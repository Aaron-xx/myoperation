
boot=boot.bin
bootsrc=boot.asm
img=date.img

NASM=nasm
RM=rm
MKFS=mkfs.msdos

all: $(boot)
	@dd if=/dev/zero of=$(img) bs=512 count=2880
	@dd if=boot.bin of=$(img) bs=512 count=1 conv=notrunc
	@$(MKFS) -F 12 -n "Aaron" $(img) > /dev/null

$(boot): $(bootsrc)
	$(NASM) $(bootsrc) -o $(boot)

clean:
	$(RM) -rf $(boot) $(img)
