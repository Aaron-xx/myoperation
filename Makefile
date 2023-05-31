NASM		:= nasm
NASMFLAGS	:= -f elf

CC			:= gcc
CFLAGS		:= -m32 -fno-builtin -fno-stack-protector

LD			:= ld
LDFLAGS		:= -m elf_i386

MOUNT		:= mount
UMOUNT		:= umount
RM			:= rm
MKFS		:= mkfs.msdos
MKDIR		:= mkdir
CP			:= cp

kernel_addr	:= B000
img			:= Aaron
mnt			:= mnt

dir_deps	:= deps
dir_bins	:= bins
dir_objs	:= objs

dirs		:= $(dir_bins) $(dir_deps) $(dir_objs)

common_src	:= common.asm
blfunc_src	:= blfunc.asm
boot_src	:= boot.asm
loader_src	:= loader.asm
kentry_src	:= kentry.asm

kernel_src	:= kmain.c screen.c

boot_out	:= boot
loader_out	:= loader
kernel_out	:= kernel
kentry_out	:= $(dir_objs)/kentry.o

bin			:= kernel.bin
bin			:= $(addprefix $(dir_bins)/, $(bin))

#srcs		:= $(wildcard *.c)
srcs		:= $(kernel_src)
objs		:= $(srcs:.c=.o)
objs		:= $(addprefix $(dir_objs)/, $(objs))
deps		:= := $(srcs:.c=.dep)
deps		:= $(addprefix $(dir_deps)/, $(deps))

.PHONY: all

all: $(mnt) $(img) $(dir_objs) $(dir_bins) $(dir_deps) $(boot_out) $(loader_out) $(kentry_out) $(kernel_out)
	@echo "succeed! ==> Aaron.OS"

ifeq ("$(MAKECMDGOALS)", "all")
-include $(DEPS)
endif

ifeq ("$(MAKECMDGOALS)", "")
-include $(DEPS)
endif

$(img): 
	@dd if=/dev/zero of=$@  bs=512 count=2880
	@$(MKFS) -F 12 -n "Aaron" $@ > /dev/null

$(boot_out): $(boot_src) $(blfunc_src)
	$(NASM) -g $< -o $@
	@dd if=$@ of=$(img) bs=512 count=1 conv=notrunc

$(loader_out): $(loader_src) $(common_src) $(blfunc_src)
	@$(NASM) $< -o $@
	@sudo $(MOUNT) -o loop $(img) $(mnt)
	@sudo $(CP) $@ $(mnt)/$@
	@sudo $(UMOUNT) $(mnt)

$(kentry_out): $(kentry_src) $(common_src)
	$(NASM) $(NASMFLAGS) $< -o $@

$(kernel_out): $(bin)
	objcopy --set-start 0xB000 $< -O binary $@
	@sudo $(MOUNT) -o loop $(img) $(mnt)
	@sudo $(CP) $@ $(mnt)/$@
	@sudo $(UMOUNT) $(mnt)

$(bin): $(kentry_out) $(objs)
	$(LD) $(LDFLAGS) -s $^ -o $@

$(dir_objs)/%.o : %.c
	$(CC) $(CFLAGS) -m32 -o $@ -c $(filter %.c, $^)

$(dirs):
	$(MKDIR) $(dirs)

ifeq ("$(wildcard $(dir_deps))", "")
$(dir_deps)/%.dep : $(dir_deps) %.c
else
$(dir_deps)/%.dep : %.c
endif
	@echo "Creatng $@ ..."
	@set -e; \
	gcc -MM -E $(filter %.c, $^) | sed 's,\(.*\)\.o[ :]*,objs/\1.o @ : ,g'

$(mnt):
	$(MKDIR) mnt
	
.PHONY: clean rebuild

rebuild:
	$(MAKE) clean
	$(MAKE) all

clean:
	$(RM) -rf $(dirs) $(kernel_out) $(boot_out) $(loader_out) $(img) $(mnt) 
