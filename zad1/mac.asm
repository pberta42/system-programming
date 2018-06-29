; SPaASM 2017 - Zadanie c. 1, Uloha c.1
; Autor: Peter Berta 
; Included MACRO file

print macro text						;Macro to print string
    mov dx, offset text
    mov ah, 9
    int 21h
    endm
    
printChar macro char					;Macro to print single character
    mov dl, char
    mov ah,2
    int 21h
    endm 

backToMenu macro
	mov ah, 8                           ;Console Character Input without Echo
    int 21h
    jmp getAction
	endm

printCount macro number
	mov ax, number   
    xor dx, dx
    call printNumber					;print number of lower cases
    endm
    

bruh macro reg							
	;Together with printNum, this macro prints a number with zero before if its 1 digit
	;Correctly dislplays hours and minutes

    mov ah, 0
    mov al, reg
	mov bl, ten
    div bl
    
    mov cl, al
    mov ch, ah
    
    printNum
    endm   
    
    
printNum macro 
    mov ah, 2
    
    add cl, 48
    add ch, 48
    
    mov dl, cl
    int 21h
   
    mov dl, ch
    int 21h  
    endm    
    

    
    
    
    
    