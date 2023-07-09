%include "blfunc.asm"
%include "common.asm"

org BaseOfBoot

BaseOfStack		equ		BaseOfBoot

Loader db  "LOADER     "
LdLen  equ ($-Loader)

BLMain:
	;所有段寄存器都设置为代码段(cs)
	;以便访问同一段数据
	mov ax, cs				;不可以直接在段寄存器之间赋值，要间接
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, SPInitValue

	push word Buffer
	push word BaseOfLoader / 0x10
	push word BaseOfLoader
	push word LdLen
	push word Loader

	call LoadTarget

	cmp dx, 0
	jz err

	jmp BaseOfLoader
	
err:
	mov ax, cs
	mov es, ax
	mov bp, errStr
	mov cx, errLen
	xor dx, dx
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10
    
	jmp $    


errStr	db	"NO LOADER..."		; 要打印的字符串
errLen	equ	($-errStr)			; 字符串长度

Buffer:
	times 510-($-$$) db 0x00	; times :重复 (510-($-$$)) 次 "db 00"
	; 后面还有两个字节，所以上一行使用的是510
	dw 0xaa55					; 以此结尾，表示这是一个可启动的扇区

