; SPaASM 2017 - Zadanie c. 1, Uloha c.1
; Autor: Peter Berta 
; Main .ASM file

include mac.asm

ten            equ 10
hundred		   equ 100
nameSize       equ 32
fileBufferSize equ 32768  ; 32 768

zas segment stack
    dw 128 dup (?)
zas ends

public lastRead
public fileHandle
public msgNl
public msgFileRead1
public fileName
public fileBuffer
public msgFileReadErr

public printNumber
public printError

public msgError01
public msgError02
public msgError03
public msgError04
public msgError05
public msgError06
public msgOtherErr


data segment public
msg1 db 10,13,"SPaASM - Peter Berta - Zadanie 1, Uloha 1",10,13    
     db "Zvolte pozadovanu akciu: ",10,13
     db " - 1: zadat meno suboru",10,13
     db " - 2: vypisat obsah suboru",10,13
     db " - 3: vypisat dlzku suboru",10,13
     db " - 4: vykonat ulohu c.1",10,13
     db " - 5: uknocit program",10,13
     db '$'
     
msgfout          db 10,13,"Zadal si nazov suboru: $"
msgfin           db 10,13,"Zadaj nazov suboru: ",10,13,'$'
msgcas           db "Cas: $"
msgNoFileName    db "Ziaden nazov suboru na otvorenie!$"

msgFileOpen1     db 10,13,"Subor s nazvom '$"
msgFileOpen2     db "' sa podarilo otvorit...$"
msgFileErr       db "' sa NEPODARILO otvorit!$"

msgFileRead1     db 10,13,"Subor s nazvom '$"
msgFileRead2     db "' sa podarilo precitat...$"
msgFileReadErr   db "' sa NEPODARILO precitat!$"

msgError01		 db 10,13,"Neplatne cislo funkcie!$"
msgError02       db 10,13,"Subor nenajdeny!$"
msgError03       db 10,13,"Neplatna cesta k suboru!$"
msgError04       db 10,13,"Ziaden HANDLE!$"
msgError05       db 10,13,"Nepovoleny pristup!$"
msgError06       db 10,13,"Neplatny HANDLE!$"
msgOtherErr      db 10,13,"Ina chyba!$"

msgFileSize      db 10,13,"Velkost suboru je: $"
msgFileBytes     db " bytov$"

msgNL            db 10,13,'$'

fnbuffer db nameSize
len      db (0)
fileName db nameSize DUP (?)

fileBuffer      db fileBufferSize DUP ('$')
                db '$'

lastRead        dw 0
fileHandle	    dw 0
filePartSize    dw 0  
number			db 0

data ends

extrn countThem:proc

code segment public
    assume cs:code, ds:data, ss:zas   
    
start:
    mov ax, seg data                    ;Initialization
    mov ds, ax
    
getAction:
	clc									;Clear the carry flag
    call clearScreen					;Clear the screen
    call showTime						;Show real time and date
    print msg1							;Print MENU
    
    mov ah, 8                           ;Console Character Input without Echo
    int 21h								;read menu selection by input
    
    cmp al, '1'                         ;to read file name
    jz readfn
    cmp al, '2'                         ;to print file
    jz printf
    cmp al, '3'                         ;to print length of the file
    jz printl
    cmp al, '4'                         ;to execute the task
    jz functionJ
    cmp al, '5'                         ;to end
    jz finishJ
    cmp al, 1b                          ;also ESC to end
    jz finishJ
    
    jmp getAction                       ;to start again
    
functionJ:								;increase jump size
    jmp function
finishJ:								;increase jump size
    jmp finish

readfn:
    print msgfin                        ;Enter file name
    
    mov ah, 10                          ;Buffered input
    mov dx, offset fnbuffer             ;Buffer for filename
    int 21h
    
    mov bh, 0                           ;resetting contents of bh(bx)
    mov bl, len                         ;number of letters read
    mov fileName[bx], '$'               ;ending of the string
    
    print msgfout                       ;You have entered file:
    print fileName                      ;The file name
	
    mov fileName[bx], 0                 ;Ending with the null sign for ASCIIZ

    backToMenu							;Shows menu
		
printf:
    call openFile                       ;Procedure for opening file
	jc goBack							;If carry is set, dont continue, show error
    
	call readFile                       ;Procedure for reading file
	jc goBack							;If carry is set, dont continue, show error

    call closeFile						;Procedure for closing file
    
    backToMenu							;Shows menu

printl:
	call openFile						;Procedure for opening file
    jc goBack							;If carry is set, dont continue, show error
	
	call getFileLength					;Procedure for getting the file length
	jc goBack							;If carry is set, dont continue, show error

	call closeFile						;Procedure for closing file

    backToMenu							;Shows menu

function:
	call openFile						;Procedure for opening file
	jc goBack							;If carry is set, dont continue, show error
	    
    call countThem						;External procedure for counting characters

	call closeFile						;Procedure for closing file

goBack:
    backToMenu							;Shows menu

finish: 
    mov ax, 4c00h                       ;ending
    int 21h
    
;--------------------------------------------------------------------------------
printNumber proc
	;IN - DX:AX, BX
	;Procedure outputs number in DX:AX registers

    xor cx,cx							;Reset register contents for loop
	xor bx, bx							;Resetting contents
    mov bl, ten							;Divide by ten
    
pncycle:
    div bx								;Divide number by ten
    
    inc cx								;Iterate
    add dx, 48							;Make it an ASCII char
    push dx								;PUSH the number on stack
    xor dx, dx							;Reset contents
    
    cmp ax, 0							;Done dividing?
    jnz pncycle							;if not, next iteration
    
    mov ah, 2							;Character Output
    
pnwrite:
    pop dx								;Pop the number from stack
    int 21h
    loop pnwrite						;Loop until done

    ret									;Return

printNumber endp
    
;--------------------------------------------------------------------------------
openFile proc                           ;procedure for opening file
	;Procedure tries to open a file
	;If successful, sets the length of file name and file handle

	cmp len, 0							;No filename to open
	jnz openFileCont					;Continue if name seems fine

noFileName:
	print msgNoFileName
	stc									;Set carry for easier error handling
	ret									;Finish procedure

openFileCont:
    mov ah, 3dh                         ;Open a file
    mov al, 0                           ;Only for reading
    mov dx, offset fileName            
    int 21h
    
    jc failure                          ;If carry is set, opening failed
    
openFileSucc:
    mov fileHandle, ax                  ;save file handle for later
    jmp openFileEnd                     ;To end the procedure
    
failure:
    call printError						;Procedure for printing error message
	stc
    
openFileEnd:
    ret
openFile endp 

;--------------------------------------------------------------------------------
readFile proc
	;Procedure tries to read from an opened file using handle
	;IN - needs correctly set handle
	;OUT - outputs the file contents

readFileBegin:
    mov ah, 3Fh							;Read from File or Device, Using a Handle
    mov bx, fileHandle
    mov cx, fileBufferSize              ;Number of bytes to read
    mov dx, offset fileBuffer			;File buffer in data segment
    int 21h
    
    jc readFileErr						;Something went wrong if carry is set
    
	mov filePartSize, 0					;Reset the file part size

readFileSucc:
	xor bx,bx							;BX is used as a pointer in file buffer
    add filePartSize, ax				;Number of characters read
    
    cmp ax, fileBufferSize				;Was Buffer full? If yes, read again... 
    jz readAgain
    
	mov ah, 02h							;Character Output

readFilePrint:
	mov dl, fileBuffer[bx]				;Set argument for output function
	int 21h
	
	inc bx								;Increase for next iteration

	cmp bx, filePartSize				;Have i printed the entire file part?
	jnz readFilePrint					;If not, continue printing
    jmp readFileEnd						;If yes, finish reading
    
readAgain:
	mov ah, 02h							;Character Output
	xor bx, bx

readFilePrint2:							;Print full file buffer
	mov dl, fileBuffer[bx]				;Set argument for output function
	int 21h										
	
	inc bx								;Increase for next iteration

	cmp bx, filePartSize				;Have i printed the entire file part?
	jnz readFilePrint2					;If not, continue printing
    jmp readFileBegin					;If yes, read from file another part
    
readFileErr:
	call printError						;Procedure for printing error message
	stc									;Set carry for error handling

readFileEnd:
    ret
    
readFile endp    

;--------------------------------------------------------------------------------
closeFile proc
	;Procedure tries to close file using opened handle
	;Needs a correct file handle
	;Doesnt output anything if successful

    mov ah, 3eh							;Close a File Handle
    mov bx, fileHandle
    int 21h
    
    jc closeFileErr						;Something went wrong
    ret
    
closeFileErr:
    call printError						;Procedure for printing error message
    
closeFileEnd:
    ret    
    
closeFile endp

;--------------------------------------------------------------------------------
getFileLength proc
	;Procedure prints file length using LSEEK
	;Moves the file pointer on the end and prints its position
	;Needs correctly opened file handle

	print msgFileSize					;The file size is...

    mov ah, 42h							;Move File Pointer (LSEEK)
    mov al, 2							;Move pointer CX:DX bytes from END of file
    mov bx, fileHandle					;file handle
    xor cx,cx							;resetting contents
    xor dx,dx							;resetting contents
    int 21h

    jc printlErr						;fail if carry is set
    
    call printNumber					;fileSize
    print msgFileBytes					;bytes

    jmp printlEnd
    
printlErr:
	call printError						;Procedure for printing error message
	stc									;Set carry for error handling

printlEnd:
	ret
getFileLength endp

;--------------------------------------------------------------------------------
clearScreen proc
    mov ax, 3							;Set Video Mode
    int 10h
    
    ret
clearScreen endp

;--------------------------------------------------------------------------------
printError proc
	;Procedure prints the correct error message
	;Gets error code from ax register

    cmp ax, 1
    jz errorCode01
	cmp ax, 2
    jz errorCode02
	cmp ax, 3
    jz errorCode03
	cmp ax, 4
    jz errorCode04
	cmp ax, 5
    jz errorCode05
	cmp ax, 6
    jz errorCode06
	jmp errorCodeOther

errorCode01:
	print msgError01
	ret
errorCode02:
	print msgError02
	ret
errorCode03:
	print msgError03
	ret
errorCode04:
	print msgError04
	ret
errorCode05:
	print msgError05
	ret
errorCode06:
	print msgError06
	ret
errorCodeOther:
	print msgOtherErr
    
printErrorEnd:
	ret
printError endp

;--------------------------------------------------------------------------------
showTime proc
	;Procedure prints the TIME and DATE

    print msgcas			

    mov ah, 2ah						;get date
    int 21h
    
    push cx							;cx = year
    push dx							;dh = month dl = day
    
    mov ah, 2ch						;get time
    int 21h
    
    push dx							;dh = seconds
    push cx							;cl = minutes ch = hours  
      
    pop bx							;take hours and minutes
    
	mov dh, bl
	bruh bh							;print the hours
	printChar ':'

	bruh dh							;print the minutes
					
    printChar ':'
    
    pop bx
    
	bruh bh							;print the seconds
    
    printChar ' '
    
    pop bx

	mov number, bh
	xor dx, dx
	xor ax, ax
	mov al, bl
	call printNumber				;print the day

	printChar '.'

	xor dx, dx
	xor ax, ax
	mov al, number
	call printNumber				;print the month
    
    printChar '.'
    printChar ' '
    
    pop bx							;year
    
    mov ax, bx
	xor dx, dx
	call printNumber
	
    ret
showTime endp    
;--------------------------------------------------------------------------------
code ends
end start

