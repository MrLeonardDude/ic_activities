@	Autor : Leonardo M Pagnez 
@	RA 	  : 172017

	.global set_motor_speed
	.global set_motors_speed
	.global read_sonar
	.global read_sonars
	.global register_proximity_callback
	.global add_alarm
	.global get_time
	.global set_time
	


	.align 4
set_motor_speed:
	
	push 	{r4-r11, lr}
	ldrb 	r1, [r0]
	ldrb 	r2, [r0, #1]

	mov  	r0, r1
	mov  	r1, r2
	mov 	r7, #18
	svc 	0x0
	pop		{r4-r11, lr}
	mov 	pc, lr


set_motors_speed:
	
	push	{r4-r11, lr}
	ldrb 	r4, [r0]
	ldrb 	r5, [r0, #1]
	ldrb 	r6, [r1]
	ldrb 	r7, [r1, #1]

	if:
		cmp 	r4, #0
		bne 	fail

	ifAND:
		cmp 	r6, #1
		bne 	fail

	continue:
		mov 	r0, r5
		mov 	r1, r7
		mov 	r7, #19
		svc 0x0
	
	fail:
	pop 	{r4-r11, lr}
	mov 	pc, lr

read_sonar:

	push	{r4-r11, lr}
	mov 	r7, #16
	svc 	0x0
	pop		{r4-r11, lr}
	mov 	pc, lr 	


read_sonars:

	push 	{r4-r11, lr}
	mov 	r4, r0
	mov		r5, r1
	mov 	r6, r2 
	mov 	r7, #16
	mov 	r8, #0
	cmp 	r4, r5
	bgt 	fim_loop

	inicio_loop:
		mov 	r0, r4
		svc 	0x0
		str 	r0, [r6, r8]
		add 	r4, r4, #1
		add 	r8, r8, #4
		cmp 	r4, r5
		bne 	inicio_loop

	fim_loop:

	pop 	{r4-r11, pc}

register_proximity_callback:

	push 	{r4-r11, lr}
	mov 	r7, #17
	svc 	0x0
	pop 	{r4-r11, pc}

add_alarm:
	
	push 	{r4-r11, lr}
	mov 	r7, #22
	svc 	0x0
	pop 	{r4-r11, pc}


get_time:
	push 	{r4-r11, lr}
	mov 	r4, r0
	mov 	r7, #20
	svc 	0x0
	str 	r0, [r4]
	pop 	{r4-r11, pc}


set_time:
	push 	{r4-r11, lr}
	mov 	r7, #21
	svc 	0x0
	pop 	{r4-r11, pc}


