
; many bugs can be caught in DoMove
; we catch the caller of DoMove and make sure that the move is legal
	      align   16

Move_Do__UciParseMoves:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__UciParseMoves',0	   }

Move_Do__PerftGen_Root:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__PerftGen_Root',0	   }

Move_Do__PerftGen_Branch:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__PerftGen_Branch',0	     }

Move_Do__ExtractPonderFromTT:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__ExtractPonderFromTT',0		 }

Move_Do__Search:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__Search',0			 }

Move_Do__QSearch:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__QSearch',0			 }

Move_Do__EasyMoveMng:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__EasyMoveMng',0			 }

Move_Do__RootMove_InsertPVInTT:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__RootMove_InsertPVInTT',0	 }

Move_Do__ProbCut:
match =1, DEBUG {
		lea   rax, [@f]
		mov   [rbp+Pos.debugPointer], rax
		jmp   Move_Do
@@: db 'DoMove__ProbCut',0	   }


Move_Do:
	; in: rbp  address of Pos
	;     rbx  address of State
	;     ecx  move
	;     edx  move is check

	       push   rsi rdi r12 r13 r14 r15
	       push   rcx rdx

match =1, DEBUG {
push rcx rdx
sub rsp, MAX_MOVES*sizeof.ExtMove
mov dword[rbp+Pos.debugMove], ecx
lea rdi, [DebugOutput]
mov qword[rbp+Pos.state], rbx
call Position_PrintSmall
mov eax, 10
stosd
mov qword[rbp+Pos.state], rbx
call Position_IsLegal
test eax, eax
jnz Move_Do_posill
mov ecx, dword[rbp+Pos.debugMove]
call Move_IsPseudoLegal
test rax, rax
jz Move_Do_pillegal
mov ecx, dword[rbp+Pos.debugMove]
call Move_IsLegal
test eax, eax
jz Move_Do_illegal
mov rdi, rsp
call Gen_Legal
mov rcx, rsp
@@:
cmp rcx, rdi
jae Move_Do_DoIllegal
mov eax, dword[rbp+Pos.debugMove]
cmp eax, dword[rcx]
lea rcx,[rcx+sizeof.ExtMove]
jne @b
add rsp, MAX_MOVES*sizeof.ExtMove
pop rdx rcx
}

match=1, VERBOSE {
push rax rcx rsi rdi
lea rdi, [VerboseOutput]
mov rax, 'do move '
stosq
call PrintUciMove
mov al, 10
stosb
lea rcx, [VerboseOutput]
call _WriteOut
pop rdi rsi rcx rax
}

		mov   esi, dword[rbp+Pos.sideToMove]

		mov   r15, qword[Zobrist_side]

		mov   r8d, ecx
		shr   r8d, 6
		and   r8d, 63	; r8d = from
		mov   r9d, ecx
		and   r9d, 63	; r9d = to
		shr   ecx, 12

match =1, PROFILE {
lock inc qword[profile.moveDo]
lock inc qword[profile.moveUnpack]
}

	      movzx   r10d, byte[rbp+Pos.board+r8]     ; r10 = FROM PIECE
	      movzx   r11d, byte[rbp+Pos.board+r9]     ; r11 = TO PIECE

	       push   r10

		xor   r15, qword[rbx+State.key]
		mov   r14, qword[rbx+State.pawnKey]
		mov   r13, qword[rbx+State.materialKey]
	      vmovq   xmm0, qword[rbx+State.psq]       ; psq and npMaterial
		cmp   ecx, MOVE_TYPE_CASTLE
		sbb   edi, edi

	; update rule50 and pliesFromNull and capturedPiece
	      movzx   eax, word[rbx+State.rule50]
		add   eax, 0101H
		and   al, byte[IsNotPawnMasks+r10]
		and   al, byte[IsNotPieceMasks+r11]
		mov   word[rbx+sizeof.State+State.rule50], ax
		mov   byte[rbx+sizeof.State+State.capturedPiece], r11l

	; castling rights
	      movzx   edx, byte[rbx+State.castlingRights]
	      movzx   eax, byte[castling_rightsMask+r8]
		 or   al, byte[castling_rightsMask+r9]
		and   edi, 7
		and   al, dl
		jnz   .Rights
.RightsRet:	mov   byte [rbx+State.castlingRights+sizeof.State], dl

	; ep square
	      movzx   eax, byte[rbx+State.epSquare]
		mov   r12d, r11d
		and   r12d, 8
		cmp   eax, 64
		 jb   .ResetEp
		mov   byte[rbx+State.epSquare+sizeof.State], al
.ResetEpRet:
	; capture
		mov   eax, r11d
		and   eax, edi
		jnz   .Capture
.CaptureRet:
	; move piece
		xor   edx, edx
		bts   rdx, r8
	       push   rdx
		bts   rdx, r9
	       push   rdx
		mov   eax, r10d
		and   eax, 7
		mov   byte[rbp+Pos.board+r8], 0
		mov   byte[rbp+Pos.board+r9], r10l
		xor   qword[rbp+Pos.typeBB+8*rax], rdx
		xor   qword[rbp+Pos.typeBB+8*rsi], rdx
	      movsx   rax, byte[IsPawnMasks+r10]
		shl   r10d, 6+3
		mov   rdx, qword[Zobrist_Pieces+r10+8*r8]
		xor   rdx, qword[Zobrist_Pieces+r10+8*r9]
	      vmovd   xmm1, dword[Scores_Pieces+r10+8*r8]
	      vmovd   xmm2, dword[Scores_Pieces+r10+8*r9]
		xor   r15, rdx
		and   rax, rdx
		xor   r14, rax
	     vpsubd   xmm0, xmm0, xmm1
	     vpaddd   xmm0, xmm0, xmm2
		shr   r10d, 6+3

	; special moves
		cmp   ecx, MOVE_TYPE_DPAWN
		 je   .DoublePawn
		jae   .Special
.SpecialRet:

	; write remaining data to next state entry

		pop   r9 r8 r10 rdx rcx
		xor   esi, 1
		add   rbx, sizeof.State
		xor   r9, r8
		and   r10d, 7
		shr   ecx, 12

		mov   dword[rbp+Pos.sideToMove], esi
		mov   qword[rbp+Pos.state], rbx

		mov   qword[rbx+State.key], r15
		mov   qword[rbx+State.pawnKey], r14
		mov   qword[rbx+State.materialKey], r13
	      vmovq   qword[rbx+State.psq], xmm0

	       test   rdx, rdx
		jnz   .MoveIsCheck
		mov   qword[rbx+State.checkersBB], rdx

.Done:


match =1, DEBUG {
		mov   qword[rbp+Pos.state], rbx
	       call   Position_IsLegal
	       test   eax, eax
		jnz   Move_Do_post_posill
}


		pop   r15 r14 r13 r12 rdi rsi
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	      align   8
.Capture:
	; remove piece r11(=r12+rax) on to square r9

match =1, DEBUG {
		lea   edx, [8*rsi]
		cmp   edx, r12d
		 je   Move_Do_capself
		cmp   eax, King
		 je   Move_Do_capking
}

		mov   rdi, qword[rbp+Pos.typeBB+r12]
		mov   rdx, qword[rbp+Pos.typeBB+8*rax]
		btr   rdi, r9
		btr   rdx, r9
		mov   qword[rbp+Pos.typeBB+r12], rdi
		mov   qword[rbp+Pos.typeBB+8*rax], rdx
		and   rdi, rdx
	     popcnt   rdi, rdi, rdx
	      movsx   rax, byte[IsPawnMasks+r11]
		shl   r11d, 6+3
		mov   rdx, qword[Zobrist_Pieces+r11+8*r9]
		xor   r15, rdx
		and   rax, rdx
		xor   r14, rax
		xor   r13, qword[Zobrist_Pieces+r11+8*rdi]
	      vmovq   xmm1, qword[Scores_Pieces+r11+8*r9]
	     vpsubd   xmm0, xmm0, xmm1
		shr   r11d, 6+3
		jmp   .CaptureRet



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	      align   8
.MoveIsCheck:
		mov   rax, qword[rbx+State.dcCandidates-sizeof.State]
		mov   r10, qword[rbx+State.checkSq-sizeof.State+8*r10]
	       test   ecx, ecx
		jae   .DoFull
		and   r10, r9
	       test   rax, r8
		jnz   .DoFull
		mov   qword[rbx+State.checkersBB], r10
		jmp   .Done
.DoFull:
		mov   ecx, esi
		mov   rdx, qword[rbp+Pos.typeBB+8*King]
		and   rdx, qword[rbp+Pos.typeBB+8*rsi]
		bsf   rdx, rdx
	       call   AttackersTo_Side
		mov   qword[rbx+State.checkersBB], rax
		jmp   .Done


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	      align   8
.ResetEp:
		and   eax, 7
		xor   r15, qword[Zobrist_Ep+8*rax]
		mov   byte[rbx+sizeof.State+State.epSquare], 64
		jmp   .ResetEpRet


	      align   8
.Rights:
		xor   edx, eax
		xor   r15, qword[Zobrist_Castling+8*rax]
		jmp   .RightsRet

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	      align   8
.DoublePawn:
		mov   edx, esi
		shl   edx, 6+3
		add   r8d, r9d
		shr   r8d, 1
		mov   rax, qword[WhitePawnAttacks+rdx+8*r8]
		mov   edx, esi
		xor   edx, 1
		and   rax, qword[rbp+Pos.typeBB+8*Pawn]
	       test   rax, qword[rbp+Pos.typeBB+8*rdx]
		 jz   .SpecialRet
		mov   byte[rbx+State.epSquare+sizeof.State], r8l
		and   r8d, 7
		xor   r15, qword[Zobrist_Ep+8*r8]
		jmp   .SpecialRet


	      align   8
.Special:
		xor   edx, edx
		cmp   ecx, MOVE_TYPE_CASTLE
		 je   .Castling
		jae   .EpCapture

.Promotion:
		lea   ecx, [rcx-MOVE_TYPE_PROM+8*rsi+Knight]
	; remove pawn r10 on square r9
		mov   rdx, qword[rbp+Pos.typeBB+8*Pawn]
		btr   rdx, r9
		mov   qword[rbp+Pos.typeBB+8*Pawn], rdx
		and   rdx, qword[rbp+Pos.typeBB+8*rsi]
	     popcnt   rax, rdx, r8
		shl   r10d, 6+3
		mov   rdx, qword[Zobrist_Pieces+r10+8*r9]
		xor   r15, rdx
		xor   r14, rdx
		xor   r13, qword[Zobrist_Pieces+r10+8*rax]
	      vmovq   xmm1, qword[Scores_Pieces+r10+8*r9]
	     vpsubd   xmm0, xmm0, xmm1
	; place piece ecx on square r9
		mov   eax, ecx
		and   eax, 7
		mov   rdx, qword[rbp+Pos.typeBB+8*rax]
		bts   rdx, r9
		mov   qword[rbp+Pos.typeBB+8*rax], rdx
		mov   byte[rbp+Pos.board+r9], cl
		and   rdx, qword [rbp+Pos.typeBB+8*rsi]
	     popcnt   rax, rdx, r8
		shl   ecx, 6+3
		xor   r15, qword[Zobrist_Pieces+rcx+8*r9]
		xor   r13, qword[Zobrist_Pieces+rcx+8*(rax-1)]
	      vmovq   xmm1, qword[Scores_Pieces+rcx+8*r9]
	     vpaddd   xmm0, xmm0, xmm1
		jmp   .SpecialRet



	      align   8
.EpCapture:
	; remove pawn r10^8 on sqare ecx=r9+8*(2*esi-1)
		lea   ecx, [2*rsi-1]
		lea   ecx, [r9+8*rcx]
		xor   r10, 8
		xor   esi, 1
		mov   rdx, qword[rbp+Pos.typeBB+8*Pawn]
		mov   rdi, qword[rbp+Pos.typeBB+8*rsi]
		btr   rdx, rcx
		btr   rdi, rcx
		mov   qword[rbp+Pos.typeBB+8*Pawn], rdx
		mov   qword[rbp+Pos.typeBB+8*rsi], rdi
		mov   byte[rbp+Pos.board+rcx], 0
		and   rdi, rdx
	     popcnt   rdi, rdi, rdx
		shl   r10d, 6+3
		mov   rdx, qword[Zobrist_Pieces+r10+8*rcx]
		xor   r15, rdx
		xor   r14, rdx
		xor   r13, qword[Zobrist_Pieces+r10+8*rdi]
	      vmovq   xmm1, qword[Scores_Pieces+r10+8*rcx]
	     vpsubd   xmm0, xmm0, xmm1
		lea   eax, [8*rsi+Pawn]
		mov   byte[rbx+sizeof.State+State.capturedPiece], al
		xor   esi, 1
		jmp   .SpecialRet


	      align   8
.Castling:
	; r8 = kfrom
	; r9 = kto
	; ecx = rfrom
	; edx = rto
	; r10 = ourking
	; r11 = our rook
	;
	; this is too tricky due to chess960 so nothing fancy here

match =1, DEBUG {
		mov   eax, dword[rbp+Pos.debugMove]
		cmp   eax, dword[castling_movgen+8*rsi+0]
		 je   @f
		cmp   eax, dword[castling_movgen+8*rsi+4]
		jne   Move_Do_badcas
		@@:
}
		mov   eax, r9d
		and   eax, 7
		mov   edx, esi
		cmp   eax, 4
		adc   edx, edx
	      movzx   ecx, byte[castling_rfrom+rdx]
	      movzx   edx, byte[castling_rto+rdx]
		lea   r11d, [r10-King+Rook]
		mov   byte[rbp+Pos.board+r8], 0
		mov   byte[rbp+Pos.board+rcx], 0
		mov   byte[rbp+Pos.board+r9], r10l
		mov   byte[rbp+Pos.board+rdx], r11l
		mov   byte[rbx+sizeof.State+State.capturedPiece], 0
		shl   r11d, 6+3
		xor   r15, qword[Zobrist_Pieces+r11+8*rcx]
		xor   r15, qword[Zobrist_Pieces+r11+8*rdx]
	      vmovd   xmm1, dword[Scores_Pieces+r11+8*rcx]
	      vmovd   xmm2, dword[Scores_Pieces+r11+8*rdx]
	     vpsubd   xmm0, xmm0, xmm1
	     vpaddd   xmm0, xmm0, xmm2
		mov   rax, qword[rbp+Pos.typeBB+8*rsi]
		mov   r10, qword[rbp+Pos.typeBB+8*King]
		mov   r11, qword[rbp+Pos.typeBB+8*Rook]
		btr   rax, r8
		btr   rax, rcx
		bts   rax, r9
		bts   rax, rdx
		btr   r10, r8
		bts   r10, r9
		btr   r11, rcx
		bts   r11, rdx
		mov   qword[rbp+Pos.typeBB+8*rsi], rax
		mov   qword[rbp+Pos.typeBB+8*King], r10
		mov   qword[rbp+Pos.typeBB+8*Rook], r11
		jmp   .SpecialRet



















match =1, DEBUG {

Move_Do_posill:
		lea   rdi, [Output]
	     szcall   PrintString, 'position did not pass Position_IsLegal in DoMove'
		jmp   Move_Do_GoError
Move_Do_pillegal:
		lea   rdi, [Output]
	     szcall   PrintString, 'move did not pass IsMovePseudoLegal in DoMove'
		jmp   Move_Do_GoError
Move_Do_illegal:
		lea   rdi, [Output]
	     szcall   PrintString, 'move did not pass IsMoveLegal in DoMove'
		jmp   Move_Do_GoError
Move_Do_DoIllegal:
		lea   rdi, [Output]
	     szcall   PrintString, 'move not in legal list in DoMove'
		jmp   Move_Do_GoError
Move_Do_badcas:
		lea   rdi, [Output]
	     szcall   PrintString, 'bad castling in DoMove'
		jmp   Move_Do_GoError
Move_Do_capself:
		lea   rdi, [Output]
	     szcall   PrintString, 'capture self in DoMove'
		jmp   Move_Do_GoError
Move_Do_capking:
		lea   rdi, [Output]
	     szcall   PrintString, 'capture king in DoMove'
		jmp   Move_Do_GoError
Move_Do_post_posill:
		lea   rdi, [Output]
	      szcall  PrintString, 'position not legal after making'
		jmp   Move_Do_GoError


Move_Do_GoError:
		mov   al, 10
	      stosb
		mov   rcx, qword[rbp+Pos.debugPointer]
	       call   PrintString
		mov   al, 10
	      stosb
		mov   rax, 'move:   '
		mov   ecx, dword[rbp+Pos.debugMove]
		mov   edx, dword[rbp+Pos.chess960]
	       call   PrintUciMoveLong
		mov   al, 10
	      stosb
		lea   rcx, [DebugOutput]
	       call   PrintString
		xor   eax, eax
	      stosd
		lea   rdi, [Output]
	       call   _ErrorBox
	       int3

}


