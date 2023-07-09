NASM		:= nasm
NASMFLAGS	:= -f elf

CC			:= gcc
CFLAGS		:= -m32 -fno-builtin -fno-stack-protector 

LD			:= ld
LDFLAGS		:= -m elf_i386


kernel_addr := 0xB000
app_addr    := 0x12000

OBJCOPY		:=  objcopy
OBJCFLAGS	:= --set-start

MOUNT		:= mount
UMOUNT		:= umount
RM			:= rm -rf
MKFS		:= mkfs.msdos
MKDIR		:= mkdir
CP			:= cp

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
aentry_src  := aentry.asm

kernel_src	:= kmain.c		\
			   screen.c		\
			   kernel.c		\
			   utility.c	\
			   task.c		\
			   interrupt.c	\
			   ihandler.c	\
			   global.c		\
			   list.c		\
			   queue.c		\
			   memory.c		\
			   mutex.c		\
			   keyboard.c	\
			   event.c		\
			   sysinfo.c	\
			   hdraw.c

app_src		:= screen.c		\
               utility.c	\
			   list.c		\
			   queue.c		\
               memory.c		\
			   syscall.c	\
			   demo1.c      \
			   demo2.c      \
			   shell.c		\
			   app.c

boot_out	:= boot
loader_out	:= loader
kernel_out	:= kernel
app_out     := app
kentry_out	:= $(dir_objs)/kentry.o
aentry_out  := $(dir_objs)/aentry.o

kernel_bin	:= kernel.bin
kernel_bin	:= $(addprefix $(dir_bins)/, $(kernel_bin))

kernel_objs := $(kernel_src:.c=.o)
kernel_objs := $(addprefix $(dir_objs)/, $(kernel_objs))
kernel_deps := $(kernel_src:.c=.dep)
kernel_deps := $(addprefix $(dir_deps)/, $(kernel_deps))

app_bin		:= app.bin
app_bin		:= $(addprefix $(dir_bins)/, $(app_bin))

app_objs := $(app_src:.c=.o)
app_objs := $(addprefix $(dir_objs)/, $(app_objs))
app_deps := $(app_src:.c=.dep)
app_deps := $(addprefix $(dir_deps)/, $(app_deps))

.PHONY: all

all: $(img) $(dir_objs) $(dir_bins) $(boot_out) $(loader_out) $(kernel_out) $(app_out)
	@echo "succeed! ==> Aaron.OS"

ifeq ("$(MAKECMDGOALS)", "all")
-include $(app_deps)
-include $(kernel_deps)
endif

ifeq ("$(MAKECMDGOALS)", "")
-include $(app_deps)
-include $(kernel_deps)
endif

$(img): $(mnt)
	dd if=/dev/zero of=$@  bs=512 count=2880
	$(MKFS) -F 12 -n "Aaron" $@ > /dev/null

$(boot_out): $(boot_src) $(blfunc_src)
	$(NASM) -g $< -o $@
	dd if=$@ of=$(img) bs=512 count=1 conv=notrunc

$(loader_out): $(loader_src) $(common_src) $(blfunc_src)
	$(NASM) $< -o $@
	sudo $(MOUNT) -o loop $(img) $(mnt)
	sudo $(CP) $@ $(mnt)/$@
	sudo $(UMOUNT) $(mnt)

$(kentry_out): $(kentry_src) $(common_src)
	$(NASM) $(NASMFLAGS) $< -o $@

$(kernel_out): $(kernel_bin)
	$(OBJCOPY) $(OBJCFLAGS) $(kernel_addr) $< -O binary $@
	sudo $(MOUNT) -o loop $(img) $(mnt)
	sudo $(CP) $@ $(mnt)/$@
	sudo $(UMOUNT) $(mnt)

$(kernel_bin): $(kentry_out) $(kernel_objs)
	$(LD) $(LDFLAGS) -s $^ -o $@ -T ld.script

$(aentry_out) : $(aentry_src) $(common_src)
	$(NASM) $(NASMFLAGS) $< -o $@

$(app_out): $(app_bin)
	$(OBJCOPY) $(OBJCFLAGS) $(app_addr) $< -O binary $@
	sudo $(MOUNT) -o loop $(img) $(mnt)
	sudo $(CP) $@ $(mnt)/$@
	sudo $(UMOUNT) $(mnt)

$(app_bin): $(aentry_out) $(app_objs)
	$(LD) $(LDFLAGS) -s $^ -o $@ -T ld.script

$(dir_objs)/%.o : %.c
	$(CC) $(CFLAGS) -o $@ -c $(filter %.c, $^)

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
	$(RM) $(dirs) $(kernel_out) $(boot_out) $(loader_out) $(img) $(mnt) $(app_out)
