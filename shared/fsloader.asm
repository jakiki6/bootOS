	org 0xe000
	bits 16

current_dir:	equ 0xe200
dir_space:	equ 0xe300

stage1:	mov si, 0x7c00
	mov di, 0xe000
	mov cx, 0x0200
	rep movsb
stage2:	jmp stage3
stage3:	mov si, int_table
	mov di, 0x0023 * 4
	mov cx, 3
.copy:	lodsw
	stosw
	xor ax, ax
	stosw
	loop .copy
	mov word [bootOS.commands + 3], ls_command
	mov di, current_dir
	mov cx, 0xfe
	mov al, "/"
	stosb
	xor ax, ax
	rep stosb
.end:	int 0x20

; here we include the fs driver
%ifndef MODULE
%define MODULE "../shared/dummyfs.asm"
%endif

%include MODULE

ls_command:
	push cs
	pop es
	mov bx, current_dir
	mov di, dir_space
	push di
	mov cx, 0xff
	xor ax, ax
	rep stosb
	pop di
	call list_files
	mov ah, 0x0e
	mov bx, 0x0007
	mov si, dir_space
	inc cl
	jmp short .1
.loop1:	pusha
	mov al, 0x0a
	int 0x10
	mov al, 0x0d
	int 0x10
	popa
.1:	dec cl
	cmp cl, 0x00
	je .end
.loop2:	lodsb
	cmp al, 0x00
	je .loop1
	pusha
	int 0x10
	popa
	jmp .loop2
.end:	ret	

int_table:
	dw load_file
	dw save_file
	dw delete_file
.end:
