
boot=boot
bootsrc=boot.asm

loader=loader
loadersrc=loader.asm

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

all: $(boot) $(loader) 
	@echo "succeed!"

$(img): $(boot)
	@dd if=/dev/zero of=$(img) bs=512 count=2880
	@$(MKFS) -F 12 -n "Aaron" $(img) > /dev/null
	@dd if=$(boot) of=$(img) bs=512 count=1 conv=notrunc

$(boot): $(bootsrc)
	$(NASM) -g $(bootsrc) -o $(boot)

$(loader): $(loadersrc) $(mnt) $(img)
	#@$(NASM) $(loadersrc) -o $(loader)
	@sudo $(MOUNT) $(img) $(mnt)
	@sudo $(CP) $(loadersrc) $(mnt)
	@sudo $(UMOUNT) $(mnt)
$(mnt):
	$(MKDIR) mnt
	
.PHONY: clean

clean:
	$(RM) -rf $(boot) $(img) $(mnt)
