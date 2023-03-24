%include "include.asm"

org 0x9000

jmp ENTRY_SEG

[section .gdt]
; GDT definition
;						 		段基址，					段界限，					段属性
GDT_ENTRY			:		Descriptor	0,				0,						0
CODE32_DESC			:		Descriptor	0, 				Code32SegLen  - 1,		DA_C + DA_32
DATA32_DESC			:		Descriptor	0, 				Data32SegLen  - 1,		DA_DR + DA_32
STACK32_DESC		:		Descriptor	0, 				TopOfStack32,			DA_DRW + DA_32
DISPLAY_DESC		:		Descriptor	0xB8000, 		0x07FFF,				DA_DRWA + DA_32
CODE16_DESC			:		Descriptor	0, 				0xFFFF,					DA_C
UPDATE_DESC			:		Descriptor	0, 				0xFFFF,					DA_DRW
TASK_A_LDT_DESC		:		Descriptor	0, 				TaskALdtLen - 1,		DA_LDT

GdtLen	equ		$ - GDT_ENTRY

GdtPtr:
	dw GdtLen
	dd 0

;GDT Selector 选择子
Code32Selector		equ (0x0001 << 3) + SA_TIG + SA_RPL0
Data32Selector		equ (0x0002 << 3) + SA_TIG + SA_RPL0
Stack32Selector		equ (0x0003 << 3) + SA_TIG + SA_RPL0
DisplaySelector		equ (0x0004 << 3) + SA_TIG + SA_RPL0
Code16Selector		equ (0x0005 << 3) + SA_TIG + SA_RPL0
UpdateSelector		equ (0x0006 << 3) + SA_TIG + SA_RPL0
TaskALdtSecector	equ (0x0007 << 3) + SA_TIG + SA_RPL0
;end of [section .gdt]

TopOfStack16    equ 0x7c00

;全局数据段
[section .dat]
[bits 32]
DATA32_SEG:
	AAOS				db  "Aaron.OS!", 0
	AAOS_OFFSET			equ AAOS - $$
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
	
	; 将实模式代码段地址赋值给 从保护模式返回实模式 的跳转语句
	mov [BACK_TO_REAL_MODE + 3], ax
	
	; initialize GDT for 32 bits code segment
	mov esi, CODE32_SEG
	mov edi, CODE32_DESC
	
	call initDescItem
    
	; initialize GDT for 32 bits data segment
	mov esi, DATA32_SEG
	mov edi, DATA32_DESC
	
	call initDescItem
	
	; initialize GDT for 32 bits stack segment
	mov esi, STACK32_SEG
	mov edi, STACK32_DESC
	
	call initDescItem
	
	; initialize GDT for 16 bits code segment
	mov esi, CODE16_SEG
	mov edi, CODE16_DESC
	
	call initDescItem
	
	mov esi, TASK_A_LDT_ENTRY
	mov edi, TASK_A_LDT_DESC
	
	call initDescItem
	
	mov esi, TASK_A_CODE32_SEG
	mov edi, TASK_A_CODE32_DESC
	
	call initDescItem
	
	mov esi, TASK_A_DATA32_SEG
	mov edi, TASK_A_DATA32_DESC
	
	call initDescItem
	
	mov esi, TASK_A_STACK32_SEG
	mov edi, TASK_A_STACK32_DESC
	
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
	
BACK_TO_REAL:
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, TopOfStack16
	
	; 关闭A20地址线
	in al, 0x92
	and al, 11111101b
	out 0x92, al
	
	; 打开硬件中断
	sti
	
	mov bp, HELLO_WORLD
	mov cx, 12
	mov dx, 0
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10
	
	jmp $
	
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

[section .s16]
[bits 16]
CODE16_SEG:
	mov ax, UpdateSelector
	mov ds, ax
	mov fs, ax
	mov es, ax
	mov gs, ax
	mov ss, ax
	
	; exit protect mode 通知cpu退出保护模式
	mov eax, cr0
	and eax, 11111110b
	mov cr0, eax
	
	; 返回实模式
BACK_TO_REAL_MODE:
	jmp 0 : BACK_TO_REAL
	
Code16SegLen equ $ - CODE16_SEG

[section .s32]
[bits 32]
CODE32_SEG:
	; 设置数据段选择子
	mov ax, Data32Selector
	mov ds, ax
	; 设置栈段选择子
	mov ax, Stack32Selector
	mov ss, ax
	; 设置栈顶
	mov eax, TopOfStack32
	mov esp, eax
	; 设置显存选择子
	mov ax, DisplaySelector
	mov gs, ax
	
	mov ebp, AAOS_OFFSET
	mov bx, 0x0C
	mov dh, 12
	mov dl, 33
	
	call print_String
	
	mov ebp, HELLO_WORLD_OFFSET
	mov bx, 0x0C
	mov dh, 13
	mov dl, 31
	
	call print_String
	
	mov ax, TaskALdtSecector
	
	lldt ax
	
	jmp TaskACode32Selector : 0
	
; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
print_String:
	push ebp
	push eax
	push edi
	push cx
	push dx
	
print:
	mov cl, [ds:ebp]
	cmp cl, 0
	je end_Print
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
	
end_Print:
	pop dx
	pop cx
	pop edi
	pop eax
	pop ebp
    
	ret

Code32SegLen	equ $ - CODE32_SEG

; 设置32位的栈段
[section .gs]
[bits 32]
STACK32_SEG:
	times 1024 * 4 db 0
	
Stack32SegLen equ $ - STACK32_SEG
TopOfStack32  equ Stack32SegLen - 1

;局部描述段:
; ==========================================
;
;            Task A Code Segment 
;
; ==========================================

[section .task-a-ldt]
; Task A LDT definition 局部描述符
;								段基址,						段界限,						段属性
TASK_A_LDT_ENTRY:
TASK_A_CODE32_DESC		:		Descriptor	0,			TaskACode32SegLen - 1,			DA_C + DA_32
TASK_A_DATA32_DESC		:		Descriptor	0,			TaskAData32SegLen - 1,			DA_DR + DA_32
TASK_A_STACK32_DESC		:		Descriptor	0,			TaskAStack32SegLen - 1,			DA_DRW + DA_32

TaskALdtLen equ $ - TASK_A_LDT_ENTRY

; Task A LDT Selector
TaskACode32Selector  equ   (0x0000 << 3) + SA_TIL + SA_RPL0
TaskAData32Selector  equ   (0x0001 << 3) + SA_TIL + SA_RPL0
TaskAStack32Selector equ   (0x0002 << 3) + SA_TIL + SA_RPL0

[section .task-a-dat]
[bits 32]
TASK_A_DATA32_SEG:
	TASK_A_STRING			db  "This is Task A!", 0
	TASK_A_STRING_OFFSET	equ TASK_A_STRING - $$

TaskAData32SegLen  equ  $ - TASK_A_DATA32_SEG

[section .task-a-gs]
[bits 32]
TASK_A_STACK32_SEG:
	times 1024 db 0 
	
TaskAStack32SegLen	equ	$ - TASK_A_STACK32_SEG
TaskATopOfStack32	equ	TaskAStack32SegLen - 1

; 局部描述段的代码段
[section .task-a-s32]
[bits 32]
TASK_A_CODE32_SEG:
	mov ax, TaskAData32Selector
	mov ds, ax
	
	mov ax, TaskAStack32Selector
	mov ss, ax
	
	mov eax, TaskATopOfStack32
	mov esp, eax
	
	mov ax, DisplaySelector
	mov gs, ax
	
	mov ebp, TASK_A_STRING_OFFSET
	mov bx, 0x0C
	mov dh, 14
	mov dl, 31
	
	call taskPrintString
	
	jmp Code16Selector : 0
	
; ds:ebp    --> string address
; bx        --> attribute
; dx        --> dh : row, dl : col
taskPrintString:
	push ebp
	push eax
	push edi
	push cx
	push dx
	
task_Print:
	mov cl, [ds:ebp]
	cmp cl, 0
	je end_task_Print
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
	jmp task_Print
	
end_task_Print:
	pop dx
	pop cx
	pop edi
	pop eax
	pop ebp
    
	ret
	
TaskACode32SegLen	equ $ - TASK_A_CODE32_SEG








