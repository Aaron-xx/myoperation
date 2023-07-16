NASM		:= nasm
NASMFLAGS	:= -f elf

CC			:= gcc
CFLAGS		:= -m32 -fno-builtin -fno-stack-protector 

LD			:= ld
LDFLAGS		:= -m elf_i386


KERNEL_ADDR := 0xB000
APP_ADDR    := 0x12000

OBJCOPY		:=  objcopy
OBJCFLAGS	:= --set-start

MOUNT		:= mount
UMOUNT		:= umount
RM			:= rm -rf
MKFS		:= mkfs.msdos
MKDIR		:= mkdir
CP			:= cp


BXIMAGE	:= bximage
BXIFALGE := -imgmode="flat" -mode=create -hd=20 -q
IMG			:= Aaron
HDIMG	:= hd.img
MNT			:= mnt

DIR_DEPS	:= deps
DIR_BINS	:= bins
DIR_OBJS	:= objs

DIRS		:= $(DIR_BINS) $(DIR_DEPS) $(DIR_OBJS)

COMMON_SRC	:= common.asm
BLFUNC_SRC	:= blfunc.asm
BOOT_SRC	:= boot.asm
LOADER_SRC	:= loader.asm
KENTRY_SRC	:= kentry.asm
AENTRY_SRC  := aentry.asm

KERNEL_SRC	:= kmain.c		\
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
			   hdraw.c		\
			   fs.c

APP_SRC		:= screen.c		\
               utility.c	\
			   list.c		\
			   queue.c		\
               memory.c		\
			   syscall.c	\
			   demo1.c      \
			   demo2.c      \
			   shell.c		\
			   app.c

BOOT_OUT	:= boot
LOADER_OUT	:= loader
KERNEL_OUT	:= kernel
APP_OUT     := app
KENTRY_OUT	:= $(DIR_OBJS)/kentry.o
AENTRY_OUT  := $(DIR_OBJS)/aentry.o

AENTRY_BIN	:= kernel.bin
AENTRY_BIN	:= $(addprefix $(DIR_BINS)/, $(AENTRY_BIN))

KERNEL_OBJS := $(KERNEL_SRC:.c=.o)
KERNEL_OBJS := $(addprefix $(DIR_OBJS)/, $(KERNEL_OBJS))
KERNEL_DEPS := $(KERNEL_SRC:.c=.dep)
KERNEL_DEPS := $(addprefix $(DIR_DEPS)/, $(KERNEL_DEPS))

APP_BIN		:= app.bin
APP_BIN		:= $(addprefix $(DIR_BINS)/, $(APP_BIN))

APP_OBJS := $(APP_SRC:.c=.o)
APP_OBJS := $(addprefix $(DIR_OBJS)/, $(APP_OBJS))
APP_DEPS := $(APP_SRC:.c=.dep)
APP_DEPS := $(addprefix $(DIR_DEPS)/, $(APP_DEPS))

.PHONY: all

all: $(IMG) $(HDIMG) $(DIR_OBJS) $(DIR_BINS) $(BOOT_OUT) $(LOADER_OUT) $(KERNEL_OUT) $(APP_OUT)
	@echo "succeed! ==> Aaron.OS"

ifeq ("$(MAKECMDGOALS)", "all")
-include $(APP_DEPS)
-include $(KERNEL_DEPS)
endif

ifeq ("$(MAKECMDGOALS)", "")
-include $(APP_DEPS)
-include $(KERNEL_DEPS)
endif

$(HDIMG):
	$(BXIMAGE) $(BXIFALGE)  $(HDIMG)

$(IMG): $(MNT)
	dd if=/dev/zero of=$@  bs=512 count=2880
	$(MKFS) -F 12 -n "Aaron" $@ > /dev/null

$(BOOT_OUT): $(BOOT_SRC) $(BLFUNC_SRC)
	$(NASM) -g $< -o $@
	dd if=$@ of=$(IMG) bs=512 count=1 conv=notrunc

$(LOADER_OUT): $(LOADER_SRC) $(COMMON_SRC) $(BLFUNC_SRC)
	$(NASM) $< -o $@
	sudo $(MOUNT) -o loop $(IMG) $(MNT)
	sudo $(CP) $@ $(MNT)/$@
	sudo $(UMOUNT) $(MNT)

$(KENTRY_OUT): $(KENTRY_SRC) $(COMMON_SRC)
	$(NASM) $(NASMFLAGS) $< -o $@

$(KERNEL_OUT): $(AENTRY_BIN)
	$(OBJCOPY) $(OBJCFLAGS) $(KERNEL_ADDR) $< -O binary $@
	sudo $(MOUNT) -o loop $(IMG) $(MNT)
	sudo $(CP) $@ $(MNT)/$@
	sudo $(UMOUNT) $(MNT)

$(AENTRY_BIN): $(KENTRY_OUT) $(KERNEL_OBJS)
	$(LD) $(LDFLAGS) -s $^ -o $@ -T ld.script

$(AENTRY_OUT) : $(AENTRY_SRC) $(COMMON_SRC)
	$(NASM) $(NASMFLAGS) $< -o $@

$(APP_OUT): $(APP_BIN)
	$(OBJCOPY) $(OBJCFLAGS) $(APP_ADDR) $< -O binary $@
	sudo $(MOUNT) -o loop $(IMG) $(MNT)
	sudo $(CP) $@ $(MNT)/$@
	sudo $(UMOUNT) $(MNT)

$(APP_BIN): $(AENTRY_OUT) $(APP_OBJS)
	$(LD) $(LDFLAGS) -s $^ -o $@ -T ld.script

$(DIR_OBJS)/%.o : %.c
	$(CC) $(CFLAGS) -o $@ -c $(filter %.c, $^)

$(DIRS):
	$(MKDIR) $(DIRS)

ifeq ("$(wildcard $(DIR_DEPS))", "")
$(DIR_DEPS)/%.dep : $(DIR_DEPS) %.c
else
$(DIR_DEPS)/%.dep : %.c
endif
	@echo "Creatng $@ ..."
	@set -e; \
	gcc -MM -E $(filter %.c, $^) | sed 's,\(.*\)\.o[ :]*,objs/\1.o @ : ,g'

$(MNT):
	$(MKDIR) $@
	
.PHONY: clean rebuild

rebuild:
	$(MAKE) clean
	$(MAKE) all

hd_clean:
	$(RM) $(HDIMG)

clean:
	$(RM) $(DIRS) $(KERNEL_OUT) $(BOOT_OUT) $(LOADER_OUT) $(IMG) $(MNT) $(APP_OUT)
