

macro QSearch NT, InCheck {
	; in:
	;  rbp: address of Pos struct in thread struct
	;  rbx: address of State
	;  ecx: alpha
	;  edx: beta
	;  r8d: depth

;jmp _Evaluate

match =_PV_NODE, NT \{
 match =1, InCheck \\{
   ProfileInc QSearch_PV_TRUE
 \\}
 match =0, InCheck \\{
   ProfileInc QSearch_PV_FALSE
 \\}

 .PvNode equ 1
 \}

match =_NONPV_NODE, NT \{
 match =1, InCheck \\{
   ProfileInc QSearch_NONPV_TRUE
 \\}
 match =0, InCheck \\{
   ProfileInc QSearch_NONPV_FALSE
 \\}

 .PvNode equ 0
\}





virtual at rsp
  .tte	     rq 1      ; 0
  .ltte      rq 1      ; 8
  .searchFxn rq 1      ; 16

  .ttMove	  rd 1 ; 24
  .ttValue	  rd 1
  .ttDepth	  rd 1
  .move 	  rd 1
  .excludedMove   rd 1
  .bestMove	  rd 1
  .ext		  rd 1
  .newDepth	  rd 1
  .predictedDepth rd 1
  .moveCount	  rd 1
  .oldAlpha	  rd 1
  .alpha	  rd 1
  .beta 	  rd 1
  .depth	  rd 1
  .bestValue	  rd 1
  .value	  rd 1
  .eval 	  rd 1
  .nullValue	  rd 1
  .futilityValue  rd 1
  .futilityBase   rd 1

  .inCheck		   rb 1   ;  104
  .givesCheck		   rb 1   ;  105
  .singularExtensionNode   rb 1   ;  106
  .improving		   rb 1   ;  107
  .captureOrPromotion	   rb 1   ;  108
  .dangerous		   rb 1   ;  109
  .doFullDepthSearch	   rb 1   ;  110
  .cutNode		   rb 1   ;  111
  .ttHit		   rb 1
			   rb 1
			   rb 1
			   rb 1
			   rb 1
			   rb 1
			   rb 1
			   rb 1

  .movepick	  rb sizeof.Pick

if .PvNode eq 1
  ._pv		   rd MAX_PLY+1
end if

  .lend rb 0

end virtual
.localsize = ((.lend-rsp+15) and (-16))


	       push   rbx rsi rdi r12 r13 r14 r15
	 _chkstk_ms   rsp, .localsize
		sub   rsp, .localsize

;match =_PV_NODE, NT
;\{
;match =1, InCheck \\{
;DebugStackUse 'qsearch<PV, in check>'
;\\}
;match =0, InCheck \\{
;DebugStackUse 'qsearch<PV, not in check>'
;\\}
;\}
;match =_NONPV_NODE, NT
;\{
;match =1, InCheck \\{
;DebugStackUse 'qsearch<NON_PV, in check>'
;\\}
;match =0, InCheck \\{
;DebugStackUse 'qsearch<NON_PV, not in check>'
;\\}
;\}


match =2, VERBOSE \{
push rcx rdx r8 r9 r13 r14 r15
mov r15, rcx
mov r14, rdx
mov r13, r8
lea rdi, [VerboseOutput]
mov rax,'qsearch<'
stosq
match =1, InCheck \\{
mov al, 't'
\\}
match =0, InCheck \\{
mov al, 'f'
\\}
stosb
mov eax, '> ('
stosd
sub rdi, 1
movsxd rax, r15d
call PrintSignedInteger
mov ax, ', '
stosw
movsxd rax, r14d
call PrintSignedInteger
mov eax, ')  '
stosd
sub rdi, 1
movsxd rax, r13d
call PrintSignedInteger
match =1, OS_IS_WINDOWS \\{
 mov al, 13
 stosb
\\}
mov al, 10
stosb
lea rcx, [VerboseOutput]
call _WriteOut
pop r15 r14 r13 r9 r8 rdx rcx
\}


		mov   dword[.alpha], ecx
		mov   dword[.beta], edx
		mov   dword[.depth], r8d

		mov   edx, dword[rbx-1*sizeof.State+State.ply]
		add   edx, 1
		xor   eax, eax
	if .PvNode eq 1
		lea   r8, [._pv]
		mov   r9, qword[rbx+State.pv]
		mov   dword[.oldAlpha], ecx
		mov   qword[rbx+1*sizeof.State+State.pv], r8
		mov   dword[r9], eax
	end if
		mov   dword[.bestMove], eax
		mov   dword[rbx+State.currentMove], eax
		mov   dword[rbx+State.ply], edx

	; check for instant draw or max ply
	      movzx   eax, word[rbx+State.rule50]
	      movzx   r8d, word[rbx+State.pliesFromNull]
		mov   r9, qword[rbx+State.key]
		cmp   edx, MAX_PLY
		jae   .AbortSearch_PlyBigger
		cmp   eax, 100
		jae   .CheckDrawBy50
		cmp   eax, r8d
	      cmova   eax, r8d
		shr   eax, 1
		 jz   .NoDrawBy50
	       imul   rax, -2*sizeof.State
     @@:	cmp   r9, qword[rbx+rax+State.key]
		 je   .AbortSearch_PlySmaller
		add   rax, 2*sizeof.State
		jnz   @b
     .NoDrawBy50:

	if InCheck eq 1
		mov   r12d, DEPTH_QS_CHECKS
		mov   dword[.ttDepth],r12d
	else
		mov   eax, DEPTH_QS_CHECKS
		mov   r12d, DEPTH_QS_NO_CHECKS
		cmp   eax, dword[.depth]
	     cmovle   r12d, eax
		mov   dword[.ttDepth], r12d
	end if

	; transposition table lookup
		mov   rcx, qword[rbx+State.key]
		sub   r12d, 1
	       call   MainHash_Probe

		mov   qword[.tte], rax
		mov   qword[.ltte], rcx
		mov   byte[.ttHit], dl
		mov   rdi, rcx
		sar   rdi, 48
	      movsx   eax, ch
		sub   r12d, eax
		sar   r12d, 31
	; r12d = 0 if tte.depth <  ttDepth
	;      =-1 if tte.depth >= ttDepth
		shr   rcx, 16
		mov   r13d, edx
	      movzx   ecx, cx
		mov   dword[.ttMove], ecx
		mov   dword[.ttValue], edi

		lea   r8d, [rdi+VALUE_MATE_IN_MAX_PLY]
	       test   edx, edx
		 jz   .DontReturnTTValue

		mov   eax, edi
		sub   eax, dword[.beta]
		sar   eax, 31
	; eax = 0 if ttValue<beta
	;     =-1 if ttvalue>=beta
		cmp   edi, VALUE_NONE
		 je   .DontReturnTTValue
		cmp   r8d, 2*VALUE_MATE_IN_MAX_PLY
		jae   .ValueFromTT
.ValueFromTTRet:
	if .PvNode eq 0
		add   eax, 2
	; eax = 2 if ttValue<beta     ie BOUND_UPPER
	;     = 1 if ttvalue>=beta    ie BOUND_LOWER
		and   eax, r12d
	       test   al, byte[.ltte+MainHashEntry.genBound]
		jnz   .ReturnTTValue
	end if

.DontReturnTTValue:

	; Evaluate the position statically
	;  r13d = ttHit

	if InCheck eq 1
		mov   eax, -VALUE_INFINITE
		mov   dword[rbx+State.staticEval], VALUE_NONE
		mov   dword[.bestValue], eax
		mov   dword[.futilityBase], eax
	else
		mov   edx, dword[rbx-1*sizeof.State+State.currentMove]
	       test   r13d, r13d
		 jz   .StaticValueNoTTHit
.StaticValueYesTTHit:
	      movsx   eax, word[.ltte+MainHashEntry.eval]
		cmp   eax, VALUE_NONE
		jne   @f
	       call   Evaluate
	@@:	xor   ecx, ecx
		mov   dword[rbx+State.staticEval], eax
		cmp   edi, eax
	       setg   cl
		add   ecx, 1
	; ecx = 2 if ttValue > bestValue   ie BOUND_LOWER
	;     = 1 if ttValue <=bestValue   ie BOUND_UPPER
		cmp   edi, VALUE_NONE
		 je   .StaticValueDone
	       test   cl, byte[.ltte+MainHashEntry.genBound]
	     cmovnz   eax, edi
		jmp   .StaticValueDone

.StaticValueNoTTHit:
		mov   eax, dword[rbx+State.staticEval-1*sizeof.State]
		neg   eax
		add   eax, 2*Eval_Tempo
		cmp   edx, MOVE_NULL
		 je   @f
	       call   Evaluate
	@@:	mov   dword[rbx+State.staticEval], eax
.StaticValueDone:
		mov   dword[.bestValue], eax

	; Return immediately if static value is at least beta
		cmp   eax, dword[.beta]
		jge   .ReturnStaticValue


    if .PvNode eq 1
		mov   ecx, dword[.alpha]
		cmp   ecx, eax
	      cmovl   ecx, eax
		mov   dword[.alpha], ecx
    end if
		add   eax, 128
		mov   dword[.futilityBase], eax

    end if ; InCheck eq 1




	       call   SetCheckInfo

	; initialize move picker
	;   Pick.endQuiets, Pick.endBadCaptures are not used in q search

	      ; endBadCaptures should not be used in qsearch
		lea   rsi, [.movepick]
		lea   r15, [rsi+Pick.moves]
	      ;  lea   rax, [r15+sizeof.ExtMove*(MAX_MOVES-1)]
		mov   qword[rsi+Pick.cur], r15
	      ;  mov   qword[rsi+Pick.endBadCaptures], rax
		mov   ecx, dword[.ttMove]

	if InCheck eq 1
	     Assert   ne, qword[rbx+State.checkersBB], 0, 'assertion qword[rbx+State.checkers]!=0 failed in QSearch'
		lea   rdx, [MovePick_Evasion]
	else
	     Assert   e, qword[rbx+State.checkersBB], 0, 'assertion qword[rbx+State.checkers]==0 failed in QSearch'
		mov   eax, dword[rbx-1*sizeof.State+State.currentMove]
		and   eax, 63
		lea   rdx, [MovePick_QSearchWithChecks]
		cmp   dword [.depth], DEPTH_QS_NO_CHECKS
		 jg   .MovePickInitGo
		lea   rdx, [MovePick_QSearchWithoutChecks]
		cmp   dword [.depth], DEPTH_QS_RECAPTURES
		 jg   .MovePickInitGo
		lea   rdx, [MovePick_Recapture]
		mov   dword[rsi+Pick.recaptureSquare], eax
		xor   edi, edi
		mov   qword[rsi+Pick.stage], rdx
		jmp   .MovePickNoTTMove
	end if

 .MovePickInitGo:
		mov   qword[rsi+Pick.stage], rdx
		mov   edi, ecx
	       test   ecx, ecx
		 jz   .MovePickNoTTMove

	       call   Move_IsPseudoLegal
	       test   rax, rax
	      cmovz   edi, eax
		 jz   .MovePickNoTTMove

		add   r15, sizeof.ExtMove
.MovePickNoTTMove:
		mov   dword[rsi+Pick.ttMove], edi
		mov   qword[rsi+Pick.endMoves], r15


	      align   8
.MovePickLoop:

		lea   rsi, [.movepick]
	GetNextMove
		mov   dword[.move], eax
	       test   eax, eax
		 jz   .MovePickDone

SD_String 'Qmp='
SD_Move rax
SD_String '|'


	; check for check and get address of search function
		mov   ecx, eax
	       call   Move_GivesCheck
		mov   byte[.givesCheck], al
	      movsx   r13d, al
	if .PvNode eq 1
		lea   rdx, [QSearch_Pv_NoCheck]
		lea   rcx, [QSearch_Pv_InCheck]
	else
		lea   rdx, [QSearch_NonPv_NoCheck]
		lea   rcx, [QSearch_NonPv_InCheck]
	end if
	       test   eax, eax
	     cmovnz   rdx, rcx
		mov   qword[.searchFxn], rdx



		mov   ecx, dword[.move]
		mov   edi, dword[.bestValue]
		mov   esi, ecx
		shr   esi, 12

		mov   r8d, ecx
		shr   r8d, 6
		and   r8d, 63			      ; r8d = from
	      movzx   eax, byte[rbp+Pos.board+r8]     ; r14d = from piece
		mov   r14d, eax

		mov   r9d, ecx
		and   r9d, 63			       ; r9d = to
	      movzx   r15d, byte[rbp+Pos.board+r9]     ; r15d = to piece

		; futility pruning
	if InCheck eq 0
		mov   r12d, dword[.futilityBase]
	       test   r13d,r13d
		jnz   .SkipFutilityPruning
		and   eax, 7
		cmp   r12d, -VALUE_KNOWN_WIN
		jle   .SkipFutilityPruning

		mov   edx, dword[rbp+Pos.sideToMove]
		neg   edx
		cmp   eax, Pawn
		 je   .CheckAdvancedPawnPush
.DoFutilityPruning:


		mov   edx, dword[PieceValue_EG+4*r15]
		add   edx, r12d
		cmp   edx, dword[.alpha]
		jle   .ContinueFromFutilityValue
		cmp   r12d, dword[.alpha]
		jle   .ContinueFromFutilityBase
.SkipFutilityPruning:
	end if

	; prepare pieces for Zobrist look up
		shl   r14d, 6+3
		shl   r15d, 6+3

	; do not search moves with negative see value
	if InCheck eq 0
		lea   eax, [rsi-MOVE_TYPE_PROM]
		cmp   eax, 4
		 jb   .DontContinue
	else
		mov   eax, dword[rbp+Pos.sideToMove]
		cmp   edi, VALUE_MATED_IN_MAX_PLY
		jle   .DontContinue

	     Assert   ne, esi, MOVE_TYPE_CASTLE, 'castling encountered in qsearch<InCheck=true>'
		cmp   esi, MOVE_TYPE_PROM
		jae   .DontContinue	   ; catch MOVE_TYPE_EPCAP
	       test   r15d, r15d
		jnz   .DontContinue
	end if
	    SeeSign   .DontContinue
	       test   eax, eax
		 js   .MovePickLoop
.DontContinue:

	; prepare square for prefetch
		mov   edx, ecx
		and   edx, 63				; edx = to
		shr   ecx, 6
		and   ecx, 63				; ecx = from
   match =1, PROFILE \{
lock inc qword[profile.moveUnpack]
\}

	; speculative prefetch
		mov   rax, qword[rbx+State.key]
		xor   rax, qword[Zobrist_side]
		xor   rax, qword[Zobrist_Pieces+r14+8*rcx]
		xor   rax, qword[Zobrist_Pieces+r14+8*rdx]
		xor   rax, qword[Zobrist_Pieces+r15+8*rdx]
		and   rax, qword[mainHash.mask]
		shl   rax, 5
		add   rax, qword[mainHash.table]
	prefetchnta   [rax]


	; check for legality
		mov   ecx, dword[.move]
	       call   Move_IsLegal
	       test   rax, rax
		 jz   .MovePickLoop

	; make the move
		mov   ecx, dword[.move]
	      movzx   edx, byte[.givesCheck]
		mov   dword[rbx+State.currentMove], ecx
		mov   rsi, qword[.searchFxn]
	       call   Move_Do__QSearch

	; search the move
		mov   ecx, dword[.beta]
		neg   ecx
		mov   edx, dword[.alpha]
		neg   edx
		mov   r8d, dword[.depth]
		sub   r8d, 1
	       call   rsi
		neg   eax
		mov   edi, eax
		mov   dword[.value], eax

	; undo the move
		mov   ecx, dword[.move]
	       call   Move_Undo

	; check for new best move
		cmp   edi, dword[.bestValue]
		jle   .MovePickLoop
		mov   dword[.bestValue], edi
		cmp   edi, dword[.alpha]
		jle   .MovePickLoop

     if .PvNode eq 1
		mov   ecx, dword[.move]
		mov   r8, qword[rbx+0*sizeof.State+State.pv]
		mov   r9, qword[rbx+1*sizeof.State+State.pv]
		xor   eax, eax
		mov   dword[r8], ecx
		add   r8, 4
	       test   r9, r9
		 jz   .pv_copy_end
	.pv_copy_loop:
		mov   eax, dword[r9]
		add   r9, 4
	.pv_copy_end:
		mov   dword[r8], eax
		add   r8, 4
	       test   eax, eax
		jnz   .pv_copy_loop

		cmp   edi, dword[.beta]
		jge   .FailHigh
		mov   dword[.alpha], edi
		mov   dword[.bestMove], ecx

		jmp   .MovePickLoop
    end if




.FailHigh:
		mov   r9, qword[rbx+State.key]
		mov   r8, qword[.tte]
		shr   r9, 48
		mov   edx, edi
		lea   ecx, [rdi+VALUE_MATE_IN_MAX_PLY]
		cmp   ecx, 2*VALUE_MATE_IN_MAX_PLY
		jae   .FailHighValueToTT
.FailHighValueToTTRet:
		mov   eax, dword[.move]
     HashTable_Save   .ltte, r8, r9w, edx, BOUND_LOWER, byte[.ttDepth], eax, word[rbx+State.staticEval]
		mov   eax, edi
		jmp   .ReturnD

.FailHighValueToTT:
		mov   edx, dword[rbx+State.ply]
		mov   eax, edi
		sar   eax, 31
		xor   edx, eax
		sub   edx, eax
		add   edx, edi
		jmp   .FailHighValueToTTRet



.MovePickDone:
		mov   r9, qword[rbx+State.key]
		mov   edi, dword[.bestValue]
		lea   ecx, [rdi+VALUE_MATE_IN_MAX_PLY]

	if InCheck eq 1
		mov   eax, dword[rbx+State.ply]
		sub   eax, VALUE_MATE
		cmp   edi, -VALUE_INFINITE
		 je   .ReturnE
	end if

	if .PvNode eq 1
		mov   esi, dword[.oldAlpha]
		sub   esi, edi
		sar   esi, 31
	end if
		mov   r8, qword[.tte]
		shr   r9, 48
		mov   edx, edi
		cmp   ecx, 2*VALUE_MATE_IN_MAX_PLY
		jae   .ValueToTT
     .ValueToTTRet:


	if .PvNode eq 0
		mov   eax, dword[.bestMove]
     HashTable_Save   .ltte, r8, r9w, edx, BOUND_UPPER, byte[.ttDepth], eax, word[rbx+State.staticEval]
	else
		mov   eax, dword[.bestMove]
		and   esi, BOUND_EXACT-BOUND_UPPER
		add   esi, BOUND_UPPER
     HashTable_Save   .ltte, r8, r9w, edx, sil, byte[.ttDepth], eax, word[rbx+State.staticEval]
	end if
		mov   eax, edi

match =2, VERBOSE \{
		jmp   .ReturnF
\}

.ReturnA:
match =2, VERBOSE \{
push  rax rcx rdx r8
mov   word[Output],'A '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}

.ReturnB:
match =2, VERBOSE \{

push  rax rcx rdx r8
mov   word[Output],'B '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}

.ReturnC:
match =2, VERBOSE \{
push  rax rcx rdx r8
mov   word[Output],'C '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}

.ReturnD:
match =2, VERBOSE \{
push  rax rcx rdx r8
mov   word[Output],'D '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}

.ReturnE:
match =2, VERBOSE \{
push  rax rcx rdx r8
mov   word[Output],'E '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}

.ReturnF:
match =2, VERBOSE \{
push  rax rcx rdx r8
mov   word[Output],'F '
lea   rdi, [Output+2]
call   _WriteOut_Output
pop   r8 rdx rcx rax
jmp   .Return
\}


.Return:


match =2, VERBOSE \{
push rax r13 r14 r15
mov r15, rax
lea rdi, [VerboseOutput]
mov rax,'qsearch<'
stosq
match =1, InCheck \\{
mov al, 't'
\\}
match =0, InCheck \\{
mov al, 'f'
\\}
stosb
szcall PrintString, '> return: '
movsxd rax, r15d
call PrintSignedInteger
match =1, OS_IS_WINDOWS \\{
 mov al, 13
 stosb
\\}

mov al, 10
stosb
lea rcx, [VerboseOutput]
call _WriteOut
pop r15 r14 r13 rax
\}


		add   rsp, .localsize
		pop   r15 r14 r13 r12 rdi rsi rbx
		ret





    if InCheck eq 0

	      align   8
.CheckAdvancedPawnPush:
		and   edx, 7
		shr   r8d, 3
		xor   edx, r8d
		cmp   edx, 4
		 jb   .DoFutilityPruning
		jmp   .SkipFutilityPruning

	      align   8
.ContinueFromFutilityBase:
	       call   See
		mov   edx, r12d
		cmp   eax, 0
		 jg   .SkipFutilityPruning

	      align   8
.ContinueFromFutilityValue:
		cmp   edi, edx
	      cmovl   edi, edx
		mov   dword[.bestValue], edi
		jmp   .MovePickLoop

    end if


		      align   8
.AbortSearch_PlyBigger:
		xor   eax, eax
		cmp   rax, qword[rbx+State.checkersBB]
		jne   .ReturnA
	       call   Evaluate
		jmp   .ReturnA

		      align   8
.AbortSearch_PlySmaller:
		xor   eax, eax
		jmp   .ReturnA

	if .PvNode eq 0

	      align   8
.ReturnTTValue:
		mov   dword[rbx+State.currentMove], ecx
		mov   eax, edi
		jmp   .ReturnB
	end if



	      align   8
.ReturnStaticValue:
		mov   r8, qword[.tte]
		mov   r9, qword[rbx+State.key]
		shr   r9, 48
		mov   edx, eax
	       test   r13d, r13d
		jnz   .ReturnC
		add   eax, VALUE_MATE_IN_MAX_PLY
		cmp   eax, 2*VALUE_MATE_IN_MAX_PLY
		jae   .ReturnStaticValue_ValueToTT
 .ReturnStaticValue_ValueToTTRet:
     HashTable_Save   .ltte, r8, r9w, edx, BOUND_LOWER, DEPTH_NONE, 0, word[rbx+State.staticEval]
		mov   eax, dword[.bestValue]
		jmp   .ReturnC

 .ReturnStaticValue_ValueToTT:
		mov   ecx, dword[rbx+State.ply]
		mov   eax, edx
		sar   eax, 31
		xor   ecx, eax
		sub   edx, eax
		add   edx, ecx
		jmp   .ReturnStaticValue_ValueToTTRet


		      align   8
.ValueFromTT:
	; value in edi is not VALUE_NONE
		mov   r8d, dword[rbx+State.ply]
		mov   r9d, edi
		sar   r9d, 31
		xor   r8d, r9d
		add   edi, r9d
		sub   edi, r8d
		mov   dword[.ttValue], edi
		mov   eax, edi
		sub   eax, dword[.beta]
		sar   eax, 31
		jmp   .ValueFromTTRet

		      align   8
.ValueToTT:
		mov   edx, dword[rbx+State.ply]
		mov   eax, edi
		sar   eax, 31
		xor   edx, eax
		sub   edx, eax
		add   edx, edi
		jmp   .ValueToTTRet


		      align   8
.CheckDrawBy50:
   PosIsDrawCheck50   .AbortSearch_PlySmaller, r8
		jmp   .NoDrawBy50


}
