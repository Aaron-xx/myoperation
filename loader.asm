%include "blfunc.asm"
%include "common.asm"

org BaseOfLoader

interface:
	BaseOfStack		equ		BaseOfLoader
	BaseOfTarget	equ		BaseOfKernel
	tarStr	db "KERNEL     "
	tarLen	equ ($-tarStr)

[section .gdt]
; GDT definition
;						 				段基址，					段界限，				段属性
GDT_ENTRY			:		Descriptor	0,							0,						0
CODE32_DESC			:		Descriptor	0, 							Code32SegLen  - 1,		DA_C + DA_32 + DA_DPL0
VIDEO_DESC			:		Descriptor	0xB8000, 					0x07FFF,				DA_DRWA + DA_32 + DA_DPL0
CODE32_FLAT_DESC	:		Descriptor	0, 							0xFFFFF,				DA_C + DA_32 + DA_DPL0
DATA32_FLAT_DESC	:		Descriptor	0, 							0xFFFFF,				DA_DRW + DA_32 + DA_DPL0
TASK_LDT_DESC		:		Descriptor	0,							0,						0
TASK_TSS_DESC		:		Descriptor	0,							0,						0

; GDT end

GdtLen	equ		$ - GDT_ENTRY

GdtPtr:
	dw GdtLen - 1
	dd 0

;GDT Selector 选择子
Code32Selector			equ (0x0001 << 3) + SA_TIG + SA_RPL0
VideoSelector			equ (0x0002 << 3) + SA_TIG + SA_RPL0
Code32FlatSelector		equ (0x0003 << 3) + SA_TIG + SA_RPL0
Data32FlatSelector		equ (0x0004 << 3) + SA_TIG + SA_RPL0

;end of [section .gdt]
	
TopOfStack16    equ 0x7c00

[section .s16]
[bits 16]
BLMain:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, SPInitValue
	
	; initialize GDT for 32 bits code segment
	mov esi, CODE32_SEG
	mov edi, CODE32_DESC
	
	call initDescItem

	; initialize GDT pointer struct
	mov eax, 0
	mov ax, ds
	shl eax, 4
	add eax, GDT_ENTRY
	mov dword [GdtPtr + 2], eax

	call LoadTarget

	cmp dx, 0
	jz err

	call StoreGlobal
	
	; 1.load GDT
	lgdt [GdtPtr]
	
	; 2.close interrupt
	; set IOPL to 3
	cli

	pushf
	pop eax

	or eax, 0x3000

	push eax
	popf
	
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
	
err:
	mov bp, errStr
	mov cx, errLen
	call Print

	jmp  $

StoreGlobal:
	mov dword [RunTaskEntry], RunTask

	mov eax, dword [GdtPtr + 2]
	mov dword [GdtEntry], eax

	mov dword [GdtSize], GdtLen / 8
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

[section .gfunc]
[bits 32]
;
;  parameter  ===> Task* pt
RunTask:
    push ebp
    mov ebp, esp
    
    mov esp, [ebp + 8]
    
    lldt word [esp + 200]
    ltr word [esp + 202]
    
    pop gs
    pop fs
    pop es
    pop ds
    
    popad
    
    add esp, 4
    
    iret

[section .s32]
[bits 32]
CODE32_SEG:
	mov ax, VideoSelector
	mov gs, ax

	mov ax, Data32FlatSelector
	mov ds, ax
	mov es, ax
	mov fs, ax

	mov ax, Data32FlatSelector
	mov ss, ax
	mov esp, BaseOfLoader

	jmp dword Code32FlatSelector : BaseOfKernel
	
Code32SegLen	equ $ - CODE32_SEG

errStr db  "NO KERNEL"	
errLen equ ($-errStr)

Buffer db  0