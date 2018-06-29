; SPaASM 2017 - Zadanie c. 1, Uloha c.1
; Autor: Peter Berta 
; Additional function

include mac.asm
ten            equ 10
nameSize       equ 32
fileBufferSize equ 32768  ;max 32 768

data segment public

point		  dw 0

sumNum        dw 0
sumLow        dw 0
sumHigh       dw 0
sumOther      dw 0

sumNumAll     dw 0
sumLowAll     dw 0
sumHighAll    dw 0
sumOtherAll   dw 0

msgSumNum     db "Cisla: $"
msgSumLow	  db ", Male: $"
msgSumHigh	  db ", Velke: $"
msgSumOther   db ", Ostatne: $"
msgSumAll     db "Cely subor: $"

data ends


public countThem

extrn lastRead:word
extrn fileHandle:word

extrn msgNL:byte
extrn msgFileRead1:byte
extrn fileName:byte
extrn fileBuffer:byte
extrn msgFileReadErr:byte
extrn msgNoHandle:byte
extrn msgAccessDenied:byte
extrn msgOtherErr:byte

extrn printNumber:proc
extrn printError:proc


code segment public   
    assume cs:code,ds:data
   
countThem proc 
	;Procedure requires opened file - set file handle
	;Procedure counts the number of numbers, lower cases, higher cases and other chars
	;Procedure outputs the numbers for every line and the whole file

	mov sumNum, 0
	mov sumLow, 0
	mov sumHigh, 0
	mov sumOther, 0

	mov sumNumAll, 0
	mov sumLowAll, 0
	mov sumHighAll, 0
	mov sumOtherAll, 0

countThemBegin:

	mov point,0							;Reset pointer for file buffer

	mov ax, 3F00h						;Read from File or Device, Using a Handle
    mov bx, fileHandle					;Opened file handle
    mov cx, fileBufferSize              ;Number of bytes to read
    mov dx, offset fileBuffer			;Buffer from file
    int 21h								;Read menu selection by input
    
    jc countThemFailJ					;Read failed
    jmp countThemSucc					;Read successful
    
countThemFailJ:							;Increase jump size
    jmp countThemFail    
    
countThemSucc:								

    mov lastRead, ax					;Save the number of read characters
    
    mov bx, ax							;Unable to use ax for this
    mov fileBuffer[bx], '$'				;Set the finish dollar sign
    
countBegin:

	mov ax, lastRead					
	cmp ax, 0							;Did i read something?
	jz countThemEndJ					;No - finish counting
	jmp countThemEndN					;Yes - continue

countThemEndJ:							;Increase jump size
	jmp countThemEnd

countThemEndN:
    mov bx, point						;on which character am i
	cmp bx, lastRead					;did i read all of the buffer?
	jz doneCountingJ					;ill check if i need to read again
	
	jmp next0							;Continue

doneCountingJ:							;increase jump size
	jmp doneCounting

next0:
    cmp byte ptr[fileBuffer+bx],10		;is it end of the line
    jz next4							;go print the numbers for this line

    cmp byte ptr[fileBuffer+bx],'0'		;is it below zero
    jb next1
    
    cmp byte ptr[fileBuffer+bx],'9'		;is it above nine
    ja next1
    
    inc sumNum
    inc sumNumAll
    jmp next5							;go to next character
    
next1:									;not a number
    cmp byte ptr[fileBuffer+bx],'a'		;is it below a
    jb next2
    
    cmp byte ptr[fileBuffer+bx],'z'		;is it above z
    ja next2
    
    inc sumLow
    inc sumLowAll
    jmp next5							;go to next character
    
next2:									;not a number nor lower case
    cmp byte ptr[fileBuffer+bx],'A'		;is it below A
    jb next3
    
    cmp byte ptr[fileBuffer+bx],'Z'		;is it below Z
    ja next3
    
    inc sumHigh
    inc sumHighAll
    jmp next5							;go to the next character
    
next3:									;it is something else
    inc sumOther
    inc sumOtherAll
    jmp next5							;go to the next character
    
next4:									;print results for this line
	
	print msgSumNum
	printCount sumNum					;print number of numbers
    
	print msgSumLow
	printCount sumLow					;print number of lower cases
    
	print msgSumHigh
    printCount sumHigh					;print number of higher cases
    
	print msgSumOther
    printCount sumOther					;print number of other characters
    
    print msgNL							;go to new line
    
    mov sumNum,0						;reset the numbers for a new line
    mov sumLow,0
    mov sumHigh,0
    mov sumOther,0
    
next5:									;go to next character
    inc point							;increase pointer in file buffer
    
	jmp countBeginJ						;check another character
    
countBeginJ:							;increase jump size
    jmp countBegin    
    
doneCounting:							;am i finished?
    mov ax, lastRead
    cmp ax, fileBufferSize				;compare characters read with buffer size
    jz countThemBeginJ					;if the file buffer size was full, ill read again
    jmp countThemEnd					;if it was not, im on the end and im done
    
countThemBeginJ:
    jmp countThemBegin    
    
countThemFail:
	call printError						;print error message
    ret

countThemEnd:
	print msgSumNum
	printCount sumNum					;print number of numbers
    
	print msgSumLow
	printCount sumLow					;print number of lower cases
    
	print msgSumHigh
    printCount sumHigh					;print number of higher cases
    
	print msgSumOther
    printCount sumOther					;print number of other characters
    
    print msgNL							;go to new line
    
	print msgSumAll

	print msgSumNum
	printCount sumNumAll				;print number of numbers
    
	print msgSumLow
	printCount sumLowAll				;print number of lower cases
    
	print msgSumHigh
    printCount sumHighAll				;print number of higher cases
    
	print msgSumOther
    printCount sumOtherAll				;print number of other characters
    
    ret
    
countThem endp
    
code ends
end