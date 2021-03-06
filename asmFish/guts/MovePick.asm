
	      align   16
MovePick_Init_Search:
	; in: rbp  address of Pos
	;     rbx  address of State
	;     rsi  address of Pick
	;     ecx  Move ttm
	;     edx  Depth d

	; clobbers rdi

	       push   r15

		mov   dword[rsi+Pick.depth], edx

		mov   rdi, qword[rbp+Pos.counterMoves]
		mov   eax, dword[rbx-1*sizeof.State+State.currentMove]

		and   eax, 63
	      movzx   edx, byte[rbp+Pos.board+rax]
		shl   edx, 6
		add   edx, eax
		mov   eax, dword[rdi+4*rdx]
		mov   dword[rsi+Pick.countermove], eax

		lea   r15, [rsi+Pick.moves]
		lea   rax, [r15+8*(MAX_MOVES-1)]
		lea   r8, [MovePick_MainSearch]
		lea   r9, [MovePick_Evasion]
		mov   r10, qword[rbx+State.checkersBB]
	       test   r10, r10
	     cmovnz   r8, r9
		mov   qword[rsi+Pick.cur], r15
		mov   qword[rsi+Pick.endBadCaptures], rax
		mov   qword[rsi+Pick.stage], r8

		mov   edi, ecx
	       test   ecx, ecx
		 jz   .NoTTMove

	       call   Move_IsPseudoLegal
	       test   rax, rax
	      cmovz   edi, eax
		 jz   .NoTTMove

		add   r15, sizeof.ExtMove
.NoTTMove:
		mov   dword[rsi+Pick.ttMove], edi
		mov   qword[rsi+Pick.endMoves], r15
		pop   r15
		ret







;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8
MovePick_MainSearch:
		cmp   r14, r15
		 je   GenNext_GoodCaptures
		;mov   r14, r15
		mov   eax, dword[rsi+Pick.ttMove]
		lea   rdx, [GenNext_GoodCaptures]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_GoodCaptures
GenNext_GoodCaptures:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Captures
		mov   r15, rdi
		mov   r13, r14
      ScoreCaptures   r13, rdi


MovePick_GoodCaptures:
		cmp   r14, r15
		 je   GenNext_Killers
	   PickBest   r14, r13, r15
		mov   ecx, eax
		mov   edi, eax
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_GoodCaptures
;;;; good
;            SeeSign   .Positive
;                mov   rdx, qword[rsi+Pick.endBadCaptures]
;               test   eax, eax
;                 js   .Negative

;;;; better
 ;               xor   edx, edx
 ;              call   SeeTest
 ;               mov   rdx, qword[rsi+Pick.endBadCaptures]
 ;              test   eax, eax
 ;                jz   .Negative

;;; best
	SeeSignTest   .Positive
		mov   rdx, qword[rsi+Pick.endBadCaptures]
	       test   eax, eax
		 jz   .Negative


  .Positive:
		mov   eax, edi
		lea   rdx, [MovePick_GoodCaptures]
		ret
  .Negative:
		mov   dword[rdx], edi
		sub   rdx, sizeof.ExtMove
		mov   qword[rsi+Pick.endBadCaptures], rdx
		jmp   MovePick_GoodCaptures



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_Killers
GenNext_Killers:
		lea   r14, [rsi+Pick.killers+0*sizeof.ExtMove]
		lea   r15, [rsi+Pick.killers+3*sizeof.ExtMove]
		lea   r13, [rsi+Pick.killers+2*sizeof.ExtMove]

		mov   eax, dword[rbx+State.killers+4*0]
		mov   ecx, dword[rbx+State.killers+4*1]
		mov   edx, dword[rsi+Pick.countermove]
		mov   dword[rsi+Pick.killers+0*sizeof.ExtMove], eax
		mov   dword[rsi+Pick.killers+1*sizeof.ExtMove], ecx
		mov   dword[rsi+Pick.killers+2*sizeof.ExtMove], edx
		cmp   edx, eax
	      cmove   r15, r13
		cmp   edx, ecx
	      cmove   r15, r13

;SD_String 'kil012:'
;SD_Move qword[rsi+Pick.killers+0*sizeof.ExtMove]
;SD_Move qword[rsi+Pick.killers+1*sizeof.ExtMove]
;SD_Move qword[rsi+Pick.killers+2*sizeof.ExtMove]
;SD_String '|'


MovePick_Killers:
		mov   edi, dword[r14]
		mov   eax, edi
		mov   ecx, edi
		and   eax, 63
	      movzx   eax, [rbp+Pos.board+rax]
		cmp   r14, r15
		 je   GenNext_Quiets
		add   r14, sizeof.ExtMove
	       test   edi, edi
		 jz   MovePick_Killers
		cmp   edi, dword[rsi+Pick.ttMove]
		 je   MovePick_Killers
		cmp   edi, mMOVE_TYPE_EPCAP shl 12
		jae   .special
	       test   eax, eax
		jnz   MovePick_Killers
	       call   Move_IsPseudoLegal
	       test   rax, rax
		 jz   MovePick_Killers
		mov   eax, edi
		lea   rdx, [MovePick_Killers]
;SD_String 'kil:'
;SD_Move rax
;SD_String '|'
		ret
.special:
		cmp   edi, mMOVE_TYPE_CASTLE shl 12
		 jb   MovePick_Killers
	       call   Move_IsPseudoLegal
	       test   rax, rax
		 jz   MovePick_Killers
		mov   eax, edi
		lea   rdx, [MovePick_Killers]
;SD_String 'kil:'
;SD_Move rax
;SD_String '|'
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_Quiets
GenNext_Quiets:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
		mov   r12, rdi
	       call   Gen_Quiets
		mov   qword[rsi+Pick.endMoves], rdi
		mov   r15, rdi
	ScoreQuiets   r12, rdi, r13
		mov   r12, r14
		mov   r13, r15
		mov   eax, dword[rsi+Pick.depth]
		cmp   eax, 3
		jge   .JustSort

; todo: is Partition1 better than Partition2 ?
if PEDANTIC
	 Partition2   r12, r13
else
	 Partition1   r12, r13
		mov   r13, r12
end if
	; r13 = good quiet

.JustSort:
      InsertionSort   r14, r13, r11, r12

;match =2, VERBOSE {
;lea rdi, [VerboseOutput]
;szcall PrintString, 'quiets:'
;mov  r12, r14
;.1c:
;cmp r12, r15
;jae .2c
;mov al, '('
;stosb
;mov ecx, dword[r12+ExtMove.move]
;xor  edx, edx
;call PrintUciMove
;mov al, ','
;stosb
;movsxd rax, dword[r12+ExtMove.score]
;call PrintSignedInteger
;mov  al, ')'
;stosb
;add  r12, 8
;jmp  .1c
;.2c:
;PrintNewLine
;lea rcx, [VerboseOutput]
;call _WriteOut
;}


MovePick_Quiets:
		mov   eax, dword[r14]
		cmp   r14, r15
		 je   GenNext_BadCaptures
		add   r14, sizeof.ExtMove
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_Quiets
		cmp   eax, dword[rsi+Pick.killers+0*sizeof.ExtMove]
		 je   MovePick_Quiets
		cmp   eax, dword[rsi+Pick.killers+1*sizeof.ExtMove]
		 je   MovePick_Quiets
		cmp   eax, dword[rsi+Pick.killers+2*sizeof.ExtMove]
		 je   MovePick_Quiets
		lea   rdx, [MovePick_Quiets]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_BadCaptures:
		lea   r14, [rsi+Pick.moves+(MAX_MOVES-1)*sizeof.ExtMove]
		mov   r15, qword[rsi+Pick.endBadCaptures]

MovePick_BadCaptures:
		mov   eax, dword[r14]
		cmp   r14, r15
		 je   GenNext_Evasion
		sub   r14, sizeof.ExtMove
		lea   rdx, [MovePick_BadCaptures]
		ret




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_Evasion:
		xor   eax, eax
		xor   edx, edx
		ret

	      align   8
MovePick_Evasion:
		cmp   r14, r15
		 je   GenNext_AllEvasions
		;mov   r14, r15
		mov   eax, dword[rsi+Pick.ttMove]
		lea   rdx, [GenNext_AllEvasions]
		ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_AllEvasions
GenNext_AllEvasions:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Evasions
		mov   r15, rdi
		sub   rdi, sizeof.ExtMove
		cmp   rdi, r14
		 je   MovePick_AllEvasions_Only1
		mov   r12, r14
      ScoreEvasions   r12, r15, r13

MovePick_AllEvasions:
		cmp   r14, r15
		 je   GenNext_QSearchWithChecks
	   PickBest   r14, r13, r15
		mov   ecx, eax
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_AllEvasions
		lea   rdx, [MovePick_AllEvasions]
		ret

MovePick_AllEvasions_Only1:
		mov   eax, dword[r14+ExtMove.move]
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   GenNext_QSearchWithChecks
		lea   rdx, [GenNext_QSearchWithChecks]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_QSearchWithChecks:
		xor   eax, eax
		xor   edx, edx
		ret

	      align   8
MovePick_QSearchWithChecks:
		cmp   r14, r15
		 je   GenNext_QCaptures1
		;mov   r14, r15
		mov   eax, dword[rsi+Pick.ttMove]
		lea   rdx, [GenNext_QCaptures1]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_QCaptures1
GenNext_QCaptures1:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Captures
		mov   r15, rdi
		mov   r13, r14
      ScoreCaptures   r13, rdi

MovePick_QCaptures1:
		cmp   r14, r15
		 je   GenNext_Checks
	   PickBest   r14, r13, r15
		mov   ecx, eax
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_QCaptures1
		lea   rdx, [MovePick_QCaptures1]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_Checks
GenNext_Checks:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_QuietChecks
		mov   r15, rdi

MovePick_Checks:
	      movzx   eax, word[r14]
		cmp   r14, r15
		 je   GenNext_QSearchWithoutChecks
		add   r14, sizeof.ExtMove
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_Checks
		lea   rdx, [MovePick_Checks]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_QSearchWithoutChecks:
		xor   eax, eax
		xor   edx, edx
		ret

	      align   8
MovePick_QSearchWithoutChecks:
		cmp   r14, r15
		 je   GenNext_QCaptures2
		;mov   r14, r15
		mov   eax, dword[rsi+Pick.ttMove]
		lea   rdx, [GenNext_QCaptures2]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_QCaptures2
GenNext_QCaptures2:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Captures
		mov   r15, rdi
		mov   r13, r14
      ScoreCaptures   r13, rdi

MovePick_QCaptures2:
		cmp   r14, r15
		 je   GenNext_Probcut
	   PickBest   r14, r13, r15
		mov   ecx, eax
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_QCaptures2
		lea   rdx, [MovePick_QCaptures2]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_Probcut:
		xor   eax, eax
		xor   edx, edx
		ret

	      align   8
MovePick_Probcut:
		cmp   r14, r15
		 je   GenNext_ProbcutCaptures
		;mov   r14, r15
		mov   eax, dword[rsi+Pick.ttMove]
		lea   rdx, [GenNext_ProbcutCaptures]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	      align   8, MovePick_ProbcutCaptures
GenNext_ProbcutCaptures:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Captures
		mov   r15, rdi
		mov   r13, r14
      ScoreCaptures   r13, rdi

MovePick_ProbcutCaptures:
		cmp   r14, r15
		 je   GenNext_Recapture
	   PickBest   r14, r13, r15
		mov   ecx, eax
		mov   edi, eax
		cmp   eax, dword[rsi+Pick.ttMove]
		 je   MovePick_ProbcutCaptures
      ;         call   See
      ;          cmp   eax, dword[rsi+Pick.threshold]
      ;          jle   MovePick_ProbcutCaptures
		mov   edx, dword[rsi+Pick.threshold]
		add   edx, 1
	       call   SeeTest
	       test   eax, eax
		 jz   MovePick_ProbcutCaptures

		mov   eax, edi
		lea   rdx, [MovePick_ProbcutCaptures]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_Recapture:
		xor   eax, eax
		xor   edx, edx
		ret

	      align   8, MovePick_Recaptures
MovePick_Recapture:
	     Assert   e, r14, r15, 'assertion r14==r15 failed in MovePick_Recapture'


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_Recaptures:
		lea   rdi, [rsi+Pick.moves]
		mov   r14, rdi
	       call   Gen_Captures
		mov   r15, rdi
		mov   r13, r14
      ScoreCaptures   r13, rdi



MovePick_Recaptures:
		cmp   r14, r15
		 je   GenNext_Stop
	   PickBest   r14, r13, r15
		mov   ecx, eax
		and   ecx, 63
		cmp   ecx, dword[rsi+Pick.recaptureSquare]
		jne   MovePick_Recaptures
		lea   rdx, [MovePick_Recaptures]
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenNext_Stop:
MovePick_Stop:
		xor   eax, eax
		xor   edx, edx
		ret