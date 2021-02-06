org 0x7c00
init:
		xor ax,ax       ; Set all segments to zero
		mov ds,ax
		mov es,ax
		mov ss,ax
		mov sp,0x8000
		mov byte [0xffff], dl
		cmp byte [0xfffe], 0xff
		je error_ran_already
get_disk:
		mov al, "#"
		call input_line
		call xdigit             ; Get a hexadecimal digit
		mov cl,4
		shl al,cl
		xchg ax,cx
		call xdigit             ; Get a hexadecimal digit
		or al,cl
		mov ah, 0x00
		push ax
		cmp al, [0xffff]
		je error_same_drive
copy:		push cs
		pop ds
		mov si, dap
		mov ah, 0x42
		mov dl, [0xffff]
		pusha
		int 0x13
		popa
		jc error_read
		pop dx
		mov ah, 0x43
		dec word [dap.lba_lower]
		pusha
		int 0x13
		popa
		jc error_write
exit:
		mov si, success
		mov byte [0xfffe], 0xff
_print:
		lodsb
		cmp al, 0x00
		je _exit
		pusha
		call output_char
		popa
		jmp _print
_exit:
		mov ah,0x00
		int 0x16
		jmp 0xffff:0x0000
error_ran_already:
	mov si, err1
	jmp _print
error_same_drive:
	mov si, err2
	jmp _print
error_read:
        mov si, err3
        jmp _print
error_write:
	mov si, err4
	jmp _print

xdigit:  
        lodsb
        cmp al,0x00             ; Zero character marks end of line
        je r
        sub al,0x30             ; Avoid spaces (anything below ASCII 0x30)
        jc xdigit
        cmp al,0x0a
        jc r
        sub al,0x07
        and al,0x0f   
        stc
r:
        ret
input_line:
        call output_char; Output prompt character
        mov si,0xa000   ; Setup SI and DI to start of line buffer
        mov di,si       ; Target for writing line
        mov dl, al
os1:    cmp al,0x08     ; Backspace?
        jne os2
        dec di          ; Undo the backspace write
        cmp si, di
        je os2_
        dec di          ; Erase a character
        push ax
        mov al, " "
        call output_char
        mov al, 0x08
        call output_char
        pop ax
os2:    call input_key  ; Read keyboard
        cmp al,0x0d     ; CR pressed?
        jne os10
        mov al,0x00
os10:   stosb           ; Save key in buffer
        jne os1         ; No, wait another key
        ret             ; Yes, return
os2_:   mov al, dl
        call output_char
        jmp os2
        ;
        ; Read a key into al
        ; Also outputs it to screen
        ;
input_key:
        mov ah,0x00
        int 0x16
        ;
        ; Screen output of character contained in al
        ; Expands 0x0d (CR) into 0x0a 0x0d (LF CR)
        ;
output_char:
        cmp al,0x0d
        jne os3
        mov al,0x0a
        call output_char
        mov al,0x0d
os3:
        mov ah,0x0e     ; Output character to TTY
        mov bx,0x0007   ; Gray. Required for graphic modes
        int 0x10        ; BIOS int 0x10 = Video
        ret

success: db "Success 0x00. Press a key to reboot...", 0x0d, 0
err1: db "Error: program ran already", 0x0d, 0
err2: db "Error: cannot install to same drive", 0x0d, 0
err3: db "Error: read error", 0x0d, 0
err4: db "Error: write error", 0x0d, 0

dap:
dap.header:	db 0x10
dap.unused:	db 0x00
dap.count:	dw 0x0080
dap.offset_offset:
		dw 0x0000
dap.offset_segment:
		dw 0x1000
dap.lba_lower:	dq 0x0001
dap.lba_upper:	dq 0x0000

times 510 - ($ - $$) db 0x00
db 0x55, 0xaa
