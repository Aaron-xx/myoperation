%include "blfunc.asm"
%include "common.asm"

org BaseOfBoot

interface:
	BaseOfStack		equ		BaseOfBoot
	BaseOfTarget	equ		BaseOfLoader
	tarStr	db "LOADER     "	; loader
	tarLen	equ ($-tarStr)

BLMain:
	;所有段寄存器都设置为代码段(cs)
	;以便访问同一段数据
	mov ax, cs				;不可以直接在段寄存器之间赋值，要间接
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, SPInitValue

	call loadTarget

	cmp dx, 0
	jz err
	jmp BaseOfLoader
	
err:
	mov bp, errStr
	mov cx, errLen
	call Print

	jmp  $


errStr	db	"NO LOADER..."		; 要打印的字符串
errLen	equ	($-errStr)			; 字符串长度

Buffer:
	times 510-($-$$) db 0x00	; times :重复 (510-($-$$)) 次 "db 00"
	; 后面还有两个字节，所以上一行使用的是510
	dw 0xaa55					; 以此结尾，表示这是一个可启动的扇区

