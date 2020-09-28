	org 0xe000
	bits 16

current_dir:	equ 0xe200

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
	mov word [bootOS.ls_command], ls_command
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
	mov si, current_dir
	call list_files

int_table:
	dw load_file
	dw save_file
	dw delete_file
.end:
