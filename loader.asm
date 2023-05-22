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
;end of [section .gdt]
	
TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEG:
	AARON				db  "Aaron.OS", 0
	AARON_OFFSET		equ AARON - $$
	HELLO_WORLD			db  "Hello World!", 0
	HELLO_WORLD_OFFSET	equ HELLO_WORLD - $$

Data32SegLen equ $ - DATA32_SEG

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
	mov esi, DATA32_SEG
	mov edi, DATA32_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits kernel stack segment
	mov esi, STACK32_SEG
	mov edi, STACK32_DESC
	
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