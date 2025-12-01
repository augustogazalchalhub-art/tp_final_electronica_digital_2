LIST P=16F887
#INCLUDE <P16F887.INC>

; CONFIG1    
__CONFIG _CONFIG1, _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2    
__CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
    
ESTADO		    EQU 0X20 ;(primer msj,flag lleno,teclado o llenando, antirrebote, espera)
CONT_ANTI	    EQU 0X21 ;ANTIRREBOTE
COL		    EQU 0X22 ;TECLADO
COLMASK		    EQU 0X23 ;TECLADO
INDICE		    EQU 0X24 ;TECLADO
DISPLAY_ACTIVO	    EQU 0X27 ;DISPLAY
UNIDADES	    EQU 0X28
DECENAS		    EQU 0X29
CENTENAS	    EQU 0X30
VOLUMEN_ACTUAL_BIN  EQU 0x33 ;Para guardar ADRESH
TECLA_NUEVA	    EQU 0X42
W_TEMP		    EQU 0X70
STATUS_TEMP	    EQU 0X71
VOL_OBJ_UNI	    EQU 0X46
VOL_OBJ_DEC	    EQU 0X47
VOL_OBJ_CEN	    EQU 0X48
BIN		    EQU	0X49
CARRY		    EQU 0X50
BCD_UNI		    EQU 0X51
BCD_DEC		    EQU 0X52
BCD_CEN		    EQU 0X53
UNI_A		    EQU 0X54
UNI_B		    EQU 0X55
UNI_R		    EQU 0X56
DEC_A		    EQU 0X57
DEC_B		    EQU 0X58
DEC_R		    EQU 0X59
CEN_A		    EQU 0X60
CEN_B		    EQU 0X61
CEN_R		    EQU 0X62
INDICE_UART	    EQU 0X63
DIRECCION_MENSAJE   EQU 0X64	    
		    
ORG 0X00
GOTO START

ORG 0X04
GOTO ISR
      
ORG 0X05

MENSAJE_VOLUMEN_LIMITE:
    DT  "Ingrese volumen limite (150-300):", 0x0D, 0x0A, 0x00

MENSAJE_LLENANDO:
    DT  "Llenando recipiente...", 0x0D, 0x0A, 0x00

MENSAJE_VOLUMEN_ALCANZADO:
    DT  "VOLUMEN ALCANZADO. Bomba detenida.", 0x0D, 0x0A, 0x00

START: 
    BANKSEL TRISD 
    CLRF TRISD		; Puerto C salida a Segmentos
    MOVLW 0XF0 ;1111 0000 RB4/5/6/7 como entrada (filas) RB0/1/2/3 como salida (col)
    MOVWF TRISB
    MOVLW 0X20		; '00100000' RA5 entrada
    MOVWF TRISA
    CLRF TRISE;
    BCF TRISC, 6	; TX como salida
    BSF TRISC, 7	; RX como entrada (aunque no se use)
    
    BANKSEL OPTION_REG
    MOVLW 0X04		; '00000100' PS 1:32 RBPU ACTIVADA
    MOVWF OPTION_REG
    
    BANKSEL WPUB
    MOVLW 0XF0		; Pull-Ups en RB4-RB7
    MOVWF WPUB
    
    BANKSEL IOCB
    MOVLW 0XF0		; Int por cambio RB4-RB7
    MOVWF IOCB
    
    BANKSEL ANSEL
    MOVLW 0X10		; '00010000' ANS4 como analógico (RA5)
    MOVWF ANSEL
    CLRF ANSELH
    BANKSEL ADCON0
    MOVLW 0X51		; '01010001' Fosc/8, canal AN4, ADC encendido
    MOVWF ADCON0
    
    BANKSEL ADCON1
    MOVLW 0X00
    MOVWF ADCON1	; VREF+ = VCC, VREF- = VSS, justificación izquierda
    
    CONFIG_UART:
    BANKSEL TXSTA         
    MOVLW 0X24
    MOVWF TXSTA ;'00100100' Habilita la transmisión, Asincrónico, Alta velocidad
    
    BANKSEL RCSTA           
    BSF RCSTA, SPEN     ; Habilita el puerto serie (SPEN=1)
        
    BANKSEL BAUDCTL        
    BCF BAUDCTL, BRG16  ; Generador de 8 bits
    
    BANKSEL SPBRG          
    MOVLW 0X19          ; SPBRG = 25 para 9600 baudios 
    MOVWF SPBRG

    BANKSEL PIE1
    BSF PIE1, ADIE	; Habilitar interrupción ADC
    BANKSEL INTCON
    BSF INTCON, PEIE	; Habilitar interrupciones periféricas
    BSF INTCON, GIE	; Habilitar interrupciones globales
    BSF INTCON, T0IE
    BSF INTCON, RBIE
    MOVLW 0X64		; (256-156 =100) 
    MOVWF TMR0		; 157 * 32 = 5024 = 5ms
        
    CLRF DISPLAY_ACTIVO
    MOVLW 0X00
    MOVWF CENTENAS
    MOVWF DECENAS
    MOVWF UNIDADES
    CLRF ESTADO
    CLRF PORTD
    CLRF PORTE
  
    BSF ESTADO, 4
    
LOOP: 
    GOTO LOOP

TABLA_7SEG:  
    ;devuelve un binario que se manda al port
    ;para mostrar los segmentos deseados
ADDWF   PCL,F
    RETLW   B'00111111'      ; 0
    RETLW   B'00000110'      ; 1
    RETLW   B'01011011'      ; 2
    RETLW   B'01001111'      ; 3
    RETLW   B'01100110'      ; 4
    RETLW   B'01101101'      ; 5
    RETLW   B'01111101'      ; 6
    RETLW   B'00000111'      ; 7
    RETLW   B'01111111'      ; 8
    RETLW   B'01101111'      ; 9

TABLA_BCD_7SEG:
    ;agarra el indice (uni,dec,cen) del escaneo y devuelve
    ;el numero en binario
ADDWF   PCL,F
    RETLW   0X01	; 1
    RETLW   0X02	; 2
    RETLW   0X03	; 3
    RETLW   0X00
    RETLW   0X04	; 4
    RETLW   0X05	; 5
    RETLW   0X06	; 6
    RETLW   0X00
    RETLW   0X07	; 7
    RETLW   0X08	; 8
    RETLW   0X09	; 9
    RETLW   0X0C	; C
    RETLW   0X00	     
    RETLW   0X00	; 0
    RETLW   0X00	    
    RETLW   0X0D	; D
 
ISR:
  MOVWF W_TEMP
  SWAPF STATUS, W
  MOVWF STATUS_TEMP
  
  BTFSC INTCON,TMR0IF	    ; fue del timer?
  CALL ISR_TIMER  
  
  BTFSC INTCON, RBIF 
  CALL ISR_TECLADO
  
  BANKSEL PIR1
  BTFSC PIR1, ADIF
  CALL ISR_ADC
  
  SWAPF STATUS_TEMP, W
  MOVWF STATUS
  SWAPF W_TEMP, F
  SWAPF W_TEMP, W
  RETFIE 
  
  ISR_TECLADO:
    BTFSC ESTADO, 0	    ; SOLO TRABAJAMOS SI ESTA EN ESPERA
    GOTO FIN_TECLADO
    
    BCF INTCON, RBIE	    ; deshabilitar interrupcion
    BSF ESTADO, 1	    ; ANTIRREBOTE 1
    BSF ESTADO, 0	    ; HAY Q PROCESAR
    MOVLW 0X05		    ; 5 CICLOS PARA ANTIREBOTE
    MOVWF CONT_ANTI
    
    FIN_TECLADO:
    MOVF PORTB, W	    ; Leo para limpiar el mismatch
    BCF INTCON, RBIF	    ; Limpio la bandera de interrupcion
    RETURN
    
  ISR_TIMER:
    MOVLW 0X64		    ; 100
    MOVWF TMR0
    BCF INTCON, TMR0IF 
    
    BTFSC ESTADO, 4	    ; El mensaje solo sale al principio
    CALL PRIMER_MENSAJE    
    
    BTFSC ESTADO, 1	    ; salto el antirrebote?
    CALL  ANTIREBOTE
    
    BTFSC ESTADO, 1	    ; termino el tiempo de antirrebote?
    GOTO REFRESCAR_DISPLAY
    
    BTFSC ESTADO, 0	    ; HAY Q PROCESAR?
    CALL  PROCESAR_BOTON
    
    BTFSS ESTADO, 2	    ; ¿Está activo el modo llenado?
    GOTO REFRESCAR_DISPLAY  ; NO: Salto (No arranco ADC)
    
    BANKSEL ADCON0
    BTFSS ADCON0, GO	    ; Si no está convirtiendo...
    BSF ADCON0, GO	    ; ...iniciar nueva conversión
    
    REFRESCAR_DISPLAY:
    BCF PORTA, 0
    BCF PORTA, 1
    BCF PORTA, 2
    MOVF DISPLAY_ACTIVO, W  ; 0 1 2
    ADDWF PCL, F
    GOTO MOSTRAR_UNIDADES
    GOTO MOSTRAR_DECENAS
    GOTO MOSTRAR_CENTENAS
    
    MOSTRAR_UNIDADES:
    BSF PORTA, 0	    ; RA0
    MOVF UNIDADES, W
    CALL TABLA_7SEG
    MOVWF PORTD
    GOTO CONTADOR_DISPLAY
    
    MOSTRAR_DECENAS:
    BSF PORTA, 1	    ; RA1
    MOVF DECENAS, W
    CALL TABLA_7SEG
    MOVWF PORTD
    GOTO CONTADOR_DISPLAY
    
    MOSTRAR_CENTENAS:
    BSF PORTA, 2	    ; RA2
    MOVF CENTENAS, W
    CALL TABLA_7SEG
    MOVWF PORTD 
    GOTO CONTADOR_DISPLAY
    
    CONTADOR_DISPLAY:
    INCF DISPLAY_ACTIVO, F
    MOVLW 0X03
    SUBWF DISPLAY_ACTIVO, W
    BTFSC STATUS, C
    CLRF DISPLAY_ACTIVO
    GOTO FIN_ISR_TMR0
    
    FIN_ISR_TMR0:
    RETURN
    
    PRIMER_MENSAJE:
    
    BCF ESTADO, 4
    MOVLW HIGH(MENSAJE_VOLUMEN_LIMITE)
    MOVWF PCLATH
    MOVLW LOW(MENSAJE_VOLUMEN_LIMITE)
    MOVWF DIRECCION_MENSAJE
    CALL ENVIAR_MENSAJE
    RETURN
    
    ISR_ADC:
    BANKSEL PIR1
    BTFSS PIR1, ADIF	    ; Verificar si es interrupción del ADC
    GOTO FIN_ADC_ISR	    ; Salir si no lo es
    
    ; Leectura de los 8 bits ALTOS del ADC
    BANKSEL ADRESH
    MOVF ADRESH, W	    ; Leer byte alto
    BANKSEL PORTA
    MOVWF VOLUMEN_ACTUAL_BIN; Cargar los 8 bits altos ; ESCALON
    ;pasaje de escalon a ml (adc-20) *3
    resto 20
    MOVLW 0X14 ; 20
    SUBWF VOLUMEN_ACTUAL_BIN, F
    ;antes de multiplicar por 3 paso a bcd
    MOVF VOLUMEN_ACTUAL_BIN, W
    MOVWF BIN
    CALL BIN_TO_BCD
    MOVF BCD_UNI, W
    MOVWF UNIDADES
    MOVF BCD_DEC, W
    MOVWF DECENAS
    MOVF BCD_CEN, W
    MOVWF CENTENAS
    
    CALL MULT_BCD_3
    MOVF UNI_R, W
    MOVWF UNIDADES
    MOVF DEC_R, W
    MOVWF DECENAS
    MOVF CEN_R, W
    MOVWF CENTENAS
   
    COMPARAR_BCD:
    ;centenas
    MOVF VOL_OBJ_CEN, W
    SUBWF CENTENAS, W       ; CENTENAS - VOL_OBJ_CEN
    BTFSS STATUS, C         ; Si C=0 ? CENTENAS < OBJ_CEN ? No Alcanzado
    GOTO NIVEL_NO_ALCANZADO
    BTFSS STATUS, Z         ; Si no son iguales ? CENTENAS > OBJ_CEN ? Alcanzado  
    GOTO NIVEL_ALCANZADO
    
    ; decenas
    MOVF VOL_OBJ_DEC, W
    SUBWF DECENAS, W        ; DECENAS - VOL_OBJ_DEC
    BTFSS STATUS, C         ; Si C=0 ? DECENAS < OBJ_DEC ? No Alcanzado
    GOTO NIVEL_NO_ALCANZADO
    BTFSS STATUS, Z         ; Si no son iguales ? DECENAS > OBJ_DEC ? Alcanzado
    GOTO NIVEL_ALCANZADO
    
    ; unidades
    MOVF VOL_OBJ_UNI, W
    SUBWF UNIDADES, W       ; UNIDADES - VOL_OBJ_UNI
    BTFSS STATUS, C         ; Si C=0 ? UNIDADES < OBJ_UNI ? No Alcanzado
    GOTO NIVEL_NO_ALCANZADO
    GOTO NIVEL_ALCANZADO

NIVEL_ALCANZADO:
    BTFSC ESTADO, 3	    ; FLAG_ MSJ ENVIADO LLENO
    GOTO FIN_ADC_ISR
    
    MOVLW HIGH(MENSAJE_VOLUMEN_ALCANZADO)
    MOVWF PCLATH
    MOVLW LOW(MENSAJE_VOLUMEN_ALCANZADO)
    MOVWF DIRECCION_MENSAJE
    CALL ENVIAR_MENSAJE
    
    BSF ESTADO, 3	    ; FLAG ENVIADO LLENO
    BCF PORTE, 1

    GOTO FIN_ADC_ISR
    
NIVEL_NO_ALCANZADO:
    BCF ESTADO, 3	    ; FLAG ENVIADO NO LLENANDO
    BSF PORTE, 1

    GOTO FIN_ADC_ISR
    
FIN_ADC_ISR:
    BANKSEL PIR1
    BCF PIR1, ADIF
    RETURN
    
    PROCESAR_BOTON:
    CALL ESCANEO
    MOVF INDICE, W
    CALL TABLA_BCD_7SEG
    MOVWF TECLA_NUEVA
    
    BTFSC ESTADO, 2	    ; llenando o teclado?
    GOTO PROCESAR_LLENO
    GOTO PROCESAR_TECLADO
    
    PROCESAR_TECLADO:
    MOVF TECLA_NUEVA, W
    XORLW 0X0D		    ; D
    BTFSC STATUS, Z
    GOTO ACCION_ENTER
    
    MOVF TECLA_NUEVA, W
    XORLW 0X0C		    ; C
    BTFSC STATUS, Z
    GOTO ACCION_RESET
    
    GOTO ACCION_TECLA
    
    GOTO FIN_PROCESAR_BOTON
    
PROCESAR_LLENO:
    BTFSC ESTADO,3
    GOTO PROCESO_RESET
    RETURN

PROCESO_RESET:
    MOVF TECLA_NUEVA, W
    XORLW 0X0C		    ; C
    BTFSC STATUS, Z	    ; Si Z=1, sí es la tecla RESET
    GOTO ACCION_RESET
    GOTO FIN_PROCESAR_BOTON
    
    ACCION_TECLA:
    MOVF DECENAS, W
    MOVWF CENTENAS
    
    MOVF UNIDADES,W
    MOVWF DECENAS
    
    MOVF TECLA_NUEVA, W
    MOVWF UNIDADES
    GOTO FIN_PROCESAR_BOTON
    
    ACCION_RESET:
    CLRF UNIDADES;
    CLRF DECENAS;
    CLRF CENTENAS
    CLRF VOL_OBJ_CEN
    CLRF VOL_OBJ_DEC  
    CLRF VOL_OBJ_UNI
    BCF ESTADO,3
    BCF ESTADO, 2
    BCF PORTE, 1	    ; APAGO LED
    
    MOVLW HIGH(MENSAJE_VOLUMEN_LIMITE)
    MOVWF PCLATH
    MOVLW LOW(MENSAJE_VOLUMEN_LIMITE)
    MOVWF DIRECCION_MENSAJE
    CALL ENVIAR_MENSAJE
    
    GOTO FIN_PROCESAR_BOTON
    
    ACCION_ENTER:
    BSF ESTADO, 2	    ; prendo modo llenando
    
    MOVLW HIGH(MENSAJE_LLENANDO)
    MOVWF PCLATH
    MOVLW LOW(MENSAJE_LLENANDO)
    MOVWF DIRECCION_MENSAJE
    CALL ENVIAR_MENSAJE
    
    MOVF UNIDADES,W
    MOVWF VOL_OBJ_UNI
    MOVF DECENAS,W
    MOVWF VOL_OBJ_DEC
    MOVF CENTENAS,W
    MOVWF VOL_OBJ_CEN
    
    BCF PIR1, ADIF
    BSF PIE1, ADIE
    BSF ADCON0, GO
    GOTO FIN_PROCESAR_BOTON
    
    FIN_PROCESAR_BOTON:
    CALL RESET_ESTADO;
    RETURN
    
    ESCANEO:
    ;entra valor de teclado matricial
    ;salida indice (0-15)
    CLRF COL		    ; COL EMPIEZA EN 0
    MOVLW 0X0E		    ; 0000 1110 
    MOVWF COLMASK 
    
    ESCANEAR_FILAS:
    CLRF INDICE
    MOVF COLMASK,W
    MOVWF PORTB
    BTFSS PORTB, 4
    GOTO OFFSET_COL
    CALL SUMO_4
    BTFSS PORTB, 5
    GOTO OFFSET_COL
    CALL SUMO_4
    BTFSS PORTB, 6
    GOTO OFFSET_COL
    CALL SUMO_4
    BTFSS PORTB, 7
    GOTO OFFSET_COL
    INCF COL,F
    BSF STATUS, C 
    RlF COLMASK, F 
    
    MOVLW 0X04
    SUBWF COL, W
    BTFSS STATUS,Z 
    GOTO ESCANEAR_FILAS
    RETURN 
    
    OFFSET_COL:
    MOVF COL, W
    ADDWF INDICE,F
    RETURN
    
    SUMO_4:
    MOVLW 0X04
    ADDWF INDICE, F
    RETURN
    
    ANTIREBOTE:
    DECFSZ CONT_ANTI, F
    RETURN
    BANKSEL PORTB
    MOVLW 0x00		    ; Poner 0000 en las 4 columnas (RB0-RB3)
    MOVWF PORTB		    ; (El resto de los bits no importa porque son entrada
    MOVF PORTB, W
    ANDLW 0XF0
    XORLW 0XF0
    BTFSC STATUS, Z 
    GOTO ANTIRREBOTE_FALLO  ; antirrebote falla
    BCF ESTADO, 1	    ; BAJO BANDERA ANTIRREBOTE
    RETURN 
    
    ANTIRREBOTE_FALLO:
    CALL RESET_ESTADO
    RETURN
    
    RESET_ESTADO:
    BCF ESTADO, 0
    BCF ESTADO, 1	    ; Limpia las banderas de "procesando" y "antirrebote"
    BCF INTCON, RBIF	    ; Asegura que la bandera de interrupción esté limpia
    BTFSS ESTADO, 2	    ; SI ESTOY LLENANDO NO REACTIVO INTERRUPCION
    BSF INTCON, RBIE	    ; ¡Crucial! Reactiva la interrupción del teclado
    RETURN
    
    
    BIN_TO_BCD:
    ;BINARIO A  BCD de 8 bits 
    ;entrada BIN
    ;salida bcd_uni, bcd_dec, bcd_cen
    
	CLRF BCD_UNI
	CLRF BCD_DEC
	CLRF BCD_CEN
	RESTO_100:
	MOVLW 0X64
	SUBWF BIN, W
	BTFSS STATUS,C
	GOTO RESTO_10

	MOVWF BIN
	INCF BCD_CEN,F
	GOTO RESTO_100
	RESTO_10:
	MOVLW 0X0A
	SUBWF BIN, W
	BTFSS STATUS, C
	GOTO FIN_BCD

	MOVWF BIN
	INCF BCD_DEC, F
	GOTO RESTO_10

	FIN_BCD:
	MOVF BIN, W
	MOVWF BCD_UNI

	RETURN

    MULT_BCD_3:
    ; entrada: unidades, decenas, centenas
    ; salida: uni_r,dec_r,cen_r
    MOVF UNIDADES, W
    MOVWF UNI_A
    MOVWF UNI_B
    MOVF DECENAS, W
    MOVWF DEC_A
    MOVWF DEC_B
    MOVF CENTENAS, W
    MOVWF CEN_A
    MOVWF CEN_B
    CALL SUMA_BCD	    ; = MULTIPLICAR POR 2
    
    MOVF UNIDADES, W
    MOVWF UNI_A
    MOVF UNI_R, W
    MOVWF UNI_B
    MOVF DECENAS, W
    MOVWF DEC_A
    MOVF DEC_R, W
    MOVWF DEC_B
    MOVF CENTENAS, W
    MOVWF CEN_A
    MOVF CEN_R, W
    MOVWF CEN_B
    CALL SUMA_BCD
    RETURN
	SUMA_BCD:
	CLRF CARRY
	MOVF UNI_A, W
	ADDWF UNI_B, W
	MOVWF UNI_R
	MOVLW 0X0A
	SUBWF UNI_R, W
	BTFSS STATUS, C	    ; C = 0 => W<10 , C=1 => W>=10
	GOTO SUMA_DECENAS
	MOVWF UNI_R
	MOVLW 0X01
	MOVWF CARRY
	SUMA_DECENAS:
	MOVF DEC_A, W
	ADDWF DEC_B, W	    ; A+B
	MOVWF DEC_R 
	MOVF CARRY, W
	ADDWF DEC_R, F	    ; sumo carry
	CLRF CARRY	    ; limpio carry
	MOVLW 0X0A
	SUBWF DEC_R, W
	BTFSS STATUS, C
	GOTO SUMA_CENTENAS
	MOVWF DEC_R
	MOVLW 0X01
	MOVWF CARRY
	SUMA_CENTENAS:
	MOVF CEN_A,W
	ADDWF CEN_B,W
	MOVWF CEN_R
	MOVF CARRY, W
	ADDWF CEN_R,F	    ; sumo carry
	RETURN
	
ENVIAR_CARACTER:
    BANKSEL TXSTA
  ESPERO_TX:
    BTFSS TXSTA, TRMT	    ; ¿TSR vacío?
    GOTO ESPERO_TX
    
    BANKSEL TXREG
    MOVWF TXREG		    ; Cargo W en el TXREG
    BANKSEL PORTA
    RETURN

ENVIAR_MENSAJE:
    CLRF INDICE_UART	    ; Empiezo de la primer letra
  LOOP_MENSAJE:
    MOVF DIRECCION_MENSAJE, W 
    ADDWF INDICE_UART, W    ; Le sumo a la dirección de la tabla el índice
    
    CALL TRAER_CARACTER	    ; Voy a la tabla y vuelvo con el carácter en W

    ADDLW 0X00		    ; Solo para afectar el Z
    BTFSC STATUS, Z	    ; ¿W = 0? (fin del mensaje)
    RETURN                 
    CALL ENVIAR_CARACTER    ; No fue 0, envía el siguiente carácter
    
    INCF INDICE_UART, F	    ; Voy al siguiente carácter
    GOTO LOOP_MENSAJE 

TRAER_CARACTER:
    MOVWF PCL	  ; Voy a la dirección del mensaje y vuelvo con el carácter en W
    
END
