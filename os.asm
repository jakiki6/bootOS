bits 16
cpu 186

stack:  equ 0x7600      ; Stack pointer (grows to lower addresses)
line:   equ 0x7780      ; Buffer for line input
sector: equ 0x7800      ; Sector data for directory
osbase: equ 0x7a00      ; bootOS location
boot:   equ 0x7c00      ; Boot sector location  

entry_size:     equ 16  ; Directory entry size
sector_size:    equ 512 ; Sector size
max_entries:    equ sector_size/entry_size

        ;
        ; Cold start of bootOS
        ;
        ; Notice it is loaded at 0x7c00 (boot) and needs to
        ; relocate itself to 0x7a00 (osbase), the instructions
        ; between 'start' and 'restart' shouldn't depend
        ; on the assembly location (osbase) because these
        ; are running at boot location (boot).
        ;
        org 0x7a00	; osbase
start:
        xor ax,ax       ; Set all segments to zero
        mov ds,ax
        mov es,ax
        mov ss,ax
        mov sp,stack    ; Set stack to guarantee data safety
        mov [disk.1 + 1], dl

        cld             ; Clear D flag.
        mov si,boot     ; Copy bootOS boot sector...
        mov di,osbase   ; ...into osbase
        mov cx,sector_size
        rep movsb

        mov si,interrupt_table ; SI now points to interrupt_table 
        mov di,0x0020*4 ; Address of service for int 0x20
        mov cl,7
.load_vec:
        movsw           ; Copy IP address
        stosw           ; Copy CS address
        loop .load_vec
	int 0x20	; Jump to real main and set CS:IP to fix the issue with some BIOSes
        ;
        ; Warm start of bootOS
        ;
restart:
        cld             ; Clear D flag.
	clc
        push cs         ; Reinit all segment registers
        push cs
        push cs
        pop ds
        pop es
        pop ss
        mov sp,stack    ; Restart stack

        mov al,'>'      ; Command prompt
        int int_input_line ; Input line

        cmp byte [si],0x00  ; Empty line?
        je restart          ; Yes, get another line

        mov di,commands ; Point to commands list

        ; Notice that filenames starting with same characters
        ; won't be recognized as such (so file lsab cannot be
        ; executed).
os11:
        mov al,[di]     ; Read length of command in chars
        inc di
        and ax,0x00ff   ; Is it zero?
        je os12         ; Yes, jump
        xchg ax,cx
        push si         ; Save current position
        rep cmpsb       ; Compare statement
        jne os14        ; Equal? No, jump
        call word [di]  ; Call command process
        jmp restart     ; Go to expect another command

os14:   add di,cx       ; Advance the list pointer
        inc di          ; Avoid the address
        inc di
        pop si
        jmp os11        ; Compare another statement

os12:   mov bx,si       ; Input pointer
        mov di,boot     ; Location to read data
        int int_load_file       ; Load file
        jc os7          ; Jump if error
        jmp bx

        ;
        ; File not found error
        ;
os7:
	mov si, error_msg
	call output_string
        int int_restart

        ;
        ; >> COMMAND <<
        ; rm filename
        ;
rm_command:
os22:
        mov bx,si       ; Copy SI (buffer pointer) to BX
        lodsb
        cmp al,0x20     ; Avoid spaces
        je os22
        int int_delete_file
        jc os7
        ret

        ;
        ; 'ls' command
        ;
ls_command:
        call read_dir           ; Read the directory
        mov di,bx
os18:
        cmp byte [di],0         ; Empty entry?
        je os17                 ; Yes, jump
        mov si,di               ; Point to data
        call output_string      ; Show name
os17:   call next_entry
        jne os18                ; No, jump
        ret                     ; Return

        ;
        ; Get filename length and prepare for directory lookup
        ; Entry:
        ;   si = pointer to string
        ; Output:
        ;   si = unaffected
        ;   di = pointer to start of directory
        ;   cx = length of filename including zero terminator
        ;
filename_length:
        push si
        xor cx,cx       ; cx = 0
.loop:
        lodsb           ; Read character.
        inc cx          ; Count character.
        cmp al,0        ; Is it zero (end character)?
        jne .loop       ; No, jump.

        pop si
        mov di,sector   ; Point to start of directory.
        ret
        
        ;
        ; >> SERVICE <<
        ; Load file
        ;
        ; Entry:
        ;   ds:bx = Pointer to filename ended with zero byte.
        ;   es:di = Destination.
        ; Output:
        ;   Carry flag = Set = not found, clear = successful.
        ;
load_file:
        push di         ; Save destination
        push es
        call find_file  ; Find the file (sanitizes ES)
        mov ah,0x42     ; Read sector
shared_file:
        pop es
        pop bx          ; Restore destination on BX
        jc ret_cf       ; Jump if error
        call disk       ; Do operation with disk
                        ; Carry guaranteed to be clear.
ret_cf:
        mov bp,sp
        rcl byte [bp+4],1       ; Insert Carry flag in Flags (automatic usage of SS)
        iret

        ;
        ; >> SERVICE <<
        ; Save file
        ;
        ; Entry:
        ;   ds:bx = Pointer to filename ended with zero byte.
        ;   es:di = Source.
        ; Output:
        ;   Carry flag = Set = error, clear = good.
        ;
save_file:
        push di                 ; Save origin
        push es
        push bx                 ; Save filename pointer
        int int_delete_file     ; Delete previous file (sanitizes ES)
        pop bx                  ; Restore filename pointer
        call filename_length    ; Prepare for lookup

.find:  es cmp byte [di],0      ; Found empty directory entry?
        je .empty               ; Yes, jump and fill it.
        call next_entry
        jne .find
        jmp shared_file

.empty: push di
        rep movsb               ; Copy full name into directory
        call write_dir          ; Save directory
        pop di
        call get_location       ; Get location of file
        mov ah,0x43             ; Write sector
        jmp shared_file

        ;
        ; >> SERVICE <<
        ; Delete file
        ;
        ; Entry:
        ;   ds:bx = Pointer to filename ended with zero byte.
        ; Output:
        ;   Carry flag = Set = not found, clear = deleted.
        ;
delete_file:
        call find_file          ; Find file (sanitizes ES)
        jc ret_cf               ; If carry set then not found, jump.
        mov cx,entry_size
        call write_zero_dir
	jmp ret_cf

        ;
        ; Find file
        ;
        ; Entry:
        ;   ds:bx = Pointer to filename ended with zero byte.
        ; Result:
        ;   es:di = Pointer to directory entry
        ;   Carry flag = Clear if found, set if not found.
find_file:
        push bx
        call read_dir   ; Read directory (sanitizes ES)
        pop si
        call filename_length    ; Get filename length and setup DI
os6:
        pusha
	repe cmpsb      ; Compare name with entry
	popa
        je get_location ; Jump if equal.
        call next_entry
        jne os6         ; No, jump
        ret             ; Return

next_entry:
        add di,byte entry_size          ; Go to next entry.
        cmp di,sector+sector_size-entry_size	; Complete directory?
        stc                             ; Error, not found.
        ret

        ;
        ; Get location of file on disk
        ;
        ; Entry:
        ;   DI = Pointer to entry in directory.
        ;
        ; Result
        ;   CL = Sector
        ;
        ; The position of a file inside the disk depends on its
        ; position in the directory. The first entry goes to
        ; track 1, the second entry to track 2 and so.
        ;
get_location:
	; mov cx, di
	; sub cx, sector - entry_size - (1 << 4)
        lea cx,[di - (sector - entry_size - (1 << 4))] ; Get entry pointer into directory
                        ; Plus one entry (files start on track 1)
        shr cx,4        ; Divide by 16
        ret

        ;
        ; Read the directory from disk
        ;
read_dir:
        push cs         ; bootOS code segment...
        pop es          ; ...to sanitize ES register
        mov ah,0x42
        jmp short disk_dir

write_zero_dir:
        mov al,0
        rep stosb
        ;
        ; Write the directory to disk
        ;
write_dir:
        mov ah,0x43
disk_dir:
        mov bx,sector
        mov cl, 0x01
        ;
        ; Do disk operation.
        ;
        ; Input:
        ;   AH = 0x42 read disk, 0x43 write disk
        ;   ES:BX = data source/target
        ;   CL = Sector number
        ;
disk:
	clc
        pusha
	push cs
	pop ds
        mov si, dap
	mov bp, si
	mov word [bp + (dap.offset_offset - dap)], bx
	mov word [bp + (dap.offset_segment - dap)], es
	mov byte [bp + (dap.lba_lower - dap)], cl
.1:
_disk2:
	mov dl, 0x80
        int 0x13
	popa
	jc disk
        ret

        ;
        ; Input line from keyboard
        ; Entry:
        ;   al = prompt character
        ; Result:
        ;   buffer 'line' contains line, finished with CR
        ;   SI points to 'line'.
        ;
input_line:
        int int_output_char ; Output prompt character
        mov si,line     ; Setup SI and DI to start of line buffer
        mov di,si       ; Target for writing line
        xchg ax, dx
os1:    cmp al,0x08     ; Backspace?
        jne os2
        dec di          ; Undo the backspace write
        cmp si, di
        je os2_
        dec di          ; Erase a character
        mov al, " "
        int int_output_char
        mov al, 0x08
        int int_output_char
        mov al, dl
os2:    int int_input_key  ; Read keyboard
        cmp al,0x0d     ; CR pressed?
        jne os10
        mov al,0x00
os10:   stosb           ; Save key in buffer
        jne os1         ; No, wait another key
        iret             ; Yes, return
os2_:   mov al, dl
        int int_output_char
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
	push ax
	mov al, 0x0a
        int int_output_char
        pop ax
os3:
        mov ah,0x0e     ; Output character to TTY
        mov bx,0x0007   ; Gray. Required for graphic modes
        int 0x10        ; BIOS int 0x10 = Video
irt:    iret

        ;
        ; Output string
        ;
        ; Entry:
        ;   SI = address
        ;
        ; Implementation:
        ;   It supposes that SI never points to a zero length string.
        ;
output_string:
        cs lodsb                ; Read character
        int int_output_char     ; Output to screen
        cmp al,0x00             ; Is it 0x00 (terminator)?
        jne output_string       ; No, the loop continues
        mov al,0x0d
        int int_output_char
        ret

        ;
        ; 'edit' command
        ;
edit_command:
        mov di,boot             ; Point to boot sector
os23:   push di
        mov al,'<'              ; Prompt character
        int int_input_line      ; Input line
        pop di
        cmp byte [si],0         ; Empty line?
        je os20                 ; Yes, jump
os19:   call xdigit             ; Get a hexadecimal digit
        jnc os23
        shl al,4
        xchg ax,cx
        call xdigit             ; Get a hexadecimal digit
        or al,cl
        stosb                   ; Write one byte
        jmp os19                ; Repeat loop to complete line
os20:        
        mov al,'*'              ; Prompt character
        int int_input_line      ; Input line with filename
        push si
        pop bx
        mov di,boot             ; Point to data entered
        int int_save_file       ; Save new file
        ret

        ;
        ; Convert ASCII letter to hexadecimal digit
        ;
xdigit:
        lodsb
        cmp al,0x00             ; Zero character marks end of line
        je os15
        sub al,0x30             ; Avoid spaces (anything below ASCII 0x30)
        jc xdigit
        cmp al,0x0a
        jc os15
        sub al,0x07
        and al,0x0f
        stc
os15:
        ret



        ;
        ; Commands supported by bootOS
        ;
commands:
        db 2,"ls"
        dw ls_command
        db 4,"edit"
        dw edit_command
        db 2,"rm"
        dw rm_command
	db 1, "/"
	dw 0x7c00

dap:
dap.header:
	db dap.end - dap	; header
dap.unused:
	db 0x00		; unused
dap.count:
	dw 0x0001	; number of sectors
dap.offset_offset:
	dw 0		; offset
dap.offset_segment:
	dw 0		; segment
dap.lba_lower:
	dd 0		; lba
dap.lba_upper:
	dd 0		; lba
dap.end:


int_restart:            equ 0x20
int_input_key:          equ 0x21
int_output_char:        equ 0x22
int_load_file:          equ 0x23
int_save_file:          equ 0x24
int_delete_file:        equ 0x25
int_input_line:		equ 0x26

interrupt_table:
        dw restart          ; int 0x20
        dw input_key        ; int 0x21
        dw output_char      ; int 0x22
        dw load_file        ; int 0x23
        dw save_file        ; int 0x24
        dw delete_file      ; int 0x25
	dw input_line	    ; int 0x26

error_msg:
	db 0x13, 0x00

%assign space_left 510-($-$$)
%warning space_left bytes left

        times space_left db 0x00
        db 0x55,0xaa            ; Make it a bootable sector

times (2880 * 512) - ($ - $$) db 0x00
