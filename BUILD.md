# 1. environment
* 基于linux x86环境：
* sudo apt install bochs
* bochs版本是2.6.9
* gcc : 12.2.0
* nasm : 2.16.01
* ld : 2.40
* bximage 需根据版本修改命令行参数
* 不同的版本其配置文件(bochsrc)会有不同，如不能运行bochs运行失败可能需要修改配置文件

# 2. build & run
*  make 或者 make all
*  bochs
*  make hd_clean 仅删除硬盘 ， make clean_all 可删除全部生成文件