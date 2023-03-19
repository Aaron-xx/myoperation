org 0x7c00

jmp short start
nop

define:
	BaseOfStack      equ 0x7c00
	BaseOfLoader     equ 0x9000
	RootEntryOffset  equ 19
	RootEntryLength  equ 14
	EntryItemLength  equ 32
	FatEntryOffset   equ 1
	FatEntryLength   equ 9

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
	
	mov ax, RootEntryOffset
	mov cx, RootEntryLength
	mov bx, Buf
	
	; 将根目录的文件内容复制到Buf处
	call readSector
	
	mov si, tarStr
	mov cx, tarLen
	mov dx, 0
	
	; 从Buf处的根目录文件中寻找loader
	call findEntry
	
	cmp dx, 0
	jz nofound
	
	mov si, bx
	mov di, EntryItem
	mov cx, EntryItemLength
	
	; 将找到的loader复制到指定位置
	call memCpy
	
	; 设置Fat表的起始地址
	mov ax, FatEntryLength
	mov cx, [BPB_BytsPerSec]
	mul cx
	mov bx, BaseOfLoader
	sub bx, cx
	
	mov ax, FatEntryOffset
	mov cx, FatEntryLength
	
	; 将Fat表复制到 BaseOfLoader前
	call readSector
	
	mov dx, [EntryItem + 0x1A]
	mov si, BaseOfLoader

; dx == fat index
; si == target
; bx == fat table address
loadLoader:
	mov ax, dx
	add ax, 31
	mov cx, 1
	push dx
	push bx
	mov bx, si
	; 将loader加载到0x9000，每次一个扇区
	call readSector
	pop bx
	; 将原来dx的值弹出到cx,其存放的为 fat dex,调用FatVec要用
	pop cx
	; 读取下一个fat index（返回值）
	call FatVec
	; 若返回值大于等于0xFF7,即加载loader完毕
	; 跳转到loader中，将执行权交给loader
	cmp dx, 0xFF7
	jnb BaseOfLoader
	; 若还没有读完，读取下一个扇区
	add si, 512
	jmp loadLoader

nofound:
	mov bp, msgStr
	mov cx, msgLen
	
	call print_String

last:
	hlt
	jmp last

; cx --> index
; bx --> fat table address
;
; return:
;     dx --> fat[index]
FatVec:
	;下面的操作在计算目前的实际的fat表地址，即 给定的索引 * 3 / 2
	mov ax, cx
	mov cl, 2
	div cl
	
	push ax
	
	mov ah, 0
	mov cl, 3
	mul cl
	mov cx, ax
	
	pop ax
	
	;ax里面的放的是之前除以2后的结果，
	;因为余数放在ah中,所以这里根据ah的值来判断给的索引的奇偶性
	cmp ah, 0
	jz even
	jmp odd
	
even:	; FatVec[j] = ( (Fat[i+1] & 0x0F) << 8 ) | Fat[i];
	; cx == i
	mov dx, cx
	; dx == i+1
	add dx, 1
	; Fat[i+1]
	add dx, bx
	mov bp, dx
	mov dl, byte [bp]
	; (Fat[i+1] & 0x0F)
	and dl, 0x0F
	; (Fat[i+1] & 0x0F) << 8)
	shl dx, 8
	; Fat[i]
	add cx, bx
	mov bp, cx
	; FatVec[j] = ( (Fat[i+1] & 0x0F) << 8 ) | Fat[i]
	or dl, byte [bp]
	jmp return

	
odd:	; FatVec[j+1] = (Fat[i+2] << 4) | ( (Fat[i+1] >> 4) & 0x0F );
	; cx == i
	mov dx, cx
	; i+2
	add dx, 2
	; Fat[i+2]
	add dx, bx
	mov bp, dx
	mov dl, byte [bp]
	mov dh, 0
	; (Fat[i+2] << 4)
	shl dx, 4
	; i+1
	add cx, 1
	; Fat[i+1]
	add cx, bx
	mov bp, cx
	mov cl, byte [bp]
	; (Fat[i+1] >> 4)
	shr cl, 4
	; (Fat[i+1] >> 4) & 0x0F )
	and cl, 0x0F
	mov ch, 0
	; (Fat[i+2] << 4) | ( (Fat[i+1] >> 4) & 0x0F 
	or dx, cx

return:
	ret

; no parameter
resetSector:
	push ax
	push dx
	
	; 复位磁盘系统的BIOS中断号
	mov ah, 0x00
	; 指定要复位的软盘驱动器的驱动器号
	mov dl, [BS_DrvNum]
	; 调用BIOS 0x13中断，执行ah中值的操作，此时为重置磁盘系统
	int 0x13
	
	pop dx
	pop ax
	
	ret

; ax	==> logic sector num
; cx	==> number of sector
; es:bx	==> target address
readSector:
	push bx
	
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
	
	; 长度(扇区) al
	; 此两条指令可使用一条指令替换:
	; pop cx; mov ax,cx ==> pop ax
	pop ax
	pop bx
	
	mov ah, 0x02
	
read:
	int 0x13
	; 将数据读取到es:bx ==> Buf
	; 如果读取出错跳转到read重新读取
	jc read
	
	pop bx
	ret

; ds:si --> source
; es:di --> destination
; cx    --> length
memCpy:
	; 判断源地址和目标地址的大小
	; 为了在复制前不破坏数据，如果 源 < 目标
	; 就需要从后向前复制，否则就正常复制
	cmp si, di
	; ja ==> 若si > di跳转
	ja startToTail
	
	; 若si < di 移动到末尾
	add si, cx
	add di, cx
	dec si
	dec di
	jmp tailToStart

tailToStart:
	cmp cx, 0
	jz cpdone
	mov al, [si]
	mov byte [di], al
	; 因为是从高向地复制，所有si di 每次都要减1
	dec si
	dec di
	dec cx
 	jmp tailToStart

startToTail:
	cmp cx, 0
	jz cpdone
	mov al, [si]
	mov byte [di], al
	inc si
	inc di
	dec cx
	jmp startToTail
	
cpdone:
	ret

; ds:si --> source
; es:di --> destination
; cx    --> length
;
; return:
;        (cx == 0) ? equal : noequal
memCmp:
	push si
	push di
	
compare:
	; 若cx为0,则相等，因为目标字符串自定的，那么它的长度cx是已知的
	cmp cx, 0
	jz equal
	; 取出源地址存放的值
	mov al, [si]
	; 将其与目标地址存放的值对比
	cmp al, byte [di]
	jz goon
	jmp unequal

goon:
	inc si
	inc di
	dec cx
	jmp compare
	
equal:
unequal:
	pop di
	pop si
	
	ret

; es:bx --> root entry offset address
; ds:si --> target string
; cx    --> target string length
;
; return:
;     (dx != 0) ? exist : noexist
;        exist --> bx is the target entry
findEntry:
	; 将cx入栈，之后每次循环都要使用
	push cx
	
	; dx存入根目录所有条目数
	mov dx, [BPB_RootEntCnt]
	mov bp, sp

find:
	; 若dx等于0,则根目录遍历完毕
	cmp dx, 0
	jz noexist
	; 将当前根目录条目赋值给di
	mov di, bx
	; 每次都把栈顶的值给cx,栈顶存放的是之前压入的cx的值
	mov cx, [bp]
	call memCmp
	; cx为memCmp返回值
	cmp cx, 0
	jz exist
	; 每个条目占32字节，循环后每次 +32
	add bx, 32
	dec dx
	jmp find

exist:
noexist:
	pop cx
	ret
	
; es:bp ==> 字符串地址
; cx ==> 字符串长度
print_String:
	; BIOS字符打印
	mov ax, 0x1301
	mov bx, 0x0007
	int 0x10

	ret


msgStr	db	"NO LOADER..."		; 要打印的字符串
msgLen	equ	($-msgStr)			; 字符串长度

tarStr	db "LOADER     "		; loader文件名
tarLen	equ ($-tarStr)

EntryItem times EntryItemLength db 0x00

Buf:
	times 510-($-$$) db 0x00	; times :重复 (510-($-$$)) 次 "db 00"
	; 后面还有两个字节，所以上一行使用的是510
	dw 0xaa55					; 以此结尾，表示这是一个可启动的扇区

