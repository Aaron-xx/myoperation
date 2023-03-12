org 0x7c00

jmp short start
nop

define:
	BaseOfStack equ 0x7c00

header:
    BS_OEMName     db "Aaron.op"	; 8 字节，格式化该磁盘的工具名称
    BPB_BytsPerSec dw 512			; 每个扇区的字节数
    BPB_SecPerClus db 1				; 每个簇的扇区数
    BPB_RsvdSecCnt dw 1				; 保留扇区数，包括引导扇区和文件系统信息扇区
    BPB_NumFATs    db 2				; FAT 表的个数
    BPB_RootEntCnt dw 224			; 根目录区域所占用的条目数
    BPB_TotSec16   dw 2880			; FAT32 之前使用的字段，表示总扇区数（16位）
    BPB_Media      db 0xF0			; 介质描述符，指定介质类型1.44MB软盘是0xF0
    BPB_FATSz16    dw 9				; FAT 表的扇区数（16 位）
    BPB_SecPerTrk  dw 18			; 每个磁道的扇区数
    BPB_NumHeads   dw 2				; 磁头数
    BPB_HiddSec    dd 0				; 隐藏扇区数
    BPB_TotSec32   dd 0				; FAT32 使用的字段，表示总扇区数（32 位）
    BS_DrvNum      db 0				; 驱动器编号
    BS_Reserved1   db 0				; 保留字段
    BS_BootSig     db 0x29			; 扩展引导标志，指示是否有扩展引导记录
    BS_VolID       dd 0				; 卷序列号，用于标识卷
    BS_VolLab      db "AARON-0.01"	; 卷标，长度为 11 个字节，用于标识卷
    BS_FileSysType db "FAT12   "	; 8 字节, 文件系统类型
	
start:
	;所有段寄存器都设置为代码段(cs)
	;以便访问同一段数据
	mov ax, cs				;不可以直接在段寄存器之间赋值，要间接
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, BaseOfStack
	
	mov ax, 34
	mov cx, 1
	mov bx, Buf
	
	call ReadSector

	mov bp, Buf
	mov cx, 20
	
	call print_String
	
	jmp $

;no parameter
resetSector:
	push ax
	push dx
	
	;复位磁盘系统的BIOS中断号
	mov ah, 0x00
	;指定要复位的软盘驱动器的驱动器号
	mov dl, [BS_DrvNum]
	;调用BIOS 0x13中断，执行ah中值的操作，此时为重置磁盘系统
	int 0x13
	
	pop dx
	pop ax
	
	ret

;ax	==> logic sector num
;cx	==> number of sector
;es:bx	==> target address
ReadSector:
	pusha
	
	call resetSector
	
	push bx
	push cx
	
	; 逻辑扇区号/柱面扇区数	==> 磁头号: 商 & 1	<== dh
	;					==> 柱面号: 商 >> 1	<== ch
	;					==> 扇区号: 余数 + 1	<== cl
	; al: 长度(扇区) ch: 柱面号 cl: 起始扇区
	; dh: 磁头号 dl: 驱动器号 
	mov bl, [BPB_SecPerTrk]
	div bl
	; al ==> 商，ah ==> 余
	; 磁头号 dh
	mov dh, al
	and dh, 1
	; 柱面号 ch
	mov ch, al
	shr ch, 1
	; 扇区号 cl
	mov cl, ah
	add cl, 1
	; 驱动器号 dl
	mov dl, [BS_DrvNum]
	
	;长度(扇区) al
	;此两条指令可使用一条指令替换:
	;pop cx; mov ax,cx ==> pop ax
	pop ax
	pop bx
	
	mov ah, 0x02
	
read:
	int 0x13
	; 将数据读取到es:bx ==> Buf
	; 如果读取出错跳转到read重新读取
	jc read
	
	popa
	
	ret

;es:bp ==> 字符串地址
;cx ==> 字符串长度
print_String:
	;BIOS字符打印
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10
done:
	ret

msgStr	db	"Hello Aaron!"			;要打印的字符串
msgLen	equ	($-msgStr)				;字符串长度

Buf:
	times 510-($-$$) db 0x00	;times :重复 (510-($-$$)) 次 "db 00"
	;后面还有两个字节，所以上一行使用的是510
	dw 0xaa55					;以此结尾，表示这是一个可启动的扇区

