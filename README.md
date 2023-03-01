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


