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
controlWord EQU 10001000b

;Users
user1 DB 'Welcome Abdul$'
user2 DB  'Welcome Aaden$'
user3 DB  'Welcome Drake$'
user4 DB  'Welcome Daryl$'
user5 DB  'Welcome Ellyn$'
user6 DB  'Welcome Edmon$'
user7 DB  'Welcome Peele$'
user8 DB  'Welcome Frank$'
user9 DB  'Welcome Essex$'
user10 DB 'Welcome Larue$'


; Corresponding PINs
pin1 DB 0
pin2 DB 1
pin3 DB 2
pin4 DB 3
pin5 DB 4 
pin6 DB 5
pin7 DB 6
pin8 DB 7
pin9 DB 8
pin10 DB 9

; Corresponding Bank Balances
balance1 DW 200            
balance2 DW 500            
balance3 DW 235          
balance4 DW 130
balance5 DW 500
balance6 DW 450
balance7 DW 100
balance8 DW 900
balance9 DW 105
balance10 DW 205
         
; UI Shiet
msg1 DB  'THE BANK. PESA OTAS NIGGA!!!$'
msg2 DB  'ENTER PIN (1 CHAR) # TO CONTINUE$'
msg3 DB  'INCORRECT PIN. PLEASE TRY AGAIN$'
msg4 DB ' TRIES LEFT$'
msg5 DB  '1: WITHDRAW, 2: BALANCE, 3: DEPOSIT.# TO CONTINUE$'
msg6 DB  'AMOUNT TO WITHDRAW. # TO CONTINUE$'
msg7 DB  'AMOUNT TO DEPOSIT (<=100) # TO CONTINUE$'
msg8 DB ' PRESENT IN YOUR ACCOUNT$'
msg9 DB ' SUCCESSFULLY WITHDRAWN$' 
msg10 DB ' SUCCESSFULLY DEPOSITED$'
msg11 DB  'MAX TRIES REACHED. ACCOUNT LOCKED. BYE!!$'  
msg12 DB  'YOU HAVE INSUFFICIENT MONIES. AIM LOWER$'

tries DB 4 
dec1 DB 1
dec2 DB 2
dec3 DB 3

; Temp vars
buffer DB ?     ; Entered pin
pesa DW ?
singleChar DB ?
routedBalance DW ?
whatUser DB ? 
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

;---------------------------- MACROS -----------------
; 1. Display Text
displayMessage MACRO message
    CALL clearLCD
    CALL initialiseLCD   
    MOV DL, 1
    MOV DH, 1
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

; Werocome
    displayMessage msg1

operations:
    ;Ask for pin
    displayMessage msg2
    CALL readUserValues ;Read user values     
    CALL routeBalance   ; Get appropriate user
    CMP BP, 1   ; Max tries reached
    JE operations
    JNE getToBusiness
    getToBusiness:
        displayMessage msg5
        CALL readUserValues
        CALL chosenOne
        CMP BP, 1   ;Withdraw
        JE letUsWithdraw
        CMP BP, 2   ;Balance
        JE seeBalance
        CMP BP, 3   ; Deposit
        JE letUsDeposit
        CMP BP, 4   ; Some other number
        JE getToBusiness
        
        letUsWithdraw:
            CALL getMoney
            JMP operations
        
        seeBalance:                
            CALL showBalance
            JMP operations
        
        letUsDeposit:
            CALL doDeposit
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
      
                                                         

; 8. Read from PORT C (Keypad) CL- cols, CU-rows
; Rows have a signal. Key press completes a circuit, therefore, for the number '1':
; C4=1,C5=0,C6=0,C7=0 AND C0=1,C1=0,C2=0, C3=0
; For number '9':
; C4=0,C5=0,C6=1,C7=0... C0=0,C1=0,C2=1  <THIS LOGIC FAILED TO WORK>
readUserValues PROC 
    MOV DI, 0       ; For storing keyed-in input
    
    ; Check number and display to user 
    isItOne:
        MOV CX, 00ffh
        MOV AL, 11111110b          ; Initialise Col one
        MOV DX, PORTC
        OUT DX, AL
        MOV CX, 20000
        CALL delay
        MOV AL,0
        MOV singleChar, 0        
        
        IN AL, DX           ; Read from PORTC
        MOV singleChar, AL
        CMP singleChar, 11101110b    ;Is it 1
        JNE isItFour
        MOV AH, '1'
        CALL writeChar
        MOV AL, '1'
        MOV AH, 0
        MOV AL, 1
        MOV pesa[DI], AX
        MOV buffer[DI], AL
        INC DI
        JMP isItOne
         
    isItFour:
         CMP singleChar, 11011110b    ; Is it 4
         JNE isItSeven
         MOV AH, '4'
         CALL writeChar
         MOV AL, '4'
         MOV AH, 0
         MOV AL, 4
         MOV pesa[DI], AX
         MOV buffer[DI], AL
         INC DI
         JMP isItOne
       
     isItSeven:
          CMP singleChar, 10111110b     ; Is it 7
          JNE isItTwo
          MOV AH, '7'
          CALL writeChar
          MOV AL, '7'
          MOV AH, 0
          MOV AL, 7 
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne
          
     isItTwo:
          MOV CX, 00ffh
          MOV AL, 11111101b          ; Initialise Col two
          MOV DX, PORTC
          OUT DX, AL
          MOV CX, 20000
          CALL delay
          MOV AL,0
          MOV singleChar, 0         
        
          IN AL, DX
          MOV singleChar, AL      
          CMP singleChar, 11101101b     ; Is it 2
          JNE isItFive
          MOV AH, '2'
          CALL writeChar
          MOV AL, '2'
          MOV AH, 0
          MOV AL, 2
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne
          
      isItFive:
          CMP singleChar, 11011101b     ; Is it 5
          JNE isItEight
          MOV AH, '5'
          CALL writeChar
          MOV AL, '5'
          MOV AH, 0
          MOV AL, 5
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne
          
      isItEight:
          CMP singleChar, 10111101b     ; Is it 8
          JNE isItZero
          MOV AH, '8'
          CALL writeChar
          MOV AL, '8'
          MOV AH, 0
          MOV AL, 8
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne 
          
      isItZero:
          CMP singleChar, 01111101b     ; Is it 8
          JNE isItThree
          MOV AH, '0'
          CALL writeChar
          MOV AL, '0'
          MOV AH, 0
          MOV AL, 0
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne
          
      isItThree:
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
          CMP singleChar, 11101011b    ; Is it 3
          JNE isItSix
          MOV AH, '3'
          CALL writeChar
          MOV AL, '3'
          MOV AH, 0
          MOV AL, 3
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne 
          
      isItSix:
          CMP singleChar, 11011011b     ; Is it 6
          JNE isItNine
          MOV AH, '6'
          CALL writeChar
          MOV AL, '6'
          MOV AH, 0
          MOV AL, 6
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne
          
      isItNine:
          CMP singleChar, 10111011b    ; Is it 9
          JNE isItHash
          MOV AH, '9'
          CALL writeChar
          MOV AL, '9'
          MOV AH, 0
          MOV AL, 9
          MOV pesa[DI], AX
          MOV buffer[DI], AL
          INC DI
          JMP isItOne 
          
       isItHash:
          CMP AL, 01111011b     ; Is it #
          JNE isItOne
              
            
   goBack:        
        ret
readUserValues ENDP        

; 9. Route balances appropriately AKA Point to correct customer 
routeBalance PROC     ; Pin - buffer  
    isItPin1:
        MOV DL, buffer
        CMP DL, pin1
        JNE isItPin2
        displayMessage user1
        MOV CX, balance1
        MOV routedBalance, CX
        MOV whatUser, 1
        ret 
    
    isItPin2:
        MOV DL, buffer
        CMP DL, pin2
        JNE isItPin3
        displayMessage user2
        MOV CX, balance2
        MOV routedBalance, CX
        MOV whatUser, 2
        ret
     
     isItPin3:
        MOV DL, buffer
        CMP DL, pin3 
        JNE isItPin4
        displayMessage user3
        MOV CX, balance3
        MOV routedBalance, CX
        MOV whatUser, 3
        ret
        
     isItPin4:
        MOV DL, buffer
        CMP DL, pin4 
        JNE isItPin5
        displayMessage user4
        MOV CX, balance4
        MOV routedBalance, CX
        MOV whatUser, 4
        ret
        
      isItPin5:
        MOV DL, buffer
        CMP DL, pin5 
        JNE isItPin6
        displayMessage user5
        MOV CX, balance5
        MOV routedBalance, CX
        MOV whatUser, 5
        ret
     
     isItPin6:
        MOV DL, buffer
        CMP DL, pin6 
        JNE isItPin7
        displayMessage user6
        MOV CX, balance6
        MOV routedBalance, CX
        MOV whatUser, 6 
        ret
        
     isItPin7:
        MOV DL, buffer
        CMP DL, pin7
        JNE isItPin8
        displayMessage user7
        MOV CX, balance7
        MOV routedBalance, CX
        MOV whatUser, 7
        ret 
        
     isItPin8:
        MOV DL, buffer
        CMP DL, pin8 
        JNE isItPin9
        displayMessage user8
        MOV CX, balance8
        MOV routedBalance, CX 
        MOV whatUser, 8
        ret
        
     isItPin9:
        MOV DL, buffer
        CMP DL, pin9 
        JNE isItPin10
        displayMessage user9
        MOV CX, balance9
        MOV routedBalance, CX
        MOV whatUser, 9 
        ret
        
    isItPin10:
        MOV DL, buffer
        CMP DL, pin10
        JNE wrongPin
        displayMessage user10
        MOV CX, balance10
        MOV routedBalance, CX
        MOV whatUser, 10
        ret
        
     wrongPin:
        displayMessage msg3
        MOV AH, tries
        ADD AH, 0x30h
        CALL writeChar
        displayMessage msg4        
        CMP tries, 0
        JNE someInfoFirst
        JE noLuck
        someInfoFirst:
            displayMessage msg2
            CALL readUserValues ;Read user
            SUB tries, 1
            JMP isItPin1
        
        noLuck:    
            displayMessage msg11
            MOV BP, 1
            ret    
         
routeBalance ENDP

; 10. Check user choice
chosenOne PROC
    isItWithdraw:
        MOV BL, buffer
        CMP BL, dec1
        JNE isItBalance
        MOV BP, 1
        ret
        
    isItBalance:
        MOV BL, buffer
        CMP BL, dec2
        JNE isItDeposit 
        MOV BP, 2
        ret
        
    isItDeposit:
        MOV BL, buffer
        CMP BL, dec3
        JNE noneOfThose
        MOV BP, 3
        ret     
        
    noneOfThose:
        MOV BP, 4
        ret
chosenOne ENDP

; 11. Display balance
showBalance PROC
    CALL clearLCD 
    MOV AX, routedBalance 
    MOV BX, 0
    MOV DX, 0 
    
    MOV BP, 0
    mazingaombwe:
        MOV BX, 10
        DIV BX
        PUSH DX
        
        INC BP
        CMP BP,3
        JNE mazingaombwe
        
        MOV BP, 0
        display:
            POP BX
            MOV BH, 0
            ADD BL, 0x30h   ;Displayable hex
            MOV AH, BL
            CALL writeChar
            MOV CX, 60000
            CALL delay
            INC BP
            CMP BP, 3 
            JE enof
            JNE display 
            
            enof:
                MOV AH, '$'
                CALL writeChar
                MOV CX, 60000
                CALL delay
                displayMessage msg8
                ret      
showBalance ENDP

; 12. Perform deposit
doDeposit PROC
    displayMessage msg7
    CALL  readUserValues ; pesa  and routedBalance
    
    ;MOV AX, pesa
    MOV BX, routedBalance
    
    ADD BX, pesa      ; This is not working
    MOV routedbalance, 0
    MOV routedBalance, BX
    CALL changeOrigi 
    displayMessage msg10
    CALL showBalance
    
    ret    
doDeposit ENDP

; 13. Perform Withdrawal
getMoney PROC
    displayMessage msg6
    CALL readUserValues ; pesa and routedBalance
    
    MOV AX, 0
    MOV BX, 0
    MOV AX, pesa
    MOV BX, routedBalance
    
    CMP AX, BX
    JGE thisIsTooMuch
    JNGE toaPesa 
    
    thisIsTooMuch:
        displayMessage msg12
        ret
            
    toaPesa:
        MOV AX, pesa
        MOV BX, routedBalance 
        SUB BX, AX    ; This is not working
        MOV routedBalance, BX
        CALL changeOrigi
        displayMessage msg9
        CALL showBalance
        ret   
getMoney ENDP

; 14. Change original balances appropriately
changeOrigi PROC
    isUser1:
        CMP whatUser, 1
        MOV CX, routedBalance
        JNE isUser2
        MOV balance1, CX
        ret
          
    isUser2:
        CMP whatUser, 2
        MOV CX, routedBalance
        JNE isUser3
        MOV balance2, CX
        ret
        
    isUser3:
        CMP whatUser, 3
        MOV CX, routedBalance
        JNE isUser4
        MOV balance3, CX
        ret
        
    isUser4:
        CMP whatUser, 4
        MOV CX, routedBalance
        JNE isUser5
        MOV balance4, CX
        ret
        
    isUser5:
        CMP whatUser, 5
        MOV CX, routedBalance
        JNE isUser6
        MOV balance5, CX
        
     isUser6:
        CMP whatUser, 6
        MOV CX, routedBalance
        JNE isUser7
        MOV balance6, CX
        
    isUser7:
        CMP whatUser, 7
        MOV CX, routedBalance
        JNE isUser8
        MOV balance7, CX
        
    isUser8:
        CMP whatUser, 8
        MOV CX, routedBalance
        JNE isUser9
        MOV balance8, CX
        
    isUser9:
        CMP whatUser, 9
        MOV CX, routedBalance
        JNE isUser10
        MOV balance9, CX 
        
    isUser10:
        CMP whatUser, 10
        MOV CX, routedBalance
        MOV balance10, CX
        ret
        
changeOrigi ENDP
    
ENDS

END start ; set entry point and stop the assembler.
