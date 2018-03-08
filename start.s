.global _start

@start -> 0x77812000
_start:
    ldr r9, =1200
    ldr r8, =4000
    ldr r6, =6000           @ r6 <- 1200 (Limiar para parar o robo)
    mov r0, #30
    mov r1, #30
    mov r7, #19        
    svc 0x0

    mov r7, #22
    mov r1, r8
    ldr r0, =gofuckyourself
    svc 0x0

    mov r7, #17
    mov r0, #3
    mov r1, r9
    ldr r2, =gofuckmyself
    svc 0x0

    cmp r1, #-2
    beq loop

    @mov r7, #17
    @mov r1, r6
    @ldr r0, =gofuckthyself
    @svc 0x0

    @mov r7, #17
   @ mov r0, #3
  @  mov r1, r9
 @   ldr r2, =gofuckmyself
@    svc 0x0

    mov r0, #0
loopInfinito:
    add r0, r0, #1
    cmp r0, #0x10000
    bne loopInfinito

loopTerceiro:
    b loopTerceiro


loop:
    mov r0, #0
    mov r1, #0
    mov r7, #19        
    svc 0x0
    b loop


gofuckyourself:
    push {r4-r11, lr}
    mov r0, #0
    mov r1, #30
    mov r7, #19        
    svc 0x0
    pop {r4-r11, lr}
    mov pc, lr


gofuckthyself:
    push {r4-r11, lr}
    mov r0, #30
    mov r1, #0
    mov r7, #19        
    svc 0x0
    pop {r4-r11, lr}
    mov pc, lr


gofuckmyself:
    push {r4-r11, lr}
    mov r0, #0
    mov r1, #0
    mov r7, #19        
    svc 0x0
    pop {r4-r11, lr}
    mov pc, lr
    