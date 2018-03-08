.org 0x0
.section .iv,"a"

_start:     

    interrupt_vector:

        b RESET_HANDLER
    .org 0x08
        b SOFT_HANDLER
    .org 0x18
        b IRQ_HANDLER
    .org 0x100
.text

    @ Text -> 0x77800700
    RESET_HANDLER:

        .set CSPR_MODE_CLEAR,   0xFF

        set_variaveis_ctrl:
            @Marca que nenhuma funcao de alarme ou callback esta sendo EXECUTANDO_FUNCAO
            ldr r0, =EXECUTANDO_FUNCAO
            mov r1, #0
            str r1, [r0]

            @ Marca callbacks comm inativas
            ldr r0, =CALLBACKS_ATIVAS
            mov r1, #0
            str r1, [r0]

            @ Zera o contador
            ldr r2, =CONTADOR  @lembre-se de declarar esse contador em uma secao de dados! 
            mov r0, #0
            str r0, [r2]

            ldr r2, =N_ATUAL_CALLBACKS
            mov r0, #0
            str r0, [r2]

            ldr r2, =ALARMS_ATIVOS
            mov r0, #0
            str r0, [r2]

            ldr r2, =N_ATUAL_ALARMS
            mov r0, #0
            str r0, [r2]    

        set_vetor_interrupcao:
            @Faz o registrador que aponta para a tabela de interrupções apontar para a tabela interrupt_vector
            ldr r0, =interrupt_vector
            mcr p15, 0, r0, c12, c0, 0

        set_pilhas_all_modes:    
            @muda para o supervisor
            mrs r0, cpsr
            bic r0, r0, #CSPR_MODE_CLEAR
            orr r0, r0, #0x13
            msr cpsr, r0

            @alcoca memoria para a pilha do SVC
            
            ldr r13, =PILHA_SVC

            @muda para o irq
            mrs r0, cpsr
            bic r0, r0, #CSPR_MODE_CLEAR
            orr r0, r0, #0x12
            msr cpsr, r0

            @aloca memoria para a pilha do IRQ 

            ldr r13, =PILHA_IRQ

            @muda devolta para modo System
            mrs r0, cpsr                   
            bic r0, r0, #CSPR_MODE_CLEAR                
            orr r0, r0, #0x13                
            msr cpsr, r0

            @aloca memoria para a pilha do USER/SYSTEM
            ldr r13, =PILHA_USER_SYSTEM

        SET_GPT:
            @constantes.
            .set GPT_CR,                0x53FA0000
            .set GPT_PR,                0x53FA0004
            .set GPT_OCR1,              0x53FA0010
            .set GPT_IR,                0x53FA000C
            .set TIME_SZ,               0x00010000


            @escreve no registrador GPT_CR (control register) o valor 0x00000041 que irá habilitá-lo e configurar o clock_src para periférico.
            ldr r1, =GPT_CR
            mov r0, #0x041
            str r0, [r1]

            @Zera GPT_PR
            ldr r1, =GPT_PR
            mov r0, #0x0
            str r0, [r1]

            @Valor de ciclos do periférico para incrementar o contador
            ldr r1, =GPT_OCR1
            mov r0, #0x20
            str r0, [r1]

            @Para demonstrar interesse nesse tipo específico de interrupção do GPT, grave 1 no registrador GPT_IR
            ldr r1, =GPT_IR
            mov r0, #0x01
            str r0, [r1]

        SET_TZIC:
            @ Constantes para os enderecos do TZIC
            .set TZIC_BASE,             0x0FFFC000
            .set TZIC_INTCTRL,          0x0
            .set TZIC_INTSEC1,          0x84 
            .set TZIC_ENSET1,           0x104
            .set TZIC_PRIOMASK,         0xC
            .set TZIC_PRIORITY9,        0x424

            @ Liga o controlador de interrupcoes
            @ R1 <= TZIC_BASE

            ldr r1, =TZIC_BASE

            @ Configura interrupcao 39 do GPT como nao segura
            mov r0, #(1 << 7)
            str r0, [r1, #TZIC_INTSEC1]

            @ Habilita interrupcao 39 (GPT)
            @ reg1 bit 7 (gpt)

            mov r0, #(1 << 7)
            str r0, [r1, #TZIC_ENSET1]

            @ Configure interrupt39 priority as 1
            @ reg9, byte 3

            ldr r0, [r1, #TZIC_PRIORITY9]
            bic r0, r0, #0xFF000000
            mov r2, #1
            orr r0, r0, r2, lsl #24
            str r0, [r1, #TZIC_PRIORITY9]

            @ Configure PRIOMASK as 0
            eor r0, r0, r0
            str r0, [r1, #TZIC_PRIOMASK]

            @ Habilita o controlador de interrupcoes
            mov r0, #1
            str r0, [r1, #TZIC_INTCTRL]

            @instrucao msr - habilita interrupcoes
            msr  CPSR_c, #0x53       @ SUPERVISOR mode, IRQ/FIQ enabled

        SET_GPIO:

            .set DR,            0x53F84000
            .set GDIR,          0x53F84004
            .set GDIR_MASK,     0xFFFC003E
            .set PSR,           0x53F84008

            @Seta pinos de entrfada e saída do GPIO
            ldr r2, =GDIR
            ldr r1, =GDIR_MASK
            str r1, [r2]

        go_to_user_code:
            
            .set USR_CODE, 0x77812000

            @muda para o usuario
            mrs r0, cpsr
            bic r0, r0, #CSPR_MODE_CLEAR
            orr r0, r0, #0x10
            msr cpsr, r0
            
            ldr r13, =PILHA_USR

            ldr pc, =USR_CODE

    IRQ_HANDLER:
        
        .set GPT_SR,            0x53FA0008

        push {r0-r12, lr}            
        @Gravando GPT_SR para GPT saber que estamos tratando a interrupção

        incializa_gpt_sr:
            ldr r2, =GPT_SR
            mov r1, #0x1
            str r1, [r2]

        contador_add:
            @Incrementa contador
            ldr r2, =CONTADOR
            ldr r1, [r2]
            add r1, r1, #1
            str r1, [r2]

        check_tempo_verificar:
            @verifica se eh multiplo de 128 (momento em que verifica alarmes e callbacks)
            lsl r1, r1, #25
            cmp r1, #0
            bne fim_irq_handler

            @verifica se ja nao existe uma funcao sendo executada
            ldr r0, =EXECUTANDO_FUNCAO
            ldr r1, [r0]
            cmp r1, #1
            beq fim_irq_handler

        inicio_verifica_callbacks:
            @verifica call_backs
            ldr r8, =VETOR_CALLBACKS
            ldr r5, =MAX_CALLBACKS
            mov r4, #0

        loop_verifica_callbacks: @verifica cada posicao ocupada do vetor de callbacks
            cmp r4, r5
            beq inicio_verifica_alarmes

            @verifica se posicao esta ativa
            ldr r0, =CALLBACKS_ATIVAS
            ldr r0, [r0]
            mov r1, #1
            and r0, r0, r1, lsl r4
            cmp r0, #0
            beq continua_loop_callback


            mov r10, #12
            mul r6, r4, r10 @r6 = posicao a ser olhada no vetor de calbacks
            ldr r0, [r8, r6] @r0 = sonar a ser testado
            
            @chama sonar
            mov r7, #16
            svc 0x0

            @compara valor recebido com limiar
            add r6, #4
            ldr r1, [r8, r6]
            cmp r0, r1
            bge continua_loop_callback

            executa_callback:

                push {r0-r12, lr}

                @marca que uma funcao esta sendo executada
                ldr r0, =EXECUTANDO_FUNCAO
                mov r1, #1
                str r1, [r0]

                @muda para o usuario
                mrs r0, cpsr
                bic r0, r0, #CSPR_MODE_CLEAR
                orr r0, r0, #0x50
                msr cpsr, r0

                @executa funcao do callback
                add r6, #4
                ldr r0, [r8, r6]
                blx r0

                mov r7, #23
                svc 0x0

                @marca que uma funcao acabou de ser executada
                ldr r0, =EXECUTANDO_FUNCAO
                mov r1, #0
                str r1, [r0]
                   
                pop {r0-r12, lr}

                @desativa callback
                ldr r0, =CALLBACKS_ATIVAS
                ldr r2, [r0]
                mov r1, #1
                bic r2, r2, r1, lsl r4
                str r2, [r0]

            continua_loop_callback:
                add r4, r4, #1
                b loop_verifica_callbacks

        inicio_verifica_alarmes:

            @verifica alarmes
            ldr r8, =VETOR_ALARMS
            ldr r5, =MAX_ALARMS
            mov r4, #0

        loop_verifica_alarmes: @verifica cada posicao ocupada do vetor de alarmes
            cmp r4, r5
            beq fim_irq_handler

            @verifica se posicao esta ativa
            ldr r0, =ALARMS_ATIVOS
            ldr r0, [r0]
            mov r1, #1
            and r0, r0, r1, lsl r4
            cmp r0, #0
            beq continua_loop_alarmes


            mov r10, #8
            mul r6, r4, r10 @r6 = posicao a ser olhada no vetor de alarmes
            ldr r0, [r8, r6] @r0 = sonar a ser testado
            
            
            @chama sonar
            mov r7, #20
            svc 0x0

            @compara valor recebido com limiar
            add r6, #4
            ldr r1, [r8, r6]
            cmp r0, r1
            bls continua_loop_alarmes

            executa_alarme:
                
                push {r0-r12, lr}

                @marca que uma funcao esta sendo executada
                ldr r0, =EXECUTANDO_FUNCAO
                mov r1, #1
                str r1, [r0]

                @muda para o usuario
                mrs r0, cpsr
                bic r0, r0, #CSPR_MODE_CLEAR
                orr r0, r0, #0x50
                msr cpsr, r0

                muda_modo:

                @executa funcao do alarme
                sub r6, r6, #4
                ldr r0, [r8, r6]
                blx r0
                
                mov r7, #23
                svc 0x0
                aqui: @0x7780092C
               
                @marca que a funcao acabou de ser executada
                ldr r0, =EXECUTANDO_FUNCAO
                mov r1, #0
                str r1, [r0]

                pop {r0-r12, lr}

                @desativa alarme
                ldr r0, =ALARMS_ATIVOS
                ldr r2, [r0]
                mov r1, #1
                bic r2, r2, r1, lsl r4
                str r2, [r0]

            continua_loop_alarmes:
                add r4, r4, #1
                b loop_verifica_alarmes    

        fim_irq_handler:
            pop {r0-r12, lr}
            sub lr, lr, #4
            movs pc, lr 

    SOFT_HANDLER:
        push {r4-r11, lr}    
        cmp r7, #16
        beq read_sonar    
        cmp r7, #17
        beq register_proximity_callback
        cmp r7, #18
        beq set_motor_speed
        cmp r7, #19
        beq set_motors_speed
        cmp r7, #20
        beq get_time
        cmp r7, #21
        beq set_time
        cmp r7, #23
        beq return_irq_mode

        set_alarm: 
            .set MAX_ALARMS, 8
            @carrega N_ATUAL_CALLBACKS
            ldr     r6, =N_ATUAL_ALARMS
            ldr     r4, [r6]
            @carrega MAX_CALLBACKS
            ldr     r5, =MAX_ALARMS
            @Testa se ja existe um numero maximo de callbacks
            cmp     r4, r5
            moveq   r0, #-1
            beq     fim_soft_handler
            @Testa se o tempo atual do sistema eh superior ao pedido
            mov     r4, r1
            ldr     r5, =CONTADOR
            ldr     r5, [r5] 
            cmp     r4, r5
            movle   r0, #-2
            ble     fim_soft_handler

            @carrega o ponteiro do vetor com as callbacks
            ldr     r5, =VETOR_ALARMS
            ldr     r6, =ALARMS_ATIVOS
            ldr     r6, [r6]
            
            @testa se eh a primeira callback a ser arquivada
            mov     r8, #0
            mov     r7, r6
            and     r7, r7, #1
            cmp     r7, #0
            beq     graveCallbackA

            loopCallbackA:
                
                add     r5, r5, #8
                lsl     r6, r6, #1
                add     r8, r8, #1
                mov     r7, r6
                and     r7, r7, #1
                cmp     r7, #0
                bne     loopCallbackA

            graveCallbackA:
                
                add     r7, r7, #1
                lsl     r7, r7, r8
                ldr     r8, =ALARMS_ATIVOS
                ldr     r6, [r8]
                orr     r6, r6, r7
                str     r6, [r8]

            callbackStepA:
                str     r0, [r5]
                str     r1, [r5, #4]
                ldr     r6, =N_ATUAL_ALARMS
                ldr     r4, [r6]

                b fim_soft_handler

        set_time:
            ldr r1, =CONTADOR
            str r0, [r1]
            b fim_soft_handler

        get_time:
            ldr r1, =CONTADOR
            ldr r0, [r1] 
            b fim_soft_handler

        set_motors_speed:

            cmp      r0, #0
            movlt    r0, #-2
            blt      fim_soft_handler      
            cmp      r0, #63
            movgt    r0, #-2
            bgt      fim_soft_handler

            write_motors_HalfValid:
                
                cmp      r1, #0
                movlt    r0, #-2
                blt      fim_soft_handler      
                cmp      r1, #63
                movgt    r0, #-2
                bgt      fim_soft_handler

            write_motors_valid:

                .set motorsMask, 0xFFFC0000

                ldr     r6, =DR
                ldr     r4, [r6]
                
                lsl     r0, r0 , #7
                orr     r0, r0, r1
                lsl     r0, r0, #19

                ldr     r5, =motorsMask
                bic     r4, r4, r5

                orr     r4, r4, r0

                str     r4, [r6]

                b fim_soft_handler

        set_motor_speed:
            
            cmp     r0, #0
            beq     write_motor_HalfValid
            cmp     r0, #1
            movne   r0, #-1
            bne     fim_soft_handler

            write_motor_HalfValid: 
                cmp      r1, #0
                movlt    r0, #-2
                blt      fim_soft_handler      
                cmp      r1, #63
                movgt    r0, #-2
                bgt      fim_soft_handler

            write_motor_valid:
                
                .set motor0Mask, 0x03FC0000
                .set motor1Mask, 0xFE000000

                ldr     r4, =DR
                ldr     r4, [r4]

                cmp     r0, #0
                ldr     r5, =motor0Mask
                ldr     r6, =motor1Mask
                biceq   r4, r4, r5       
                bicne   r4, r4, r6

                lsl     r1, r1, #1 
                
                cmp     r0, #0
                lsleq   r1, r1, #18
                lslne   r1, r1, #25

                orr     r4, r4, r1

                ldr     r5, =DR
                str     r4, [r5]

                b fim_soft_handler

        register_proximity_callback:
            
            .set MAX_CALLBACKS, 8

            mov r7, r0 @identificador do sonar
            mov r8, r1 @distancia
            mov r9, r2 @funbcao a ser chamada

            @carrega N_ATUAL_CALLBACKS em r4
            ldr     r6, =N_ATUAL_CALLBACKS
            ldr     r4, [r6]
            @carrega MAX_CALLBACKS
            ldr     r5, =MAX_CALLBACKS
            @Testa se ja existe um numero maximo de callbacks
            cmp     r4, r5
            moveq   r0, #-1
            beq     fim_soft_handler
            @Testa se o sensor requisitado existe
            cmp     r7, #15
            movhi   r0, #-2
            bhi     fim_soft_handler

            @encontra primeira posicao vaga e salva em r2
            ldr r1, =CALLBACKS_ATIVAS
            ldr r1, [r1]
            mov r2, #0
            
            loop_finda_inative_callback:
                mov r3, #1
                and r0, r1, r3, lsl r2
                cmp r0, #0
                addne r2, r2, #1
                bne loop_finda_inative_callback

                @marca posicao como ocupada
                mov r3, #1
                orr r1, r1, r3, lsl r2 
                ldr r0, =CALLBACKS_ATIVAS
                str r1, [r0]

                @encontra posicao no vetor para salvar a callback
                mov r0, #12
                mov r1, r2
                mul r2, r1, r0
                @salva valores na posicao encontrada do vetor
                ldr r0, =VETOR_CALLBACKS
                str r7, [r0, r2]
                add r2, r2, #4
                str r8, [r0, r2]
                add r2, r2, #4
                str r9, [r0, r2]

                @incrementa numero de callbacks
                add r4, #1
                str r4, [r6]
                
                b       fim_soft_handler

        read_sonar:
            @verifica se identificador do sonar passado eh valido
            cmp     r0, #15
            
            @Caso de sonar valido
            bls     read_sonar_valid

            @caso entrada nao seja valida, retorna -1
            mov     r0, #-1
            b       fim_soft_handler

            read_sonar_valid:
                @Escreve sonar_id em sonar_mux
                ldr     r1, =DR
                ldr     r2, [r1]
                bic     r2, r2, #0x3C @limpa região de sonar_mux
                orr     r2, r2, r0, lsl #2  @escreve valores em sonar_mux
                str     r2, [r1]

                @Seta triger como zero
                ldr     r1, =DR
                ldr     r2, [r1]
                bic     r2, r2, #2
                str     r2, [r1]

                @delay 15ms
                mov     r1, #0x4000
            loop_delay1:
                sub     r1, r1, #1
                cmp     r1, #0
                bne     loop_delay1

                @Seta triger como um
                ldr     r1, =DR
                ldr     r2, [r1]
                orr     r2, r2, #2
                str     r2, [r1]

                @delay 15ms
                mov     r1, #0x4000

            loop_delay2:
                sub     r1, r1, #1
                cmp     r1, #0
                bne     loop_delay2    

                @Seta triger como zero
                ldr     r1, =DR
                ldr     r2, [r1]
                bic     r2, r2, #2
                str     r2, [r1]

                @espera a flag se tornar 1
            verifica_flag:
                ldr     r1, =DR
                ldr     r2, [r1]
                and     r2, r2, #1
                cmp     r2, #0
                bne     continua_leitura_sonar
                @delay 10ms e volta
                mov     r1, #0x2800

            loop_delay3:
                sub     r1, r1, #1
                cmp     r1, #0
                bne     loop_delay3
                b       verifica_flag     

            @le resultado do sonar em r0
            continua_leitura_sonar:
                ldr     r1, =DR
                ldr     r0, [r1]
                mov     r0, r0, lsl #14
                mov     r0, r0, lsr #20 @elimina bits extras a direita e a esquerda
                b       fim_soft_handler  @termina leitura

        return_irq_mode:
            pop {r4-r11, lr}
            mov r1, lr    
            
            @Se a chamada veio do codigo de usuario, somente retorna
            ldr r2, =fim_soft_handler
            cmp r1, r2
            bhi fim_return_irq_mode

            @muda para o irq
            mrs r0, cpsr
            bic r0, r0, #CSPR_MODE_CLEAR
            orr r0, r0, #0xD2
            msr cpsr, r0
            
            fim_return_irq_mode:

            mov lr, r1
            mov pc, lr

        fim_soft_handler:
            pop {r4-r11, lr}
            movs pc, lr

@Data --> 0x77801800
.data
    CONTADOR: .skip 4
        .skip 2048
    PILHA_SVC:
        .skip 2048
    PILHA_IRQ:
        .skip 2048
    PILHA_USER_SYSTEM:
         .skip 2048
    PILHA_USR:
        .skip 2048
    VETOR_CALLBACKS:
        .skip 96
    N_ATUAL_CALLBACKS:
        .skip 4
    CALLBACKS_ATIVAS:
        .skip 4
    N_ATUAL_ALARMS:
        .skip 4
    VETOR_ALARMS:
        .skip 64
    ALARMS_ATIVOS: .skip 4
    @0x778040b4
    EXECUTANDO_FUNCAO: .skip 4
