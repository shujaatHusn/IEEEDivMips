#DVISION OF SINGLE PRECISON IEEE FORMAT#
.data
	Dividend: .float 6.0
	Divisor: .float 13.0
	op1: .asciiz "1."
	maskmantis: .word 0x7fffff
	maskexp: .word 0x7f800000
.text
.globl main
.ent main
main:
#--------------------------------------	EXTRACTING INPUT--------------------------------------#	

	la $a0, Dividend
	l.s $f0, 0($a0)		#For Check

	jal Extract
	move $s0, $v0		#$s0 = Sign of Dividend
	move $s1, $v1		#$s1 = Biased Exponent of Dividend
	lw $s2, 0($sp)		#$s2 = Mantissa of Dividend (From Stack)
	addi $sp, $sp, 4		#Increment in $sp (Stack Pointer)	
	
	la $a0, Divisor
	l.s $f1, 0($a0)		#For Check
	
	jal Extract
	move $s3, $v0		#$s3 = Sign of Divisor
	move $s4, $v1		#$s4 = Biased Exponent of Divisor
	lw $s5, 0($sp)		#$s5 = Mantissa of Divisor (From Stack)
	addi $sp, $sp, 4		#Increment in $sp (Stack Pointer)	



#--------------------------------------EXCEPTION HANDLING FOR 0 AS INPUT (REMAINING)--------------------------------------#	


#--------------------------------------DIVISION BEGINS--------------------------------------#	

	xor $s0, $s0, $s3		#Comparing Signs, Final Sign in $s0 at MSb

	sub $s1, $s1, $s4		#Calculating Exponent, Result in $s1

	move $a0, $s2		#$a0 = Mantissa of Dividend/Remainder
	move $a1, $s5		#$a1 = Mantissa of Divisor

	slt $t0,$a0,$a1		#normalDiv if divident>divisor	
	beq $t0,$0,normalDiv
	
	jal newtonDiv	#netwonDiv oterwise
	move $a0,$v0
	jal Normalization
	j else3	
		
normalDiv:
	jal DivisionAlgorithm

else3:	
	move $s3, $v0		#$s3 = Calculated 24-bit Mantissa 
	move $s4, $v1		#$s4 = Displacement of Decimal Point

	sub $s1, $s1, $s4		# $s1 = Final Exp - Displacement of Decimal Point

	lui $t0, 0x7f		
	ori $t0, $t0, 0xffff		#$t0 = 0x7fffff
	and $s3, $t0, $s3		#$s3 = Extracted Fractional Part
	
	or $s4, $0, $s0		#MSb of $s4 = Final Sign
	addi $s1, $s1, 127		#$s1 = Biased Exponent
	sll $s1, $s1, 23		#Shifting Biased Exponent Value in its Reserved Space (23-to-30 bits)
	or $s4, $s4, $s1		#Placing Biased Exponent in $s4
	or $s4, $s4, $s3		#Final Result Accumulated in $s4
	
	div.s $f2, $f0, $f1		#For Check; If $f2 = $s4 --> Correct
	
#--------------------------------------PRINTING BEGINS--------------------------------------#	

	mfc1 $a0,$f0	#print dividend		
	jal print_bin2

	li $v0,11
	addi $a0,$0,47
	syscall

	mfc1 $a0,$f1	#print divisor
	jal print_bin2

	li $v0,11
	li $a0,61
	syscall
	move $a0,$s4	#Printing reslt
	jal print_bin2
	
#--------------------------------------	#ENDS#--------------------------------------	

	li $v0, 10			#Exit
	syscall
.end main


#--------------------------------------	#FUNCTION-1#--------------------------------------	

Extract:	#Extracts: 		 #
	#	i) Sign in $v0 at MSb	 #
	#	ii) Exponent in $v1	 #
	#	 iii) Mantissa in Stack#

	lw $t0, 0($a0)
	
	lui $t1, 0x8000		#$t1= 0x80000000
	and $v0, $t1, $t0		#$v0 = Extracted Sign

	lui $t1, 0x7f80		#$t1 = 0x7f800000
	and $v1, $t1, $t0
	sra $v1, $v1, 23		#$v1 = Extracted Base Exponent
	
	lui $t1, 0x7f		
	ori $t1, $t1, 0xffff		#$t1 = 0x7fffff
	and $t3, $t1, $t0		#$t3 = Extracted Fractional Part (23-bit)
	lui $t1, 0x80		#$t1 = 0x80
	or $t3, $t3, $t1		#$t3 = 24-bit Extracted Mantissa

	addi $sp, $sp, -4		#Decrement in $sp (Stack Pointer)
	sw $t3, 0($sp)		#Saving 24-bit Extracted Mantissa in Stack

	jr $ra			#Return

#--------------------------------------	#FUNCTION-2#--------------------------------------	

DivisionAlgorithm:	#Divides Dividend Mantissa (in $a0) by Divisor Mantissa (in $a1) for 25 Iterations#
		#Returns Quotient Value in $v0#

	addi $sp, $sp, -12		#Decrement in $sp (Stack Pointer)
	sw $s0, 0($sp)		#Pushing $s0 into Stack
	sw $ra, 4($sp)		#Pushing $ra into Stack (Function Call Exists)
	sw $s1,8($sp)		#Pushing $s1 into stack	

	move $t0, $a0		#$t0 = Mantissa of Dividend/Remainder
	move $t1, $a1		#$t1 = Mantissa of Divisor

	add $s0, $0, $0		#$s0 = Initialization
	add $v1, $0, $0		#$v1 = 0 (Displacement of Decimal Point Initialized)
	addi $s1,$0,1		#$s1 = 1 (initialize loop variable to 1)
	add $t3,$0,33

loop:	
	beq $t1, $0, check		#If Divisor = 0, Branch to check
	sub $t0, $t0, $t1		#Dividend = Dividend - Divisor
	sll $s0, $s0, 1		#Quotient Register Shifted Left by 1-bit
	slt $t2, $t0, $0
	bne $t2, $0, else		#If Dividend < 0, Branch to else
	addi $s0, $s0, 1		#Setting Quotient LSb to 1
	j out
else:	add $t0, $t0, $t1		#Restoring Dividend Original Value

out:	srl $t1, $t1, 1		#Divisor Register Shifted Right by 1-bit
	j loop

check:	slt $t2, $a0, $a1		#If Dividend < Divisor, Call Function 'Normalization'
	beq $t2, $0, exit		#If Dividend > Divisor, Branch to exit
	move $a0, $s0		#$a0 = Quotient

	jal Normalization		#Function Call 
	j return

exit:	move $v0, $s0		#$v0 = Calculated Mantissa

return:	lw $ra, 4($sp)		#Restoring $ra
	lw $s0, 0($sp)		#Restoring $s0
	lw $s1, 8($sp)		#restoring $s1
	addi $sp, $sp, 12		#Increment in $sp (Stack Pointer)
 	jr $ra			#Return


#--------------------------------------	#FUNCTION-3#--------------------------------------

Normalization:	#Normalizes the Mantissa (in $a0) and Counts the Decimal Places Moved by Decimal Point#
		#Returns: 
		#	i)  $v0 = Normalized Mantissa	       #
		#	ii)  $v1 = Count of Decimal Places #

	lui $t0, 0x40		#$t0 = 0x40 (1 at 23rd-bit)
	addi $t2, $0, 1		#$t2 = 1 (Initialization)

loop2:	and $t1, $a0, $t0		#Extracting 23rd-bit of Mantissa 
	bne $t1, $0, else2		#If 23rd-bit = 1; Branch to else2
	addi $t2, $t2, 1		#Increment in Count of Decimal Places Moved
	sll $a0, $a0, 1		#Mantissa Shifted Left (To Extract Next Bit)
	j loop2			
	
else2:	sll $a0, $a0, 1		#Setting 24th-bit = 1 (Implied)
	move $v0, $a0		#$v0 = Normalized Mantissa
	move $v1, $t2		#$v1 = Displacement of Decimal Point	
	jr $ra			#Return


#--------------------------------------	#FUNCTION-4#--------------------------------------

print_binary:
	addi $sp,$sp, -16		#save s0-s3 to stack
	sw $s0,0($sp)
	sw $s1,4($sp)
	sw $s2,8($sp)
	sw $s3,12($sp)

	move	$s0, $a0
	addi	$s1, $zero, 31	# constant shift amount
	addi	$s2, $zero, 0	# variable shift amount
	addi	$s3, $zero, 23	# exit condition
print_binary_loop:
	beq	$s2, $s3, print_binary_done
	sllv	$a0, $s0, $s2
	srlv	$a0, $a0, $s1
	li	$v0, 1		# PRINT_INT
	syscall
	addi	$s2, $s2, 1
	j	print_binary_loop
print_binary_done:

	lw $s0,0($sp)
	lw $s1,4($sp)
	lw $s2,8($sp)
	lw $s3,12($sp)
	addi $sp,$sp, 16	#restore s0, s1, s2,s3
	jr	$ra

#----------------------------------------#FUNCTION-5#--------------------------------------------------------


print_bin2:
	beq	$s0,$0,printplus
	li	$v0,11		#prints negative if $s0==1
	addi 	$a0,$0,45
	syscall

	printplus:
	li	$v0,4
	la	$a0,op1
	syscall		#print "1.

	addi	$sp,$sp,-4
	sw	$ra,0($sp)
	
	la $t3,maskmantis
	lw $t3,0($t3)		#$t3=7fffff
	and	$t0,$s4,$t3	#extracting mantissa from s4, 
	sllv	$a0,$t0,9		#moving mantissa to te first 23 bits of te reg $a0
	jal	print_binary	#printing mantissa

	lw	$ra,0($sp)
	addi	$sp,$sp,4



	li 	$v0,11			#printing exp	
	addi 	$a0,$0,120		#x
	syscall	
	
	li 	$v0,11
	addi 	$a0,$0,50		#2
	syscall

	li 	$v0,11
	addi 	$a0,$0,94		#^
	syscall

	#srlv	$s4,$s4,24
	#addi 	$s4,$s4,-127

	la $t3,maskexp
	lw $t3,0($t3)		#$t3=7f800000
	and $t1,$s4,$t3		#extracting biased exp from s4
	srlv $t1,$t1,23			#sifting biased exp to last bits of t1
	
	addi $t2,$t1,-127		#converting biased exp to actual exp
	
	
	li 	$v0,1		#printing exp
	move 	$a0,$t2
	syscall
	
	jr	$ra
.end print_bin2	

		
newtonDiv:
#assmes dividend in a0 and divisor in a1
#retrns resltant mantissa in $v0

addi	$sp,$sp,-8
sw 	$ra,0($sp)
sw	$a0,4($sp)

li $a0,1
jal	DivisionAlgorithm	#approximating 1/divisor
move $t3,$v0


# x(n+1)=xn +xn(1-b*xn)
mult $t3,$a1
mflo $t0
addi $t0,$t0,-1
mult $t3,$t0
mflo $t0
add $t0,$t0,$t3


addi $t4,$0,1	#t4 is loop variable
addi $t5,$0,3	#loop rns 3 times, S=3 when P=24


loop3:
beq $t4,$t5,endLoop

add $t1,$0,$t0
mult $a1,$t1
mflo $t1
sub $t1,$t1,$a0
mult $t2,$t1
add $t2,$t1,$t1

addi $t4,$t4,1
j loop3

endLoop:

move $v0,$t2

lw $ra,0($sp)
lw $a0,4($sp)
addi $sp,$sp,8
jr $ra

.end newtonDiv