org 0x7c00

start:
	;所有段寄存器都设置为代码段(cs)
	;以便访问同一段数据
	mov ax, cs				;不可以直接在段寄存器之间赋值，要间接
	mov ds, ax
	mov es, ax
	mov ss, ax

	mov si, msg
	call Print_String
	
	jmp $

;si ==> 字符串地址
Print_String:
loop:
	mov al, [si]				;逐个取出字符放入al
	add si, 1
	cmp al, 0x00				;字符串以读完，退出
	je done
	mov ah, 0x0e				;ah=0x0E表示在tty上打印al
						;bx:
						;位 0-3：字符前景色（0-15）
						;位 4-6：字符背景色（0-7）
						;位 7：闪烁标志（0=不闪烁，1=闪烁）
	mov bx, 0x0f
	int 0x10				;调用int 0x10中断，打印字符
	jmp loop				;进入下一次循环

done:
	ret

msg:
	db 0x0a					;换行符
	db "Hello Aaron!"			;要打印的字符串
	db 0x0a
	;$:当前位置，$$:当前节位置(此时是msg)
	times 510-($-$$) db 0x00		;times :重复 (510-($-$$)) 次 "db 00"
	;后面还有两个字节，所以上一行使用的是510
	dw 0xaa55,				;以此结尾，表示这是一个可启动的扇区

