
; macro for string functions
;  the string m is put in the code
;  and the function fxn is called on it
macro szcall fxn, m {
local .message, .over
			lea   rcx, [.message]
			jmp   .over
   .message:  db m
	      db 0
   .over:
		       call   fxn
}


; should work for registers or immediates
macro ClampUnsigned x, min, max {
local .Lower, .Done
			cmp   x, min
			 jb   .Lower
			cmp   x, max
			 jb   .Done
			mov   x, max
			jmp   .Done
	.Lower:
			mov   x, min
	.Done:
}



PAGE_SIZE = 4096
macro _chkstk_ms stack, A {
; a=A
; c=stack
; while n>= PAGE_SIZE
;   c = c-PAGE_SIZE
;   or byte[c], 0
;   n=n-PAGE_SIZE
; end while
}


;        align   16
;__chkstk_ms:
;        push    rcx
;        push    rax
;        cmp     rax, PAGE_SIZE
;        lea     rcx, [rsp + 24]
;        jb      ._LessThanAPage
;._MoreThanAPage:
;        sub     rcx, PAGE_SIZE
;        or      byte[rcx], 0
;        sub     rax, PAGE_SIZE
;        cmp     rax, PAGE_SIZE
;        ja      ._MoreThanAPage
;._LessThanAPage:
;        sub     rcx, rax
;        or      byte[rcx], 0
;        pop     rax
;        pop     rcx
;        ret




; a = PopCnt(b)
macro popcnt a,x,t {
local .start,.skip,.done
 match =1, CPU_HAS_POPCNT \{
		     popcnt   a, x
 \}
 match =0, CPU_HAS_POPCNT \{

	if a eq t
	  display 'arguments of popcnt are strange'
	  display 13,10
	  err
	end if

	if a eq x   ; only have two registers to work with
		mov   t, a
		shr   t, 1
		and   t, qword[Mask55]
		sub   a, t
		mov   t, a
		shr   t, 2
		and   a, qword[Mask33]
		and   t, qword[Mask33]
		add   a, t
		mov   t, a
		shr   t, 4
		add   a, t
		and   a, qword[Mask0F]
	       imul   a, qword[Mask01]
		shr   a, 56

	else   ; can't write to x
		mov   a, x
		mov   t, x
		shr   a, 1
		and   a, qword [Mask55]
		sub   t, a
		mov   a, t
		shr   t, 2
		and   a, qword [Mask33]
		and   t, qword [Mask33]
		add   a, t
		mov   t, a
		shr   a, 4
		add   a, t
		and   a, qword [Mask0F]
	       imul   a, qword [Mask01]
		shr   a, 56
	end if
 \}
}

; a = PopCnt(b) assuming PopCnt(b)<16
macro popcnt15 a,x,t {
local .start,.skip,.done
 match =1, CPU_HAS_POPCNT \{
		     popcnt  a,x
 \}
 match =0, CPU_HAS_POPCNT \{

	if a eq t
	  display 'arguments of popcnt15 are strange'
	  display 13,10
	  err
	end if

	if a eq x   ; only have two registers to work with
		mov   t, x
		shr   t, 1
		and   t, qword[Mask55]
		sub   x, t
		mov   t, x
		shr   t, 2
		and   x, qword[Mask33]
		and   t, qword[Mask33]
		add   x, t
	       imul   x, qword[Mask01]
		shr   x, 56

	else if x eqtype rax  ; x is a register operand
		mov   a, x
		shr   a, 1
		and   a, qword [Mask55]
		sub   x, a
		mov   a, x
		shr   a, 2
		and   a, qword [Mask33]
		and   x, qword [Mask33]
		add   a, a
	       imul   a, qword [Mask11]
		shr   a, 60

	else   ; x is memory - can't write to it
		mov   a, x
		mov   t, x
		shr   a, 1
		and   a, qword [Mask55]
		sub   t, a
		mov   a, t
		shr   t, 2
		and   a, qword [Mask33]
		and   t, qword [Mask33]
		add   a, t
	       imul   a, qword [Mask11]
		shr   a, 56
	end if
 \}
}


; a = ClearLowestBit(b)
; carry flag is not handled consistently
macro blsr a,b,t {
 match =1, CPU_HAS_BMI1 \{
	       blsr  a,b
 \}
 match =0, CPU_HAS_BMI1 \{
	if a eq b
		lea  t,[a-1]
		and  a,t
	else
		lea  a,[b-1]
		and  a,b
	end if
 \}
}

; a = IsolateLowestBit(b)
; carry flag is not handled consistently
macro blsi a,b,t {
 match =1, CPU_HAS_BMI1 \{
	       blsi  a,b
 \}
 match =0, CPU_HAS_BMI1 \{
	if a eq b
		mov  t, a
		neg  a
		and  a, t
	else
		mov  a, b
		neg  a
		and  a, b
	end if
 \}
}


; a = And(Not(b),c)
; flags are not handled consistently
macro andn a,b,c {
 match =1, CPU_HAS_BMI1 \{
	       andn  a,b,c
 \}
 match =0, CPU_HAS_BMI1 \{
	if b eq c
	  display 'arguments of _andn are strange'
	  display 13,10
	  err
	else if a eq c
		not  b
		and  a, b
		not  b
	else if a eq b
		not  a
		and  a, c
	else
		mov  a, b
		not  a
		and  a, c
	end if
 \}
}



; y = BitDeposit(x,m)  slow
macro _pdep y,x,m,b,t,tm {
local .start,.skip,.done
 match =1, CPU_HAS_BMI2 \{
	       pdep  y, x, m
 \}
 match =0, CPU_HAS_BMI2 \{
		mov  tm, m
		xor  y, y
		lea  b, [y+1]
	       test  tm, tm
		 jz  .done
	.start: mov  t, tm
		neg  t
		and  t, tm
	       test  x, b
		 jz  .skip
		 or  y, t
	.skip:	lea  t, [tm-1]
		add  b, b
		and  tm, t
		jnz  .start
	.done:
 \}
}



; y = BitExtract(x,m)  slow
macro _pext y,x,m,b,t,tm {
local .start,.skip,.done
 match =1, CPU_HAS_BMI2 \{
	       pext  y, x, m
 \}
 match =0, CPU_HAS_BMI2 \{
		mov  tm, m
		xor  y, y
		lea  b, [y+1]
	       test  tm, tm
		 jz  .done
	.start: mov  t, tm
		neg  t
		and  t, tm
	       test  t, x
		lea  t, [tm-1]
		 jz  .skip
		 or  y, b
	.skip:	add  b, b
		and  tm, t
		jnz  .start
	.done:
 \}
}





; convert 64 bit register reg to its 32 bit version
;  for >= r8, r8d is the 32 bit version

raxd equ eax
rbxd equ ebx
rcxd equ ecx
rdxd equ edx
rbpd equ ebp
rsid equ esi
rdid equ edi





macro months [dayscount]
{
  forward
   if DAY > dayscount
    DAY = DAY-dayscount
    MONTH = MONTH+1
  forward
   end if
}

TIME = %T
DAY = TIME/(24*3600)
DAY = DAY - (DAY+365)/(3*365+366)
YEAR = 1970+DAY/365
DAY = DAY mod 365 + 1
MONTH = 1

if YEAR mod 4 = 0
  FEBDAYS=29
else
  FEBDAYS=28
end if

months 31,FEBDAYS,31,30,31,30,31,31,30,31,30,31

macro num_to_db num, digits {
common
   local ..lbl, ..ptr, ..dig, ..num

..lbl:
   rb digits

   ..ptr = ..lbl + digits - 1
   ..num = num
   repeat digits
     ..dig = (..num mod 10) + $30
     ..num = ..num / 10
     store byte ..dig at ..ptr
     ..ptr = ..ptr - 1
   end repeat
}


macro create_build_time day, month, year {
common
  num_to_db year, 4
  db '.'
  num_to_db month, 2
  db '.'
  num_to_db day, 2
}