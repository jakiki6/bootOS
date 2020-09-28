; Entry: DS:BX = Filename terminated with zero.
;        ES:DI = Point to source data (512 bytes)
; Output: Carry flag = 0 = Found, 1 = Not found.
load_file:
	iret

; Entry: DS:BX = Filename terminated with zero.
;        ES:DI = Point to data target (512 bytes)
; Output: Carry flag = 0 = Successful. 1 = Error.
save_file:
        iret

; Entry: DS:BX = Filename terminated with zero.
; Output: None
delete_file:
        iret

; Entry: ES:DI = Point to data target (seperated by \r)
;        DS:BX = Directory name terminated with zero.
; Output: CL = Number of file.
list_files:
	mov cl, 0x00
	ret
