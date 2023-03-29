
boot=boot
bootsrc=boot.asm

loader=loader
loadersrc=loader.asm

inc=include.asm

img=data.img

mnt=mnt

NASM=nasm
MOUNT=mount
UMOUNT=umount
RM=rm
MKFS=mkfs.msdos
MKDIR=mkdir
CP=cp

.PHONY: all

all: $(mnt) $(img) $(boot) $(loader)
	@echo "succeed!"

$(img): 
	@dd if=/dev/zero of=$@  bs=512 count=2880
	@$(MKFS) -F 12 -n "Aaron" $@ > /dev/null

$(boot): $(bootsrc)
	$(NASM) -g $< -o $@
	@dd if=$@ of=$(img) bs=512 count=1 conv=notrunc

$(loader): $(loadersrc) $(inc)
	@$(NASM) $< -o $@
	@sudo $(MOUNT) $(img) $(mnt)
	@sudo $(CP) $(loader) $(mnt)
	@sudo $(UMOUNT) $(mnt)
$(mnt):
	$(MKDIR) mnt
	
.PHONY: clean rebuild

rebuild:
	$(MAKE) clean
	$(MAKE) all

clean:
	$(RM) -rf $(boot) $(loader) $(img) $(mnt)
