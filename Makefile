# Makefile contributed by jtsiomb

src = os.asm
FILES = .

.PHONY: help
help:
	@echo =====bootOS=====
	@echo all: make all
	@echo run: run
	@echo install: install on /dev/sdc
	@echo software: make os image with software
	@echo wipe: wipe /dev/sdc
	@echo installer: make installer
	@echo cdimg: make cd image
	@echo strip: strip image
	@echo symbols: create sysmap.inc
	@echo ================

.PHONY: all
all: run

os.img: $(src)
	nasm -f bin -o os.img -l os.lst $(src)
.PHONY: clean
clean:
	$(RM) *.img
	$(RM) *.lst
	$(RM) lst/*.lst
	$(RM) *.inc
	-$(RM) software/ -fr

.PHONY: run
run: os.img
	qemu-system-i386 -drive file=$<,format=raw -serial stdio -s -soundhw pcspk
.PHONY: install
install:
	dd if=os.img of=$M
.PHONY: push
push: clean software
	mv os.img osall.iso
	git add $(FILES)
	git commit -m "$(M)"
	git push
.PHONY: software
software: os.img symbols
	mkdir software
	bash makesoftware.sh
	python3 makebase.py $(EXCLUDE)
	dd if=$< of=base.img conv=notrunc bs=512 count=1
	mv base.img os.img
	rm -fr software
.PHONY: installer
installer: symbols
	nasm -f bin -o installer.img installer.asm
	nasm -f bin -o os.img os.asm
	mkdir software
	bash makesoftware.sh
	python3 makebase.py $(EXCLUDE)
	dd if=os.img bs=512 count=1 > tmp.img
	mv tmp.img os.img
	cat base.img >> os.img
	cat installer.img os.img >> tmp.img
	mv tmp.img os.img
	rm -fr software
	rm base.img installer.img
.PHONY: cdimg
cdimg: os.img
	dd if=/dev/zero of=tmp.img bs=512 count=2879
	dd if=os.img of=tmp.img count=512 count=2879 conv=notrunc
	mv tmp.img os.img
	genisoimage -pad -b os.img -R -o cd.img os.img
.PHONY: strip
strip: os.img
	python3 strip.py
.PHONY: runkvm
runkvm: os.img
	qemu-system-x86_64 -drive file=$<,format=raw --enable-kvm -serial stdio -s -soundhw pcspk
.PHONY: symbols
symbols:
	python3 symbols.py os.asm sysmap.inc
.PHONY: upload
upload: software
	@sudo cp os.img /smb/usb.img
	@echo Reboot the PC!
