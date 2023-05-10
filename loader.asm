%include "include.asm"

org 0x9000

jmp ENTRY_SEG

[section .gdt]
; GDT definition
;						 	段基址，					段界限，				段属性
GDT_ENTRY			:		Descriptor	0,				0,						0
CODE32_DESC			:		Descriptor	0, 				Code32SegLen  - 1,		DA_C + DA_32
DATA32_DESC			:		Descriptor	0, 				Data32SegLen  - 1,		DA_DRW + DA_32
STACK32_DESC		:		Descriptor	0, 				TopOfStack32,			DA_DRW + DA_32
DISPLAY_DESC		:		Descriptor	0xB8000, 		0x07FFF,				DA_DRWA + DA_32
SYSDATA32_DESC		:		Descriptor	0,				SysData32SegLen - 1,	DA_DR + DA_32
; GDT end

GdtLen	equ		$ - GDT_ENTRY

GdtPtr:
	dw GdtLen - 1
	dd 0

;GDT Selector 选择子
Code32Selector			equ (0x0001 << 3) + SA_TIG + SA_RPL0
Data32Selector			equ (0x0002 << 3) + SA_TIG + SA_RPL0
Stack32Selector			equ (0x0003 << 3) + SA_TIG + SA_RPL0
DisplaySelector			equ (0x0004 << 3) + SA_TIG + SA_RPL0
SysData32Selector		equ (0x0005 << 3) + SA_TIG + SA_RPL0
;end of [section .gdt]
	
TopOfStack16    equ 0x7c00

[section .d16]
DATA16_SEG:
	MEM_ERR_MSG		db "[FAILED] memory check error..."
	MEM_ERR_MSG_LEN	equ $ - MEM_ERR_MSG

Data16SegLen	equ $ - DATA16_SEG

[section .dat]
[bits 32]
DATA32_SEG:
	AARON				db  "Aaron.OS", 0
	AARON_OFFSET		equ AARON - $$
	HELLO_WORLD			db  "Hello World!", 0
	HELLO_WORLD_OFFSET	equ HELLO_WORLD - $$

Data32SegLen equ $ - DATA32_SEG

[section .sysdat]
SYSDATA32_SEG:
	MEM_SIZE			times	4	db	0
	MEM_SIZE_OFFSET		equ		MEM_SIZE - $$
	MEM_ARDS_NUM		times	4	db	0
	MEM_ARDS_NUM_OFFSET	equ		MEM_ARDS_NUM - $$
	MEM_ARDS			times	64 * 20 db 0
	MEM_ARDS_OFFSET		equ		MEM_ARDS - $$

SysData32SegLen		equ $ - SYSDATA32_SEG

[section .s16]
[bits 16]
ENTRY_SEG:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16

	; get system memory information
	call InitSysMemBuf

	cmp eax, 0

	jnz CODE16_MEM_ERROR
	
	; initialize GDT for 32 bits code segment
	mov esi, CODE32_SEG
	mov edi, CODE32_DESC
	
	call initDescItem
    
	; initialize GDT for 32 bits kernel data segment
	mov esi, DATA32_SEG
	mov edi, DATA32_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits kernel stack segment
	mov esi, STACK32_SEG
	mov edi, STACK32_DESC
	
	call initDescItem

	mov esi, SYSDATA32_SEG
	mov edi, SYSDATA32_DESC
	
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
	
	; 5.jump to 32 bits code 
	jmp dword Code32Selector : 0
	
CODE16_MEM_ERROR:
	mov bp, MEM_ERR_MSG
	mov cx, MEM_ERR_MSG_LEN

	call Print
	jmp $

; es:bp --> string address
; cx    --> string length
Print:
	mov dx, 0
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10
	
	ret

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

getMemSize:
	push eax
	push ebx
	push ecx

	xor eax, eax
	mov eax, 0xE801

	int 0x15

	jc error

	shl eax, 10	; eax = eax * 1024

	shl ebx, 6	; eax = eax * 64
	shl ebx, 10	; eax = eax * 1024

	mov ecx, 1
	shl ecx, 20	; eax = 1MB

	add dword [MEM_SIZE], eax
	add dword [MEM_SIZE], ebx
	add dword [MEM_SIZE], ecx

	jmp getit

error:
	mov dword [MEM_SIZE], 0

getit:
	pop ecx
	pop ebx
	pop eax

	ret

; return 
;    eax  --> 0 : succeed      1 : failed
InitSysMemBuf:
	push edi
	push ebx
	push ecx
	push edx

	call getMemSize

	mov edi, MEM_ARDS
	mov ebx, 0

readLoop:
	mov eax, 0xE820
	mov edx, 0x534D4150
	mov ecx, 20

	int 0x15

	jc memErr

	; 取得内存段中内存范围最大的几位最大物理地址

	; 查看type的值，type值为1,则系统可用，为2则为操作系统不可用段
	; 若为3,则为为定义段，可当作type为1处理
	; 此时仅考虑type为1的情况，所以得到的结果可能比实际物理内存要小
	cmp dword [edi + 16], 1
	jne next

	; 计算取得当前段的内存地址范围
	mov eax, [edi]
	add eax, [edi + 8]

	; 若当前求得的内存范围小于MEM_SIZE地址中的值
	; 则进入下一次循环，否则，将当前计算得到的内存放入MEM_SIZE地址中
	cmp dword [MEM_SIZE], eax
	jnb next

	mov dword [MEM_SIZE], eax

next:
	add edi, 20
	inc dword [MEM_ARDS_NUM]

	cmp ebx, 0
	jne readLoop

	mov eax, 0

	jmp memOk

memErr:
	mov dword [MEM_SIZE], 0
	mov dword [MEM_ARDS_NUM], 0
	mov eax, 1

memOk:
	pop edx
	pop ecx
	pop ebx
	pop edi

	ret

[section .s32]
[bits 32]
CODE32_SEG:
	; 设置显存选择子
	mov ax, DisplaySelector
	mov gs, ax
	; 设置数据段选择子
	mov ax, Data32Selector
	mov ds, ax

	; 设置栈段选择子
	mov ax, Stack32Selector
	mov ss, ax

	mov eax, TopOfStack32
	mov esp, eax

	mov ebp, AARON_OFFSET
	mov bx, 0x0C
	mov dh, 12
	mov dl, 33

	call printString

	mov ebp, HELLO_WORLD_OFFSET
	mov bx, 0x0C
	mov dh, 13
	mov dl, 31

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

[section .gs]
[bits 32]
STACK32_SEG:
	times 1024 * 4 db 0

Stack32SegLen equ $ - STACK32_SEG

TopOfStack32  equ Stack32SegLen - 1