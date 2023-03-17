org 0x9000

start:
	mov si, msg

print_String:
	mov al, [si]
	add si, 1
	cmp al, 0x00
	je end_Print
	mov ah, 0x0E
	mov bx, 0x0F
	int 0x10
	jmp print_String

end_Print:
	hlt
	jmp end_Print

msg:
	db 0x0a, 0x0a
	db "Hello, Aaron.OS!"
	db 0x0a, 0x0a
	db 0x00
