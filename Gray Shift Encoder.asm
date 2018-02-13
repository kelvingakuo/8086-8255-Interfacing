.MODEL SMALL  
;------------------------ VARIABLES ------------------- 
DATA SEGMENT
; Ports
PORTA EQU 00h   ;A: D7 - D0
PORTB EQU 02h   ;B0: RW, B1: RS, B2: EN <FOR LCD>  
PORTC EQU 04h
PCW EQU 06h

; Track Port Values
portAVal DB 0
portBVAl DB 0
portCVal DB 0
  

; The control word: All output: 1 MOD PORTA PORTCU MOD PORTB PORTCL -> 10001000b, 88h
controlWord EQU 88h

         
; UI Shiet
msg1 DB '8-BIT CONVERTER!!!$' 
msg2 DB '1:GRAY TO BIN. 0:BIN TO GRAY. # TO CONTINUE$'
msg3 DB 'INPUT 8 BITS. # TO CONTINUE$'
msg4 DB 'GRAY TO BIN!!!$'
msg5 DB 'BIN TO GRAY!!$'
dec1 DB 1
dec2 DB 0

; Temps 
choice DB ? 
bits DB ?
singleChar DB ?

; What in all that is holy is Gray Code?
; Bin: b0,b1,b2,b3  and Gray: g0,g1,g2,g3
; Gray to bin => g3, b3 XOR g2, b2 XOR g1, b1 XOR g0 
    ; XOR with self, after right shifting (SHR) once
; Binary to gray => b3, b3 XOR b2, b2 XOR b1, b1 XOR b0 
    ; XOR with self, shifted right by gradually decreasing powers of 2, starting at  2^n < data size

ENDS

STACK SEGMENT
    dw   128  dup(0)
ENDS

; --------------------------- THE LOGIC ----------------------------

CODE SEGMENT
start:
; ***** IF THIS DOESN'T WORK, YOU'RE SCREWED!!! *****
 ;CALL initialiseLCD   
 ;MOV DL, 2
 ;MOV DH, 1
 ;CALL setCursor
 ;LEA SI, msg1
 ;CALL writeString
 ;MOV CX, 60000
 ;CALL delay
 ;CALL clearLCD
;************************************ 

;---------------------------- MESSAGE DISPLAY MACRO -----------------
displayMessage MACRO message
    CALL initialiseLCD   
    MOV DL, 1
    MOV DH, 2
    CALL setCursor
    LEA SI, message
    CALL writeString
   
    MOV CX, 60000
    CALL delay
    CALL clearLCD
ENDM

;--------------------------------------------------------------------

; set segment registers:
    MOV AX, DATA
    MOV DS, AX
    MOV ES, AX
    
; Initialise PPI
    MOV AX, controlWord
    MOV DX, PCW
    OUT DX, AX

; Initialise LCD
    CALL initialiseLCD 

; Werocome
    displayMessage msg1

operations:
    displayMessage msg2
    CALL readUserValues
    CALL chosenOne
    CMP BP, 1
    JE toBin
    JNE toGray
    
    toBin:
        displayMessage msg4
        displayMessage msg3
        CALL readUserValues
        MOV BH, 0
        PUSH BX
        CALL clearLCD
        POP BX
        CALL grayToBin
        JMP operations
    
    toGray:
        displayMessage msg5
        displayMessage msg3
        CALL readUserValues
        MOV BH, 0
        PUSH BX
        CALL clearLCD
        POP BX
        CALL binToGray
        JMP operations

; -------------------------------PROCEDURES ----------------------------- 
delay PROC   ; Input - CX (# of loops) ; For 1MHz clock, 50 loops = 1ms
   JCXZ finishDelay     ; Jump when CX=0 
   loopDelay:
        loop loopDelay
   finishDelay:
        ret
delay ENDP
       
; 1. Write to Port A
writeToPortA PROC  ; Input- AL
    MOV DX, PORTA
    OUT DX, AL 
    
    MOV portAVal, AL
    ret
writeToPortA ENDP
    
; 2. Write to Port B
writeToPortB PROC  ; Input- AL
    MOV DX, PORTB
    OUT DX, AL
    
    MOV portBVal, AL
    ret
writeToPortB ENDP

; 3. Write to Port C
writeToPortC PROC  ; Input- AL
    MOV DX, PORTC
    OUT DX, AL
    
    MOV portCVal, AL
    ret
writeToPortC ENDP

; 4. Initialise LCD 
initialiseLCD PROC
    MOV AL, 0        ; RS=EN=RW=0 i.e Data Input, Write to LCD, Enable
    CALL writeToPortB
    
    MOV CX, 1000    ; Delay 20ms
    CALL delay
    
    MOV AH, 30h
    CALL routeCommand
    MOV CX, 250
    CALL delay
    
    MOV AH, 30h
    CALL routeCommand
    MOV CX, 50
    CALL delay
    
    MOV AH, 30h
    CALL routeCommand
    MOV CX, 500
    CALL delay
    
    MOV AH, 38h
    CALL routeCommand
    
    MOV AH, 0ch
    CALL routeCommand
    
    MOV AH, 01h
    CALL routeCommand 
    
    MOV AH, 06h
    CALL routeCommand
      
    ret
initialiseLCD ENDP

; 5. Route LCD commands
routeCommand PROC   ; Command - AH
    MOV AL, portBVal
    AND AL, 0FDh      ; Set RS=0
    CALL writeToPortB 
    
    MOV AL, AH         ; Write appropriate data to LCD
    CALL writeToPortA
    
    MOV AL, portBVal
    OR AL, 100b         ; Set EN=1
    CALL writeToPortB
    MOV CX, 50
    CALL delay
    
    MOV AL, portBVal
    AND AL, 0FBh        ; Set EN=0
    CALL writeToPortB
    MOV CX, 50
    CALL delay
    
    ret
routeCommand ENDP
     

; 4. Clear LCD
clearLCD PROC
    MOV AH, 1
    CALL routeCommand
    
    ret
clearLCD ENDP

; 5. Print Character on LCD
writeChar PROC  ; Input - AH
    MOV AL, portBVal 
    OR AL, 10b  ; Set RS=1
    CALL writeToPortB
    
    MOV AL, AH       ; Write char
    CALL writeToPortA
    
    MOV AL, portBVal
    OR AL, 100b         ; Set EN=1
    CALL writeToPortB
    MOV CX, 50
    CALL delay
    
    MOV AL, portBVal
    AND AL, 0FBh        ; Set EN=0
    CALL writeToPortB
    
    ret
writeChar ENDP

; 6. Print String on LCD
writeString PROC    ; Input =SI
    printChar:
        LODSB   ; Load [SI] into AL. Increment
        CMP AL, '$'
        JE finito
        JNE conti
        conti:
            MOV AH, AL
            CALL writeChar
            JMP printChar
        finito:
            ret
writeString ENDP     

; 7. Set Cursor on LCD
setCursor PROC    ;16x2 LCD. DH (Column 0-7). DL (Row 1 or 2)
    CMP DL, 1
    JE rowOne
    CMP DL, 2
    JE rowTwo
    JNE rudiBack
    
    rowOne:
        MOV AH, 80h
        JMP getPoint 
    rowTwo:         
        MOV AH, 0C0h
        JMP getPoint
        
        getPoint:
            ADD AH, DH
            CALL routeCommand 
    
    rudiBack:
        ret
setCursor ENDP
      
                                                        
; 8. Read Choice
readUserValues PROC 
    MOV DI, 0       ; For storing keyed-in input
    MOV BX, 0
    
    ; Check number and display to user 
    isItOne:
        MOV CX, 00ffh
        MOV AL, 11111110b           ; Initialise col one
        MOV DX, PORTC
        OUT DX, AL
        MOV CX, 20000
        CALL delay
        MOV AL,0
        MOV singleChar, 0        
        
        IN AL, DX           ; Read from PORTC
        MOV singleChar, AL
        CMP singleChar, 11101110b    ;Is it 1
        JNE isItZero
        MOV AH, '1'
        CALL writeChar
        MOV AH, 0
        MOV AL, 1
        MOV choice[DI], AL
        AND AL, 0fh ; ASCII to decimal
        SHL BX, 1
        OR BL, AL   ; Set LSB of BX with user input
        INC DI
        JMP isItOne
        
      isItZero:
          MOV AL, 11111101b          ; Initialise Col 2
          MOV DX, PORTC
          OUT DX, AL
          MOV CX, 20000
          CALL delay
          MOV AL,0
          MOV singleChar, 0         
        
          IN AL, DX 
          MOV singleChar, AL
          CMP singleChar, 01111101b     ; Is it 0
          JNE isItHash
          MOV AH, '0'
          CALL writeChar
          MOV AH, 0
          MOV AL, 0
          MOV choice[DI], AL
          AND AL, 0fh ; ASCII to decimal
          SHL BX, 1
          OR BL, AL
          INC DI
          JMP isItOne 
          
      isItHash:
          MOV CX, 00ffh
          MOV AL, 11111011b          ; Initialise Col three
          MOV DX, PORTC
          OUT DX, AL
          MOV CX, 20000
          CALL delay
          MOV AL,0
          MOV singleChar, 0         
        
          IN AL, DX
          MOV singleChar, AL
          CMP AL, 01111011b     ; Is it #
          JNE isItOne 
              
            
   goBack:
        ret
readUserValues ENDP

; 9. What's the choice
chosenOne PROC
    isItToBin:
        MOV BL, choice
        CMP BL, dec1
        JNE isItToGray
        MOV BP, 1
        ret
        
    isItToGray:
        MOV BP,0
        ret        
chosenOne ENDP

; 9. Gray to Binary
grayToBin PROC     ; BL has user gray input 
    MOV AL, BL
    SHR BL,4
    XOR AL, BL
    MOV BL, AL
    SHR BL, 2
    XOR AL, BL
    MOV AL, BL
    SHR BL, 1
    XOR AL, BL      ; AL has bin output in hex 
    
    ; Display
    MOV BP, 0
    MOV BL, AL 
    displayBinary:
        SHL BL, 1   ; Shift left. MSB goes into CF
        JNC zero    ; CF=0
        MOV AH, '1' ; CF=1
        CALL writeChar
        MOV CX, 60000
        CALL delay
        ADD BP,1
        CMP BP, 9
        JE finitoBinary
        JNE displayBinary
        
        zero:
            MOV AH, '0'
            CALL writeChar
            MOV CX, 60000
            CALL delay 
            ADD BP,1
            CMP BP, 9
            JE finitoBinary
            JNE displayBinary 
    
    
   finitoBinary:
   MOV AH, 'b'
   CALL writeChar
   MOV CX, 60000
   CALL delay
   CALL clearLCD
   
   ret
grayToBin ENDP

; 10. Binary to Gray
binToGray PROC     ; BL has user binary input
    MOV AL, BL
    SHR BL, 1
    XOR AL, BL     ; AL has gray output
    
    
    ; Display
    MOV BP, 9
    MOV BL, AL 
    displayGray:
        SHL BL, 1   ; Shift left. MSB goes into CF
        JNC zeroGray    ; CF=0
        MOV AH, '1' ; CF=1
        CALL writeChar
        MOV CX, 60000
        CALL delay
        DEC BP
        CMP BP, 0
        JE finitoGray
        JNE displayGray
        
        zeroGray:
            MOV AH, '0'
            CALL writeChar
            MOV CX, 60000
            CALL delay 
            DEC BP
            CMP BP, 0
            JE finitoGray
            JNE displayGray 
    
    
    finitoGray:
    
   MOV AH, 'g'
   CALL writeChar
   MOV CX, 60000
   CALL delay
   CALL clearLCD
    ret
binToGray ENDP
