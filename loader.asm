%include "include.asm"

PageDirBase0    equ    0x200000
PageTblBase0    equ    0x201000
PageDirBase1    equ    0x700000
PageTblBase1    equ    0x701000

SourceAddr      equ    0x401000
TargetAddr1     equ    0xD01000
TargetAddr2     equ    0xE01000

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
PAGE_DIR_DESC0		:		Descriptor	PageDirBase0,	4095,					DA_DRW + DA_32
PAGE_TBL_DESC0		:		Descriptor	PageTblBase0,	1023,					DA_DRW + DA_LIMIT_4K + DA_32
PAGE_DIR_DESC1		:		Descriptor	PageDirBase1,	4095,					DA_DRW + DA_32
PAGE_TBL_DESC1		:		Descriptor	PageTblBase1,	1023,					DA_DRW + DA_LIMIT_4K + DA_32
FLAT_MODE_RW_DESC	:		Descriptor	0,				0xFFFFF,				DA_DRW + DA_LIMIT_4K + DA_32
FUNC32_DESC			:		Descriptor	0,				Func32SegLen - 1,		DA_DR + DA_LIMIT_4K + DA_32
FLAT_MODE_C_DESC	:		Descriptor	0,				0xFFFFF,				DA_C + DA_LIMIT_4K + DA_32

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
PageDirSelector0		equ (0x0005 << 3) + SA_TIG + SA_RPL0
PageTblSelector0		equ (0x0006 << 3) + SA_TIG + SA_RPL0
PageDirSelector1		equ (0x0007 << 3) + SA_TIG + SA_RPL0
PageTblSelector1		equ (0x0008 << 3) + SA_TIG + SA_RPL0
FlatModeSelector		equ (0x0009 << 3) + SA_TIG + SA_RPL0
Func32Selector			equ (0x000A << 3) + SA_TIG + SA_RPL0
FlatCModeSelector		equ (0x000B << 3) + SA_TIG + SA_RPL0
;end of [section .gdt]
	
TopOfStack16    equ 0x7c00

[section .dat]
[bits 32]
DATA32_SEG:
	AARON				db  "Aaron.OS", 0
	AARON_LEN			equ $ - AARON
	AARON_OFFSET		equ AARON - $$
	HELLO_WORLD			db  "Hello World!", 0
	HELLO_WORLD_LEN		equ $ - HELLO_WORLD
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

	mov esi, FUNC32_SEG
	mov edi, FUNC32_DESC
	
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

[section .func]
[bits 32]
FUNC32_SEG:
; cx --> n
; return:
;     eax --> n * n
Sqr:
	mov eax, 0
    
	mov ax, cx
	mul cx
    
	retf
    
SqrLen  equ  $ - Sqr
SqrFunc equ  Sqr - $$

; cx --> n
; return:
;     eax --> 1 + 2 + 3 + ... + n
Acc:
	push cx
    
	mov eax, 0
    
accLoop:
	add ax, cx
	loop accLoop
    
	pop cx
    
	retf
    
AccLen  equ  $ - Acc
AccFunc equ  Acc - $$

Func32SegLen  equ  $ - FUNC32_SEG


[section .s32]
[bits 32]
CODE32_SEG:
	; 设置显存选择子
	mov ax, DisplaySelector
	mov gs, ax

	; 设置栈段选择子
	mov ax, Stack32Selector
	mov ss, ax

	mov eax, TopOfStack32
	mov esp, eax

	mov ax, Func32Selector
	mov ds, ax

	mov ax, FlatModeSelector
	mov es, ax

	mov esi, SqrFunc
	mov edi, TargetAddr1
	mov ecx, SqrLen

	call memCpy

	mov esi, AccFunc
	mov edi, TargetAddr2
	mov ecx, AccLen

	call memCpy

	mov eax, PageDirSelector0
	mov ebx, PageTblSelector0
	mov ecx, PageTblBase0
	
	call initPageTable

	mov eax, PageDirSelector1
	mov ebx, PageTblSelector1
	mov ecx, PageTblBase1

	call initPageTable

	mov eax, SourceAddr
	mov ebx, TargetAddr1
	mov ecx, SqrLen

	call mapAddress

	mov eax, SourceAddr
	mov ebx, TargetAddr2
	mov ecx, AccLen

	call mapAddress

	mov eax, PageDirBase0

	call switchPageTable

	mov ecx, 100

	call FlatCModeSelector : TargetAddr1

	mov eax, PageDirBase1

	call switchPageTable

	mov ecx, 100

	call FlatCModeSelector : TargetAddr2

	jmp $

; es  --> flat mode
; eax --> virtual address
; ebx --> target  address
; ecx --> page directory base
mapAddress:
	push edi
	push esi 
	push eax    ; [esp + 8]
	push ebx    ; [esp + 4]
	push ecx    ; [esp]
    
	; 1. 取虚地址高 10 位， 计算子页表在页目录中的位置 ==> eax
	mov eax, [esp + 8]
	shr eax, 22
	and eax, 1111111111b
	shl eax, 2
    
	; 2. 取虚地址中间 10 位， 计算物理地址在子页表中的位置 ==> ebx
	mov ebx, [esp + 8]
	shr ebx, 12
	and ebx, 1111111111b
	shl ebx, 2
    
	; 3. 取子页表起始地址
	mov esi, [esp]
	add esi, eax
	mov edi, [es:esi]
	and edi, 0xFFFFF000
    
	; 4. 将目标地址写入子页表的对应位置
	add edi, ebx
	mov ecx, [esp + 4]
	and ecx, 0xFFFFF000
	or  ecx, PG_P | PG_USU | PG_RWW
	mov [es:edi], ecx
    
	pop ecx
	pop ebx
	pop eax
	pop esi
	pop edi
    
	ret

; es     --> flat mode selector
; ds:esi --> source
; es:edi --> destination
; ecx    --> length
memCpy:
    push esi
    push edi
    push ecx
    push ax
    
    cmp esi, edi
    
    ja btoe
    
    add esi, ecx
    add edi, ecx
    dec esi
    dec edi
    
    jmp etob
    
btoe:
    cmp ecx, 0
    jz done
    mov al, [ds:esi]
    mov byte [es:edi], al
    inc esi
    inc edi
    dec ecx
    jmp btoe
    
etob: 
    cmp ecx, 0
    jz done
    mov al, [ds:esi]
    mov byte [es:edi], al
    dec esi
    dec edi
    dec ecx
    jmp etob

done:   
    pop ax
    pop ecx
    pop edi
    pop esi
    ret

; eax --> page dir base selector
; ebx --> page table base selector 
; ecx --> page table base
; 初始化页表
initPageTable:
	push es
	push eax  ; [esp + 12]
	push ebx  ; [esp + 8]
	push ecx  ; [esp + 4]
	push edi  ; [esp]

	mov es, ax
	mov ecx, 1024	; 1k个子页表
	mov edi, 0
	mov eax, [esp + 4]
	or eax, PG_P | PG_USU | PG_RWW

	cld

stdir:
	; 传送指令 ,stosb,stosbw,stosd,将al,ax,eax 的值存储到edi指向的内存单元中
	; 使用 方向标志位cld或者std，edi 增加或减少
	stosd
	add eax, 4096
	loop stdir

	mov ax, [esp + 8]
	mov es, ax
	mov ecx, 1024 * 1024	; 1M个页
	mov edi, 0
	mov eax, PG_P | PG_USU | PG_RWW

	cld

sttlb:
	stosd
	add eax, 4096
	loop sttlb

	pop edi
	pop ecx
	pop ebx
	pop eax
	pop es

	ret

; eax --> page directory base
switchPageTable:
	push eax

	mov eax, cr0
	and eax, 0x7FFFFFFF
	mov cr0, eax

	mov eax, [esp]
	mov cr3, eax
	mov eax, cr0
	or eax, 0x80000000
	mov cr0, eax

	pop eax

	ret
	
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