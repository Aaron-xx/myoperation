学习操作系统的知识并写一个简单的操作系统

#1.需要安装qemu-systemd-x86
基于linux x86环境
sudo apt install qemu-system-x86
make 编译后
qemu-system-x86_64 boot.bin


调试模式
qemu-system-x86_64 -s -S boot.bin
另起一个终端
gdb boot.bin
(gdb) target remote localhost:1234
即可开始调试

2.现在学习如何从Fat12个格式的文件中找到需要的文件
目的在于，使用boot将loader内容加载进内存，为进一步加载内核做准备
	(1) Fat12根目录记载了文件的起始簇号
	(2) 通过根目录区确定是否存在目标文件
	(3) Fat12文件数据采用的单链表的思想

3.使用C语言模拟找到Fat12中的loader的过程(在项目目录下gcc编译后，直接运行)
	(1) 加载Fat表头
	(2) 加载根目录所有目录项 
	(3) 遍历目录表项寻找loader文件
	(4) 找到loader后遍历Fat表寻找它对应的表项
	(5) 根据Fat表找到loader的文件内容
	其他：
		1.Fat12每个簇有一个扇区，每个扇区512字节，文件超过512字节通过Fat表项找到下一个存储数据的扇区
		2.Fat表项类似于单链表


