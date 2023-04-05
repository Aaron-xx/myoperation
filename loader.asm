%include "include.asm"

org 0x9000

jmp ENTRY_SEG

[section .gdt]
; GDT definition
;						 		段基址，					段界限，					段属性
GDT_ENTRY			:		Descriptor	0,				0,						0
CODE32_DESC			:		Descriptor	0, 				Code32SegLen  - 1,		DA_C + DA_32 + DA_DPL3
DATA32_KERNEL_DESC	:		Descriptor	0, 				Data32KernelSegLen  - 1,DA_DRW + DA_32 + DA_DPL0
STACK32_KERNEL_DESC	:		Descriptor	0, 				TopOfKernelStack32,		DA_DRW + DA_32 + DA_DPL0
DATA32_USER_DESC	:		Descriptor	0, 				Data32UserSegLen  - 1,	DA_DRW + DA_32 + DA_DPL3
STACK32_USER_DESC	:		Descriptor	0, 				TopOfUserStack32,		DA_DRW + DA_32 + DA_DPL3
DISPLAY_DESC		:		Descriptor	0xB8000, 		0x07FFF,				DA_DRWA + DA_32 + DA_DPL3
FUNCTION_DESC		:		Descriptor	0, 				FunctionSegLen - 1,		DA_C + DA_32 + DA_DPL0
TSS_DESC			:		Descriptor	0, 				TSSLen - 1,				DA_386TSS + DA_32 + DA_DPL0

; Call Gate
;										选择子,				偏移,				参数个数,				属性
FUNC_GETKERNELDATA_DESC	:	Gate		FunctionSelector,	getKData,			0,					DA_386CGate + DA_DPL3

; GDT end

GdtLen	equ		$ - GDT_ENTRY

GdtPtr:
	dw GdtLen - 1
	dd 0

;GDT Selector 选择子
Code32Selector			equ (0x0001 << 3) + SA_TIG + SA_RPL3
Data32KernelSelector	equ (0x0002 << 3) + SA_TIG + SA_RPL0
Stack32KernelSelector	equ (0x0003 << 3) + SA_TIG + SA_RPL0
Data32UserSelector		equ (0x0004 << 3) + SA_TIG + SA_RPL3
Stack32UserSelector		equ (0x0005 << 3) + SA_TIG + SA_RPL3
DisplaySelector			equ (0x0006 << 3) + SA_TIG + SA_RPL3
FunctionSelector		equ (0x0007 << 3) + SA_TIG + SA_RPL0
TSSSelector				equ (0x0008 << 3) + SA_TIG + SA_RPL0
; Gate Selector
getKernelDataSelector	equ (0x0009 << 3) + SA_TIG + SA_RPL3
;end of [section .gdt]

[section .tss]
[bits 32]
TSS_SEG:
	dd		0
	dd		TopOfKernelStack32		; 0
	dd		Stack32KernelSelector	;
	dd		0						; 1
	dd		0						;
	dd		0						; 2
	dd		0						;
	times	4 * 18	dd 0
	dw		0
	dw		$ - TSS_SEG + 2
	db		0xFF

TSSLen equ $ - TSS_SEG
	
TopOfStack16    equ 0x7c00

;全局数据段,特权级0
[section .dat0]
[bits 32]
DATA32_KERNEL_SEG:
	KData				db  "Kernel Data", 0
	KDataLen			equ $ - KData
	KData_OFFSET		equ KData - $$

Data32KernelSegLen equ $ - DATA32_KERNEL_SEG

;全局数据段,特权级2
[section .dat2]
[bits 32]
DATA32_USER_SEG:
	UData				db  "User   Data", 0
	UDataLen			equ $ - UData
	UData_OFFSET		equ UData - $$

Data32UserSegLen equ $ - DATA32_USER_SEG

[section .s16]
[bits 16]
ENTRY_SEG:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16
	
	; initialize GDT for 32 bits code segment
	mov esi, CODE32_SEG
	mov edi, CODE32_DESC
	
	call initDescItem
    
	; initialize GDT for 32 bits kernel data segment
	mov esi, DATA32_KERNEL_SEG
	mov edi, DATA32_KERNEL_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits kernel stack segment
	mov esi, STACK32_KERNEL_SEG
	mov edi, STACK32_KERNEL_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits user data segment
	mov esi, DATA32_USER_SEG
	mov edi, DATA32_USER_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits user stack segment
	mov esi, STACK32_USER_SEG
	mov edi, STACK32_USER_DESC
	
	call initDescItem
	
	mov esi, FUNCTION_SEG
	mov edi, FUNCTION_DESC
	
	call initDescItem
	
	mov esi, TSS_SEG
	mov edi, TSS_DESC
	
	call initDescItem
	
	; initialize GDT pointer struct
	mov eax, 0
	mov ax, ds
	shl eax, 4
	add eax, GDT_ENTRY
	mov dword [GdtPtr + 2], eax
	
	; 1.load GDT
	lgdt [GdtPtr]
	
	; 2.close interrupt
	cli
	
	; 3.open A20 地址线
	in al, 0x92
	or al, 00000010b
	out 0x92, al
	
	; 4.enter protect mode 通知cpu进入保护模式
	mov eax, cr0
	or eax, 0x01
	mov cr0, eax

	; 5. load TSS
	mov ax, TSSSelector
	ltr ax
	
	; 6.jump to 32 bits code 
	;jmp dword Code32Selector : 0
	push Stack32UserSelector
	push TopOfUserStack32
	push Code32Selector    
	push 0                 
	retf
	
; esi --> code segment label
; edi --> descriptor label
initDescItem:
	push eax

	mov eax, 0
	mov ax, cs
	shl eax, 4
	add eax, esi
	; 向描述符填充低0-15位基址
	mov [edi + 2], ax
	shr eax, 16
	; 填充16-23基址
	mov byte [edi + 4], al
	; 填充24-31基址
	mov byte [edi + 7], ah
	
	pop eax
	
	ret

[section .s32]
[bits 32]
CODE32_SEG:
	; 设置显存选择子
	mov ax, DisplaySelector
	mov gs, ax
	
	; 设置数据段选择子
	mov ax, Data32UserSelector
	mov es, ax
	
	mov di, UData_OFFSET
	
	call getKernelDataSelector : 0
	
	mov ax, Data32UserSelector
	mov ds, ax
	
	mov ebp, UData_OFFSET
	mov bx, 0x0C
	mov dh, 12
	mov dl, 33
	
	call printString
	
	jmp $
	
; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
printString:
	push ebp
	push eax
	push edi
	push cx
	push dx
	
print:
	mov cl, [ds:ebp]
	cmp cl, 0
	je endPrint
	; 每行80个字符，乘以dh(行)，得到所设置的行数的起始位置
	mov eax, 80
	mul dh
	; 将列数加入al中，此时eax存放的就是要打印的位置
	add al, dl
	; 显卡文本显示，低位设置字符，高位设置显示属性
	; 通过左移1位，得到乘以2后的结果
	shl eax, 1
	mov edi, eax
	; 将ax低位设置字符，ax高位设置显示属性
	mov ah, bl
	mov al, cl
	mov [gs:edi], ax
	inc ebp
	inc dl
	jmp print
	
endPrint:
	pop dx
	pop cx
	pop edi
	pop eax
	pop ebp
    
	ret
	
Code32SegLen	equ $ - CODE32_SEG

[section .func]
[bits 32]
FUNCTION_SEG:

; es:di --> data buffer 
GetKernelData:
	; 将压入栈的段地址取出，拿到真实的权限等级
	mov cx, [esp + 4]
	and cx, 0x0003
	; 再取出目标段地址的前14位
	mov ax, es
	and ax, 0xFFFC
	; 将他们组合成真实的当前段地址+权限
	or ax, cx
	mov es, ax
	
	mov ax, Data32KernelSelector
	mov ds, ax
	
	mov si, KData_OFFSET
	mov cx, KDataLen
	
	call KMemCpy
	
	retf

; ds:si --> source
; es:di --> destination
; cx    --> length
KMemCpy:
	mov ax, es
	
	call checkRPL
	
	cmp si, di
	ja tailToStart
	add si, cx
	add di, cx
	dec si
	dec di
	jmp startToTail
tailToStart:
	cmp cx, 0
	jz cpyDone
	mov al, [ds:si]
	mov byte [es:di], al
	inc si
	inc di
	dec cx
	jmp tailToStart
startToTail:
	cmp cx, 0
	jz cpyDone
	mov al, [ds:si]
	mov byte [es:di], al
	dec si
	dec di
	dec cx
	jmp startToTail
cpyDone:
	ret
	
; ax --> selector value
checkRPL:
	; 检查目标段的段选择子权限等级
	; 即去段的最后两位的大小与0对比
	and ax, 0x0003
	cmp ax, SA_RPL0
	jz valid
	
	; 相当于在0低地址写入0值，模拟触发中断
	mov ax, 0
	mov fs, ax
	mov byte [fs:0], 0
	
	
valid:
	ret
	
getKData equ GetKernelData - $$

FunctionSegLen equ $ - FUNCTION_SEG


; 定义32位的特权级为0的内核栈段
[section .kgs]
[bits 32]
STACK32_KERNEL_SEG:
	times 1024 db 0
	
Stack32KernelSegLen equ $ - STACK32_KERNEL_SEG
TopOfKernelStack32  equ Stack32KernelSegLen - 1

; 定义32位的特权级为3的用户栈段
[section .ugs]
[bits 32]
STACK32_USER_SEG:
	times 1024 db 0
	
Stack32UserSegLen equ $ - STACK32_USER_SEG
TopOfUserStack32  equ Stack32UserSegLen - 1

