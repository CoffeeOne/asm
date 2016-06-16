Options_Init:
		lea   rdx, [options]
		lea   rcx, [DisplayInfo_Uci]
		mov   qword[rdx+Options.displayInfoFxn], rcx
		lea   rcx, [DisplayMove_Uci]
		mov   qword[rdx+Options.displayMoveFxn], rcx
		mov   dword[rdx+Options.contempt], 0
		mov   dword[rdx+Options.threads], 1
		mov   dword[rdx+Options.hash], 16
		mov   byte[rdx+Options.ponder], 0
		mov   dword[rdx+Options.multiPV], 1
		mov   dword[rdx+Options.weakness], 0
		mov   dword[rdx+Options.moveOverhead], 30
		mov   dword[rdx+Options.minThinkTime], 20
		mov   dword[rdx+Options.slowMover], 80
		mov   byte[rdx+Options.chess960], 0
		mov   dword[rdx+Options.weakness], 0
		mov   rax, '<empty>'
		mov   qword[rdx+Options.syzygyPath], rax
		mov   dword[rdx+Options.syzygyProbeDepth], 1
		mov   byte[rdx+Options.syzygy50MoveRule], -1
		mov   dword[rdx+Options.syzygyProbeLimit], 6
		ret


UciLoop:


virtual at rsp
  .th1 Thread
  .th2 Thread
  .states rb 2*sizeof.State
  .limits Limits
  .time  rq 1
  .nodes rq 1
  .localend rb 0
end virtual
.localsize = ((.localend-rsp+15) and (-16))

	       push   rbp rsi rdi rbx r11 r12 r13 r14 r15
		sub   rsp, UciLoop.localsize

		lea   rcx, [DisplayInfo_Uci]
		lea   rdx, [DisplayMove_Uci]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx

		lea   rcx, [UciLoop.states]
		lea   rdx, [rcx+2*sizeof.State]
		mov   qword[UciLoop.th2.rootPos.state], rcx
		mov   qword[UciLoop.th2.rootPos.stateTable], rcx
		mov   qword[UciLoop.th2.rootPos.stateEnd], rdx

		xor   eax, eax
		lea   rbp, [UciLoop.th1.rootPos]
		mov   qword[UciLoop.th1.rootPos.state], rax
		mov   qword[UciLoop.th1.rootPos.stateTable], rax
		mov   qword[UciLoop.th1.rootPos.stateEnd], rax
		lea   rsi, [szStartFEN]
		xor   ecx, ecx
	       call   Position_ParseFEN

match =2, VERBOSE {
		jmp   UciGetInput
}
match =3, VERBOSE {
		jmp   UciGetInput
}

UciUci:
		lea   rdi, [Output]
		lea   rcx, [szUCIresponse]
	       call   PrintString
UciWriteOut:
	       call   _WriteOut_Output
UciGetInput:

match =1, VERBOSE {
lea rdi, [Output]
mov rax, 'response'
stosq
mov rax, ' time:  '
stosq
call _GetTime
sub rdx, qword[VerboseTime1+8*0]
sbb rax, qword[VerboseTime1+8*1]
mov r8, rdx
mov ecx, 1000
mul rcx
xchg rax, r8
mul rcx
lea rax, [r8+rdx]
call PrintUnsignedInteger
mov eax, ' us' + (10 shl 24)
stosd
call _WriteOut_Output
}
	       call   _ReadIn

match =1, VERBOSE {
call _GetTime
mov qword[VerboseTime1+8*0], rdx
mov qword[VerboseTime1+8*1], rax
}
		cmp   byte[rsi], ' '
		 jb   UciGetInput     ; don't process empty lines

UciChoose:
	       call   SkipSpaces
	    stdcall   CmpString, 'position'
	       test   eax, eax
		jnz   UciPosition
	    stdcall   CmpString, 'go'
	       test   eax, eax
		jnz   UciGo
	    stdcall   CmpString, 'stop'
	       test   eax, eax
		jnz   UciStop
	    stdcall   CmpString, 'isready'
	       test   eax, eax
		jnz   UciIsReady
	    stdcall   CmpString, 'ponderhit'
	       test   eax, eax
		jnz   UciPonderHit
	    stdcall   CmpString, 'ucinewgame'
	       test   eax, eax
		jnz   UciNewGame
	    stdcall   CmpString, 'uci'
	       test   eax, eax
		jnz   UciUci
	    stdcall   CmpString, 'setoption'
	       test   eax, eax
		jnz   UciSetOption
	    stdcall   CmpString, 'quit'
	       test   eax, eax
		jnz   UciQuit

	    stdcall   CmpString, 'perft'
	       test   eax, eax
		jnz   UciPerft

	    stdcall   CmpString, 'show'
	       test   eax, eax
		jnz   UciShow
	    stdcall   CmpString, 'undo'
	       test   eax, eax
		jnz   UciUndo
	    stdcall   CmpString, 'moves'
	       test   eax, eax
		jnz   UciMoves
	    stdcall   CmpString, 'donull'
	       test   eax, eax
		jnz   UciDoNull
	    stdcall   CmpString, 'eval'
	       test   eax, eax
		jnz   UciEval
	    stdcall   CmpString, 'bench'
	       test   eax, eax
		jnz   UciBench

match =1, PROFILE {
	    stdcall   CmpString, 'profile'
	       test   eax, eax
		jnz   UciProfile
}

UciUnknown:
		lea   rdi, [Output]
	    stdcall   PrintString, 'error: unknown command '
		mov   ecx, 64
	       call   _ParseToken
		mov   al, 10
	      stosb
		jmp   UciWriteOut




UciQuit:
		lea   rcx, [mainThread]
		mov   byte[signals.stop], -1
	       call   Thread_StartSearching_TRUE
		lea   rcx, [mainThread]
	       call   Thread_WaitForSearchFinished
		mov   rcx, qword[UciLoop.th1.rootPos.stateTable]
	       call   _VirtualFree
		xor   eax, eax
		add   rsp, UciLoop.localsize
		pop   r15 r14 r13 r12 r11 rbx rdi rsi rbp
		ret

UciNewGame:
	       call   Search_Clear
		jmp   UciGetInput

;;;;;;;;;;;;
; isready
;;;;;;;;;;;;

UciIsReady:
		lea   rdi, [Output]
		mov   rax, 'readyok' + (10 shl 56)
	      stosq
		jmp   UciWriteOut




UciPonderHit:
		mov   al, byte[signals.stopOnPonderhit]
	       test   al, al
		jnz   UciStop
		mov   byte[limits.ponder], al
		jmp   UciGetInput
;;;;;;;;
; stop
;;;;;;;;

UciStop:
		mov   byte[signals.stop], -1
		lea   rcx, [mainThread]
	       call   Thread_StartSearching_TRUE
		jmp   UciGetInput

;;;;;;;
; go
;;;;;;;

UciGo:
		lea   rcx, [UciLoop.limits]
	       call   Limits_Init
.ReadLoop:
	       call   SkipSpaces
		cmp   byte[rsi], ' '
		 jb   .ReadLoopDone
		lea   rdi, [UciLoop.limits.time+4*White]
	     szcall   CmpString, 'wtime'
	       test   eax, eax
		jnz   .parse_dword
		lea   rdi, [UciLoop.limits.time+4*Black]
	     szcall   CmpString, 'btime'
	       test   eax, eax
		jnz   .parse_dword
		lea   rdi, [UciLoop.limits.incr+4*White]
	     szcall   CmpString, 'winc'
	       test   eax, eax
		jnz   .parse_dword
		lea   rdi, [UciLoop.limits.incr+4*Black]
	     szcall   CmpString, 'binc'
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.infinite]
	     szcall   CmpString, 'infinite'
	       test   eax, eax
		jnz   .parse_true

		lea   rdi, [UciLoop.limits.movestogo]
	     szcall   CmpString, 'movestogo'
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.nodes]
	     szcall   CmpString, 'nodes'
	       test   eax, eax
		jnz   .parse_qword

		lea   rdi, [UciLoop.limits.movetime]
	     szcall   CmpString, 'movetime'
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.depth]
	     szcall   CmpString, 'depth'
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.mate]
	     szcall   CmpString, 'mate'
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.ponder]
	     szcall   CmpString, 'ponder'
	       test   eax, eax
		jnz   .parse_true
		mov   ecx, 64
	       call   _SkipToken
		jmp   .ReadLoop
.ReadLoopDone:
		lea   rcx, [UciLoop.limits]
	       call   Limits_Set
		lea   rcx, [UciLoop.limits]
	       call   ThreadPool_StartThinking
		jmp   UciGetInput
.parse_qword:
	       call   SkipSpaces
	       call   ParseInteger
		mov   qword[rdi], rax
		jmp   .ReadLoop
.parse_dword:
	       call   SkipSpaces
	       call   ParseInteger
		mov   dword[rdi], eax
		jmp   .ReadLoop
.parse_true:
		mov   byte[rdi], -1
		jmp   .ReadLoop





;;;;;;;;;;;;
; position
;;;;;;;;;;;;

UciPosition:
	       call   SkipSpaces
		cmp   byte[rsi], ' '
		 jb   UciUnknown

	; write to pos2 in case of failure
		lea   rbp, [UciLoop.th2.rootPos]

	     szcall   CmpString, 'fen'
	       test   eax, eax
		jnz   .Fen
	     szcall   CmpString, 'startpos'
	       test   eax, eax
		 jz   .BadCmd
.Start:
		mov   r15, rsi
		lea   rsi, [szStartFEN]
		xor   ecx, ecx
	       call   Position_ParseFEN
		mov   rsi, r15
		jmp   .check
.Fen:
	      movzx   ecx, byte[options.chess960]
	       call   Position_ParseFEN
.check:
	       test   eax, eax
		jnz   .illegal
.moves:
	; copy pos2 to pos  before parsing moves
		lea   rcx, [UciLoop.th1.rootPos]
	       call   Position_CopyTo
		lea   rbp, [UciLoop.th1.rootPos]

	       call   SkipSpaces
	     szcall   CmpString, 'moves'
	       test   eax, eax
		 jz   UciGetInput
	       call   UciParseMoves
	       test   rax, rax
		 jz   UciGetInput
.badmove:
		mov   rsi, rax
		lea   rdi, [Output]
	     szcall   PrintString, 'error: illegal move '
		mov   ecx, 6
	       call   _ParseToken
		mov   al, 10
	      stosb
		lea   rbp, [UciLoop.th1.rootPos]
		jmp   UciWriteOut
.illegal:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: illegal fen'
		mov   al, 10
	      stosb
		lea   rbp, [UciLoop.th1.rootPos]
		jmp   UciWriteOut
.BadCmd:
		lea   rbp, [UciLoop.th1.rootPos]
		jmp   UciUnknown
UciParseMoves:
	; in: rbp position
	;     rsi string
	; rax = 0 if full string could be parsed
	;     = address of illegal move if there is one
	       push   rbx rsi rdi
.get_move:
	       call   SkipSpaces
		xor   eax, eax
		cmp   byte[rsi], ' '
		 jb   .done
	       call   ParseUciMove
		mov   edi, eax
	       test   eax, eax
		mov   rax, rsi
		 jz   .done
		mov   rbx, qword[rbp+Pos.state]
		mov   rax, rbx
		sub   rax, qword[rbp+Pos.stateTable]
		xor   edx, edx
		mov   ecx, sizeof.State
		div   ecx
	     Assert   e, edx, 0, 'weird remainder in UciParseMoves'
		lea   ecx, [rax+8]
		shr   ecx, 2
		add   ecx, eax
	       call   Position_SetExtraCapacity
		mov   rbx, qword[rbp+Pos.state]
		mov   ecx, edi
		mov   word[rbx+State.move+sizeof.State], cx
	       call   Move_GivesCheck
	      movzx   ecx, word[rbx+State.move+sizeof.State]
		mov   edx, eax
	       call   Move_Do__UciParseMoves
	; when VERBOSE=0, domove/undomove don't update gamPly
match =0, VERBOSE {
		inc   dword[rbp+Pos.gamePly]
}
		mov   qword[rbp+Pos.state], rbx
	       call   SetCheckInfo
		jmp   .get_move
.done:
		pop   rdi rsi rbx
		ret



;;;;;;;;;;;;
; setoption
;;;;;;;;;;;;


UciSetOption:
.Read:
	       call   SkipSpaces
		cmp   byte[rsi], ' '
		 jb   .Error

	     szcall   CmpString, 'name'
	       test   eax, eax
		 jz   .Error
	       call   SkipSpaces

	     szcall   CmpStringCaseless, 'Contempt'
		lea   rbx, [.Contempt]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'Threads'
		lea   rbx, [.Threads]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'Hash'
		lea   rbx, [.Hash]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'ClearHash'
		lea   rbx, [.ClearHash]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'Ponder'
		lea   rbx, [.Ponder]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'MultiPv'
		lea   rbx, [.MultiPv]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'Weakness'
		lea   rbx, [.Weakness]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'MoveOverhead'
		lea   rbx, [.MoveOverhead]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'MinThinkTime'
		lea   rbx, [.MinThinkTime]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'SlowMover'
		lea   rbx, [.SlowMover]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'UCI_Chess960'
		lea   rbx, [.Chess960]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'SyzygyPath'
		lea   rbx, [.SyzygyPath]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'SyzygyProbeDepth'
		lea   rbx, [.SyzygyProbeDepth]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'Syzygy50MoveRule'
		lea   rbx, [.Syzygy50MoveRule]
	       test   eax, eax
		jnz   .CheckValue
	     szcall   CmpStringCaseless, 'SyzygyProbeLimit'
		lea   rbx, [.SyzygyProbeLimit]
	       test   eax, eax
		jnz   .CheckValue

.Error:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: setoption has no value'
		mov   al, 10
	      stosb
	       call   _WriteOut_Output
		jmp   UciGetInput
.CheckValue:
	       call   SkipSpaces
	     szcall   CmpString, 'value'
	       test   eax, eax
		 jz   .Error
	       call   SkipSpaces
		jmp   rbx

.Hash:
	       call   ParseInteger
      ClampUnsigned   eax, 1, 1 shl MAX_HASH_LOG2MB
		mov   ecx, eax
		mov   dword[options.hash], eax
	       call   MainHash_Allocate
		jmp   UciGetInput
.Threads:
	       call   ParseInteger
      ClampUnsigned   eax, 1, MAX_THREADS
		mov   dword[options.threads], eax
	       call   ThreadPool_ReadOptions
		jmp   UciGetInput
.MultiPv:
	       call   ParseInteger
      ClampUnsigned   eax, 1, MAX_MOVES
		mov   dword[options.multiPV], eax
		jmp   UciGetInput
.Weakness:
	       call   ParseInteger
      ClampUnsigned   eax, 0, 200
		mov   dword[options.weakness], eax
		jmp   UciGetInput
.Chess960:
	       call   ParseBoole
		mov   byte[options.chess960], al
		jmp   UciGetInput
.Ponder:
	       call   ParseBoole
		mov   byte[options.ponder], al
		jmp   UciGetInput
.Contempt:
	       call   ParseInteger
	ClampSigned   eax, -100, 100
		mov   dword[options.contempt], eax
		jmp   UciGetInput
.MoveOverhead:
	       call   ParseInteger
      ClampUnsigned   eax, 0, 5000
		mov   dword[options.moveOverhead], eax
		jmp   UciGetInput
.MinThinkTime:
	       call   ParseInteger
      ClampUnsigned   eax, 0, 5000
		mov   dword[options.minThinkTime], eax
		jmp   UciGetInput
.SlowMover:
	       call   ParseInteger
      ClampUnsigned   eax, 0, 1000
		mov   dword[options.slowMover], eax
		jmp   UciGetInput
.ClearHash:
	       call   Search_Clear
		jmp   UciGetInput
.SyzygyProbeDepth:
	       call   ParseInteger
      ClampUnsigned   eax, 1, 100
		mov   dword[options.syzygyProbeDepth], eax
		jmp   UciGetInput
.Syzygy50MoveRule:
	       call   ParseBoole
		mov   byte[options.syzygy50MoveRule], al
		jmp   UciGetInput
.SyzygyProbeLimit:
	       call   ParseInteger
      ClampUnsigned   eax, 0, 6
		mov   dword[options.syzygyProbeLimit], eax
		jmp   UciGetInput
.SyzygyPath:
		lea   rdi, [options.syzygyPath]
		mov   ecx, 62
	       call   ParseToEndLine
		xor   eax, eax
	       test   ecx, ecx
		 js   .SyzygyPath_TooLong
	      stosb
		lea   rcx, [options.syzygyPath]
	       call   TableBase_Init
		jmp   UciGetInput
.SyzygyPath_TooLong:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: path is too long'
		mov   al, 10
	      stosb
	       call   _WriteOut_Output
		jmp   UciGetInput

;;;;;;;;;;;;
; *extras*
;;;;;;;;;;;;




UciDoNull:

		mov   rbx, qword[rbp+Pos.state]
		mov   rax, qword[rbx+State.checkersBB]
	       test   rax, rax
		jnz   UciGetInput

		mov   rax, rbx
		sub   rax, qword[rbp+Pos.stateTable]
		xor   edx, edx
		mov   ecx, sizeof.State
		div   ecx
	     Assert   e, edx, 0, 'weird remainder in UciDoNull'
		lea   ecx, [rax+8]
		shr   ecx, 2
		add   ecx, eax
	       call   Position_SetExtraCapacity
		mov   rbx, qword[rbp+Pos.state]
		mov   word[rbx+State.move+sizeof.State], MOVE_NULL
	       call   Move_DoNull
		mov   qword[rbp+Pos.state], rbx
	       call   SetCheckInfo
		jmp   UciShow




UciPerft:
	       call   SkipSpaces
	       call   ParseInteger
	       test   eax, eax
		 jz   .bad_depth
		cmp   eax, 9
		 ja   .bad_depth
		mov   esi, eax
		mov   ecx, eax
	       call   Position_SetExtraCapacity
		mov   ecx, esi
	       call   PerftGen_Root
		jmp   UciGetInput
.bad_depth:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: bad depth '
		mov   ecx, 8
	       call   _ParseToken
		mov   al, 10
	      stosb
		jmp   UciWriteOut

UciShow:
		lea   rdi, [Output]
		mov   rbx, qword[rbp+Pos.state]
	       call   Position_Print
		jmp   UciWriteOut

UciUndo:
		mov   rbx, qword[rbp+Pos.state]
	       call   SkipSpaces
	       call   ParseInteger
		mov   r15d, eax
		cmp   r15d, 1
		adc   r15d, 0
		sub   r15d, 1
.Undo:
		cmp   rbx, qword[rbp+Pos.stateTable]
		jbe   UciShow
	      movzx   ecx, word[rbx+State.move]
	       call   Move_Undo
		sub   r15d, 1
		jns   .Undo
		jmp   UciShow


UciMoves:
	       call   UciParseMoves
		jmp   UciShow





UciEval:
		mov   rbx, qword[rbp+Pos.state]
	; allocate pawn hash
		mov   ecx, PAWN_HASH_ENTRY_COUNT*sizeof.PawnEntry
	       call   _VirtualAlloc
		mov   qword[rbp+Pos.pawnTable], rax
	; allocate material hash
		mov   ecx, MATERIAL_HASH_ENTRY_COUNT*sizeof.MaterialEntry
	       call   _VirtualAlloc
		mov   qword[rbp+Pos.materialTable], rax
	       call   Evaluate
		mov   r15d, eax
	; free material hash
		mov   rcx, qword[rbp+Pos.materialTable]
	       call   _VirtualFree
		xor   eax, eax
		mov   qword[rbp+Pos.materialTable], rax
	; free pawn hash
		mov   rcx, qword[rbp+Pos.pawnTable]
	       call   _VirtualFree
		xor   eax, eax
		mov   qword[rbp+Pos.pawnTable], rax

		lea   rdi, [Output]
	     movsxd   rax, r15d
	       call   PrintSignedInteger
		mov   eax, ' == '
	      stosd
		mov   ecx, r15d
	       call   PrintScore_Uci
		mov   al, 10
	      stosb
		jmp   UciWriteOut




match =1, PROFILE {
UciProfile:
		lea   rdi, [Output]

	     szcall   PrintString, 'moveDo:        '
		mov   rax, qword[profile.moveDo]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb
	     szcall   PrintString, 'moveUnpack:    '
		mov   rax, qword[profile.moveUnpack]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb
	     szcall   PrintString, 'moveStore:     '
		mov   rax, qword[profile.moveStore]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb
	     szcall   PrintString, 'moveRetrieve:  '
		mov   rax, qword[profile.moveRetrieve]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb


	       push   rdi
		lea   rdi, [profile]
		mov   ecx, profile.ender-profile
		xor   eax, eax
	      stosb
		pop   rdi
		jmp   UciWriteOut

}

UciBench:
	       call   SkipSpaces
	       call   ParseInteger
		mov   r12d, 20		; default depth
		lea   ecx, [rax-1]
		cmp   ecx, MAX_PLY-20
	      cmovb   r12d, eax

		xor   eax, eax
		mov   qword[UciLoop.nodes], rax
		lea   rcx, [DisplayInfo_None]
		lea   rdx, [DisplayMove_None]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx
	       call   Search_Clear

		sub   rsp, 8*4
	       call   qword[__imp_GetCurrentProcess]
		mov   rcx, rax
		mov   edx, REALTIME_PRIORITY_CLASS
	       call   qword[__imp_SetPriorityClass]
		add   rsp, 8*4

		xor   r13d, r13d
		mov   qword[UciLoop.time], r13
		mov   qword[UciLoop.nodes], r13
.nextpos:
		mov   rsi, [.bench_fen_tab+8*r13]
	       call   Position_ParseFEN
		lea   rcx, [UciLoop.limits]
	       call   Limits_Init
		lea   rcx, [UciLoop.limits]
		mov   dword[rcx+Limits.depth], r12d
	       call   Limits_Set
		lea   rcx, [UciLoop.limits]

	       call   _GetTime
		mov   r14, rax
		lea   rcx, [UciLoop.limits]
	       call   ThreadPool_StartThinking
		lea   rcx, [mainThread]
	       call   Thread_WaitForSearchFinished
	       call   _GetTime
		sub   r14, rax
		neg   r14
	       call   ThreadPool_NodesSearched
		add   qword[UciLoop.time], r14
		add   qword[UciLoop.nodes], rax
		mov   r15, rax

		lea   rdi, [Output]
		mov   rax, 'nodes:  '
	      stosq
		mov   rax, r15
	       call   PrintUnsignedInteger
		mov   eax, '    '
	      stosd
		mov   rcx, r14
		cmp   r14, 1
		adc   rcx, 0
		mov   rax, r15
		xor   edx, edx
		div   rcx
	       call   PrintUnsignedInteger
		mov   al, ' '
	      stosb
		mov   eax, 'knps'
	      stosd
		mov   al, 10
	      stosb
	       call   _WriteOut_Output

		add   r13d, 1
		cmp   r13d, 30
		 jb   .nextpos

		sub   rsp, 8*4
	       call   qword[__imp_GetCurrentProcess]
		mov   rcx, rax
		mov   edx, NORMAL_PRIORITY_CLASS
	       call   qword[__imp_SetPriorityClass]
		add   rsp, 8*4

		lea   rdi, [Output]
		mov   rax, 'total no'
	      stosq
		mov   rax, 'des:    '
	      stosq
		mov   rax, qword[UciLoop.nodes]
	       call   PrintUnsignedInteger
		mov   eax, '    '
	      stosd
		mov   rcx, qword[UciLoop.time]
		cmp   rcx, 1
		adc   rcx, 0
		mov   rax, qword[UciLoop.nodes]
		xor   edx, edx
		div   rcx
	       call   PrintUnsignedInteger
		mov   al, ' '
	      stosb
		mov   eax, 'knps'
	      stosd
		mov   al, 10
	      stosb
	       call   _WriteOut_Output

		lea   rcx, [DisplayInfo_Uci]
		lea   rdx, [DisplayMove_Uci]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx
		jmp   UciGetInput

align 8
.bench_fen_tab:
dq .bench_fen00
dq .bench_fen01
dq .bench_fen02
dq .bench_fen03
dq .bench_fen04
dq .bench_fen05
dq .bench_fen06
dq .bench_fen07
dq .bench_fen08
dq .bench_fen09
dq .bench_fen10
dq .bench_fen11
dq .bench_fen12
dq .bench_fen13
dq .bench_fen14
dq .bench_fen15
dq .bench_fen16
dq .bench_fen17
dq .bench_fen18
dq .bench_fen19
dq .bench_fen20
dq .bench_fen21
dq .bench_fen22
dq .bench_fen23
dq .bench_fen24
dq .bench_fen25
dq .bench_fen26
dq .bench_fen27
dq .bench_fen28
dq .bench_fen29
dq .bench_fen30
dq .bench_fen31
dq .bench_fen32
dq .bench_fen33
dq .bench_fen34
dq .bench_fen35
dq .bench_fen36



.bench_fen00 db "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",0
.bench_fen01 db "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 10",0
.bench_fen02 db "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 11",0
.bench_fen03 db "4rrk1/pp1n3p/3q2pQ/2p1pb2/2PP4/2P3N1/P2B2PP/4RRK1 b - - 7 19",0
.bench_fen04 db "rq3rk1/ppp2ppp/1bnpb3/3N2B1/3NP3/7P/PPPQ1PP1/2KR3R w - - 7 14",0
.bench_fen05 db "r1bq1r1k/1pp1n1pp/1p1p4/4p2Q/4Pp2/1BNP4/PPP2PPP/3R1RK1 w - - 2 14",0
.bench_fen06 db "r3r1k1/2p2ppp/p1p1bn2/8/1q2P3/2NPQN2/PPP3PP/R4RK1 b - - 2 15",0
.bench_fen07 db "r1bbk1nr/pp3p1p/2n5/1N4p1/2Np1B2/8/PPP2PPP/2KR1B1R w kq - 0 13",0
.bench_fen08 db "r1bq1rk1/ppp1nppp/4n3/3p3Q/3P4/1BP1B3/PP1N2PP/R4RK1 w - - 1 16",0
.bench_fen09 db "4r1k1/r1q2ppp/ppp2n2/4P3/5Rb1/1N1BQ3/PPP3PP/R5K1 w - - 1 17",0
.bench_fen10 db "2rqkb1r/ppp2p2/2npb1p1/1N1Nn2p/2P1PP2/8/PP2B1PP/R1BQK2R b KQ - 0 11",0
.bench_fen11 db "r1bq1r1k/b1p1npp1/p2p3p/1p6/3PP3/1B2NN2/PP3PPP/R2Q1RK1 w - - 1 16",0
.bench_fen12 db "3r1rk1/p5pp/bpp1pp2/8/q1PP1P2/b3P3/P2NQRPP/1R2B1K1 b - - 6 22",0
.bench_fen13 db "r1q2rk1/2p1bppp/2Pp4/p6b/Q1PNp3/4B3/PP1R1PPP/2K4R w - - 2 18",0
.bench_fen14 db "4k2r/1pb2ppp/1p2p3/1R1p4/3P4/2r1PN2/P4PPP/1R4K1 b - - 3 22",0
.bench_fen15 db "3q2k1/pb3p1p/4pbp1/2r5/PpN2N2/1P2P2P/5PP1/Q2R2K1 b - - 4 26",0
.bench_fen16 db "6k1/6p1/6Pp/ppp5/3pn2P/1P3K2/1PP2P2/3N4 b - - 0 1",0
.bench_fen17 db "3b4/5kp1/1p1p1p1p/pP1PpP1P/P1P1P3/3KN3/8/8 w - - 0 1",0
.bench_fen18 db "2K5/p7/7P/5pR1/8/5k2/r7/8 w - - 0 1",0
.bench_fen19 db "8/6pk/1p6/8/PP3p1p/5P2/4KP1q/3Q4 w - - 0 1",0
.bench_fen20 db "7k/3p2pp/4q3/8/4Q3/5Kp1/P6b/8 w - - 0 1",0
.bench_fen21 db "8/2p5/8/2kPKp1p/2p4P/2P5/3P4/8 w - - 0 1",0
.bench_fen22 db "8/1p3pp1/7p/5P1P/2k3P1/8/2K2P2/8 w - - 0 1",0
.bench_fen23 db "8/pp2r1k1/2p1p3/3pP2p/1P1P1P1P/P5KR/8/8 w - - 0 1",0
.bench_fen24 db "8/3p4/p1bk3p/Pp6/1Kp1PpPp/2P2P1P/2P5/5B2 b - - 0 1",0
.bench_fen25 db "5k2/7R/4P2p/5K2/p1r2P1p/8/8/8 b - - 0 1",0
.bench_fen26 db "6k1/6p1/P6p/r1N5/5p2/7P/1b3PP1/4R1K1 w - - 0 1",0
.bench_fen27 db "1r3k2/4q3/2Pp3b/3Bp3/2Q2p2/1p1P2P1/1P2KP2/3N4 w - - 0 1",0
.bench_fen28 db "6k1/4pp1p/3p2p1/P1pPb3/R7/1r2P1PP/3B1P2/6K1 w - - 0 1",0
.bench_fen29 db "8/3p3B/5p2/5P2/p7/PP5b/k7/6K1 w - - 0 1",0
  ; 5-man positions
.bench_fen30 db "8/8/8/8/5kp1/P7/8/1K1N4 w - - 0 1",0	  ; Kc2 - mate
.bench_fen31 db "8/8/8/5N2/8/p7/8/2NK3k w - - 0 1",0	  ; Na2 - mate
.bench_fen32 db "8/3k4/8/8/8/4B3/4KB2/2B5 w - - 0 1",0	  ; draw
  ; 6-man positions
.bench_fen33 db "8/8/1P6/5pr1/8/4R3/7k/2K5 w - - 0 1",0   ; Re5 - mate
.bench_fen34 db "8/2p4P/8/kr6/6R1/8/8/1K6 w - - 0 1",0	  ; Ka2 - mate
.bench_fen35 db "8/8/3P3k/8/1p6/8/1P6/1K3n2 b - - 0 1",0  ; Nd2 - draw
  ; 7-man positions
.bench_fen36 db "8/R7/2q5/8/6k1/8/1P5p/K6R w - - 0 124",0  ; Draw

