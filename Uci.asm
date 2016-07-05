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
;                mov   dword[rdx+Options.weakness], 0
		mov   dword[rdx+Options.moveOverhead], 30
		mov   dword[rdx+Options.minThinkTime], 20
		mov   dword[rdx+Options.slowMover], 80
		mov   byte[rdx+Options.chess960], 0
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
	 _chkstk_ms   rsp, UciLoop.localsize
		sub   rsp, UciLoop.localsize

		lea   rcx, [DisplayInfo_Uci]
		lea   rdx, [DisplayMove_Uci]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx

		xor   eax, eax
		mov   qword[UciLoop.th1.rootPos.stateTable], rax

		lea   rcx, [UciLoop.states]
		lea   rdx, [rcx+2*sizeof.State]
		mov   qword[UciLoop.th2.rootPos.state], rcx
		mov   qword[UciLoop.th2.rootPos.stateTable], rcx
		mov   qword[UciLoop.th2.rootPos.stateEnd], rdx

UciNewGame:
		mov   rcx, qword[UciLoop.th1.rootPos.stateTable]
	       call   _VirtualFree
		xor   eax, eax
		lea   rbp, [UciLoop.th1.rootPos]
		mov   qword[UciLoop.th1.rootPos.state], rax
		mov   qword[UciLoop.th1.rootPos.stateTable], rax
		mov   qword[UciLoop.th1.rootPos.stateEnd], rax
		lea   rsi, [szStartFEN]
		xor   ecx, ecx
	       call   Position_ParseFEN
	       call   Search_Clear

		mov   rsi, qword[CmdLineStart]
	       test   rsi, rsi
		jnz   UciChoose
		jmp   UciGetInput



UciNextCmdFromCmdLine:
	; skip to next cmd
	;  if we reach null char, it is time to read from stdin

		lea   rdi, [Output]
		lea   rcx, [sz_Info]
	       call   PrintString
	       call   _WriteOut_Output

		xor   r15, r15
.Next:
	      lodsb
	       test   al, al
		 jz   .Done
		cmp   al, ' '
		jae   .Next
	       call   SkipSpaces
		mov   r15, rsi
.Done:
		mov   rcx, qword[CmdLineStart]
		lea   rdi, [rsi-1]
	       call   _WriteOut
		lea   rcx, [sz_NewLine]
		lea   rdi, [sz_NewLineEnd]
	       call   _WriteOut

		mov   qword[CmdLineStart], r15
		mov   rsi, r15
	       test   r15, r15
		jnz   UciChoose
		jmp   UciGetInput

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
		mov   rsi, qword[CmdLineStart]
	       test   rsi, rsi
		jnz   UciNextCmdFromCmdLine

	       call   _ReadIn
	       test   eax, eax
		jnz   UciQuit

match =1, VERBOSE {
call _GetTime
mov qword[VerboseTime1+8*0], rdx
mov qword[VerboseTime1+8*1], rax
}
		cmp   byte[rsi], ' '
		 jb   UciGetInput     ; don't process empty lines

UciChoose:
	       call   SkipSpaces

		lea   rcx, [sz_position]
	       call   CmpString
	       test   eax, eax
		jnz   UciPosition

		lea   rcx, [sz_go]
	       call   CmpString
	       test   eax, eax
		jnz   UciGo

		lea   rcx, [sz_stop]
	       call   CmpString
	       test   eax, eax
		jnz   UciStop

		lea   rcx, [sz_isready]
	       call   CmpString
	       test   eax, eax
		jnz   UciIsReady

		lea   rcx, [sz_ponderhit]
	       call   CmpString
	       test   eax, eax
		jnz   UciPonderHit

		lea   rcx, [sz_ucinewgame]    ; check before uci :)
	       call   CmpString
	       test   eax, eax
		jnz   UciNewGame

		lea   rcx, [sz_uci]
	       call   CmpString
	       test   eax, eax
		jnz   UciUci

		lea   rcx, [sz_setoption]
	       call   CmpString
	       test   eax, eax
		jnz   UciSetOption

		lea   rcx, [sz_quit]
	       call   CmpString
	       test   eax, eax
		jnz   UciQuit

		lea   rcx, [sz_perft]
	       call   CmpString
	       test   eax, eax
		jnz   UciPerft

		lea   rcx, [sz_bench]
	       call   CmpString
	       test   eax, eax
		jnz   UciBench

if VERBOSE > 0
	     szcall   CmpString, 'show'
	       test   eax, eax
		jnz   UciShow
	     szcall   CmpString, 'undo'
	       test   eax, eax
		jnz   UciUndo
	     szcall   CmpString, 'moves'
	       test   eax, eax
		jnz   UciMoves
	     szcall   CmpString, 'donull'
	       test   eax, eax
		jnz   UciDoNull
	     szcall   CmpString, 'eval'
	       test   eax, eax
		jnz   UciEval
end if

if PROFILE > 0
	     szcall   CmpString, 'profile'
	       test   eax, eax
		jnz   UciProfile
end if

UciUnknown:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: unknown command '
		mov   ecx, 64
	       call   ParseToken
		mov   al, 10
	      stosb
		jmp   UciWriteOut




UciQuit:
		mov   byte[signals.stop], -1
		mov   rcx, qword[threadPool.threadTable+8*0]
	       call   Thread_StartSearching_TRUE
		mov   rcx, qword[threadPool.threadTable+8*0]
	       call   Thread_WaitForSearchFinished
		mov   rcx, qword[UciLoop.th1.rootPos.stateTable]
	       call   _VirtualFree
		xor   eax, eax
		add   rsp, UciLoop.localsize
		pop   r15 r14 r13 r12 r11 rbx rdi rsi rbp
		ret

;;;;;;;;
; uci
;;;;;;;;


UciUci:
		lea   rcx, [szUciResponse]
		lea   rdi, [szUciResponseEnd]
	       call   _WriteOut
		jmp   UciGetInput


;;;;;;;;;;;;
; isready
;;;;;;;;;;;;

UciIsReady:
		lea   rdi, [Output]
		mov   rax, 'readyok'
	      stosq
		sub   rdi, 1
       PrintNewLine
		jmp   UciWriteOut

;;;;;;;;;;;;;
; ponderhit
;;;;;;;;;;;;;

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
		mov   rcx, qword[threadPool.threadTable+8*0]
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
		lea   rcx, [sz_wtime]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.time+4*Black]
		lea   rcx, [sz_btime]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.incr+4*White]
		lea   rcx, [sz_winc]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.incr+4*Black]
		lea   rcx, [sz_binc]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.infinite]
		lea   rcx, [sz_infinite]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_true

		lea   rdi, [UciLoop.limits.movestogo]
		lea   rcx, [sz_movestogo]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.nodes]
		lea   rcx, [sz_nodes]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_qword

		lea   rdi, [UciLoop.limits.movetime]
		lea   rcx, [sz_movetime]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.depth]
		lea   rcx, [sz_depth]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.mate]
		lea   rcx, [sz_mate]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_dword

		lea   rdi, [UciLoop.limits.ponder]
		lea   rcx, [sz_ponder]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_true
		mov   ecx, 64
	       call   SkipToken
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
	       call   ParseToken
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
		mov   dword[rbx+sizeof.State+State.currentMove], edi
	       call   Move_GivesCheck
		mov   ecx, edi
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
		lea   rcx, [sz_name]
	       call   CmpString
		lea   rcx, [sz_error_name]
	       test   eax, eax
		 jz   .Error
	       call   SkipSpaces

		lea   rcx, [sz_threads]
	       call   CmpStringCaseless
		lea   rbx, [.Threads]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_hash]
	       call   CmpStringCaseless
		lea   rbx, [.Hash]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_clearhash]
	       call   CmpStringCaseless
		lea   rbx, [.ClearHash]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_ponder]
	       call   CmpStringCaseless
		lea   rbx, [.Ponder]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_contempt]
	       call   CmpStringCaseless
		lea   rbx, [.Contempt]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_multipv]
	       call   CmpStringCaseless
		lea   rbx, [.MultiPv]
	       test   eax, eax
		jnz   .CheckValue

;                lea   rcx, [sz_weakness]
;               call   CmpStringCaseless
;                lea   rbx, [.Weakness]
;               test   eax, eax
;                jnz   .CheckValue

		lea   rcx, [sz_moveoverhead]
	       call   CmpStringCaseless
		lea   rbx, [.MoveOverhead]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_minthinktime]
	       call   CmpStringCaseless
		lea   rbx, [.MinThinkTime]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_slowmover]
	       call   CmpStringCaseless
		lea   rbx, [.SlowMover]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_uci_chess960]
	       call   CmpStringCaseless
		lea   rbx, [.Chess960]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_syzygypath]
	       call   CmpStringCaseless
		lea   rbx, [.SyzygyPath]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_syzygyprobedepth]
	       call   CmpStringCaseless
		lea   rbx, [.SyzygyProbeDepth]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_syzygy50moverule]
	       call   CmpStringCaseless
		lea   rbx, [.Syzygy50MoveRule]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_syzygyprobelimit]
	       call   CmpStringCaseless
		lea   rbx, [.SyzygyProbeLimit]
	       test   eax, eax
		jnz   .CheckValue

		lea   rcx, [sz_error_value]
.Error:
		lea   rdi, [Output]
	       call   PrintString
		mov   al, 10
	      stosb
	       call   _WriteOut_Output
		jmp   UciGetInput
.CheckValue:
	       call   SkipSpaces
		lea   rcx, [sz_value]
	       call   CmpString
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
;.Weakness:
;               call   ParseInteger
;      ClampUnsigned   eax, 0, 200
;                mov   dword[options.weakness], eax
;                jmp   UciGetInput
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
	; find terminator and replace it with zero
		mov   rcx, rsi
	@@:	add   rsi, 1
		cmp   byte[rsi], ' '
		jae   @b
		mov   byte[rsi], 0
	       call   TableBase_Init
		jmp   UciGetInput



;;;;;;;;;;;;
; *extras*
;;;;;;;;;;;;

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
	       call   _SetRealtimePriority
		mov   ecx, esi
	       call   Perft_Root
	       call   _SetNormalPriority
		jmp   UciGetInput
.bad_depth:
		lea   rdi, [Output]
	     szcall   PrintString, 'error: bad depth '
		mov   ecx, 8
	       call   ParseToken
		mov   al, 10
	      stosb
		jmp   UciWriteOut



UciBench:
		mov   r12d, 15	 ; depth
		mov   r13d, 1	 ; threads
		mov   r14d, 128  ; hash

.parse_loop:
	       call   SkipSpaces
		cmp   byte[rsi], ' '
		 jb   .parse_done

		lea   rcx, [sz_threads]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_threads

		lea   rcx, [sz_depth]
	       call   CmpString
	       test   eax, eax
		jnz   .parse_depth

		lea   rcx, [sz_hash]
	       call   CmpString
	       test   eax, eax
		 jz   .parse_done
.parse_hash:
	       call   SkipSpaces
	       call   ParseInteger
      ClampUnsigned   eax, 1, 1 shl MAX_HASH_LOG2MB
		mov   r14d, eax
		jmp   .parse_loop
.parse_threads:
	       call   SkipSpaces
	       call   ParseInteger
      ClampUnsigned   eax, 1, MAX_THREADS
		mov   r13d, eax
		jmp   .parse_loop
.parse_depth:
	       call   SkipSpaces
	       call   ParseInteger
      ClampUnsigned   eax, 1, 40
		mov   r12d, eax
		jmp   .parse_loop

.parse_done:

		lea   rdi, [Output]
		mov   eax, '*** '
	      stosd
		mov   rax, 'starting'
	      stosq
		mov   rax, 'bench wi'
	      stosq
		mov   rax, 'th hash='
	      stosq
		mov   eax, r14d
	       call   PrintUnsignedInteger
		mov   rax, ' threads'
	      stosq
		mov   al, '='
	      stosb
		mov   eax, r13d
	       call   PrintUnsignedInteger
		mov   rax, ' depth ='
	      stosq
		mov   eax, r12d
	       call   PrintUnsignedInteger
		mov   eax, ' ***'
	      stosd
       PrintNewLine
	       call   _WriteOut_Output

		mov   ecx, r14d
		mov   dword[options.hash], r14d
	       call   MainHash_Allocate
		mov   dword[options.threads], r13d
	       call   ThreadPool_ReadOptions

		xor   eax, eax
		mov   qword[UciLoop.nodes], rax
		lea   rcx, [DisplayInfo_None]
		lea   rdx, [DisplayMove_None]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx
	       call   Search_Clear

	       call   _SetRealtimePriority

		xor   r13d, r13d
		mov   qword[UciLoop.time], r13
		mov   qword[UciLoop.nodes], r13
		lea   rsi, [BenchFens]
.nextpos:
		add   r13d, 1
	       call   SkipSpaces
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
		mov   rcx, qword[threadPool.threadTable+8*0]
	       call   Thread_WaitForSearchFinished
	       call   _GetTime
		sub   r14, rax
		neg   r14
	       call   ThreadPool_NodesSearched
		add   qword[UciLoop.time], r14
		add   qword[UciLoop.nodes], rax
		mov   r15, rax


		lea   rdi, [Output]
		mov   rax, r13
	       call   PrintUnsignedInteger
		mov   al, ':'
	      stosb

		lea   ecx, [rdi-Output]
		and   ecx, 7
		xor   ecx, 7
		mov   al, ' '
	  rep stosb

		mov   rax, 'nodes:  '
	      stosq
		mov   rax, r15
	       call   PrintUnsignedInteger
		lea   ecx, [rdi-Output-8]
		and   ecx, 15
		xor   ecx, 15
		add   ecx, 8
		mov   al, ' '
	  rep stosb

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
       PrintNewLine

	       call   _WriteOut_Output

		cmp   rsi, BenchFensEnd
		 jb   .nextpos

	       call   _SetNormalPriority


		lea   rdi, [Output]
		mov   al, '='
		mov   ecx, 27
	  rep stosb
       PrintNewLine

		mov   rax, 'Total ti'
	      stosq
		mov   rax, 'me (ms) '
	      stosq
		mov   ax, ': '
	      stosw
		mov   rax, qword[UciLoop.time]
	       call   PrintUnsignedInteger
       PrintNewLine

		mov   rax, 'Nodes se'
	      stosq
		mov   rax, 'arched  '
	      stosq
		mov   ax, ': '
	      stosw
		mov   rax, qword[UciLoop.nodes]
	       call   PrintUnsignedInteger
       PrintNewLine

		mov   rax, 'Nodes/se'
	      stosq
		mov   rax, 'cond    '
	      stosq
		mov   ax, ': '
	      stosw

		mov   rax, qword[UciLoop.nodes]
		mov   ecx, 1000
		mul   rcx
		mov   rcx, qword[UciLoop.time]
		cmp   rcx, 1
		adc   rcx, 0
		div   rcx
	       call   PrintUnsignedInteger
       PrintNewLine

	       call   _WriteOut_Output

		lea   rcx, [DisplayInfo_Uci]
		lea   rdx, [DisplayMove_Uci]
		mov   qword[options.displayInfoFxn], rcx
		mov   qword[options.displayMoveFxn], rdx


if PROFILE > 0
		lea   rdi, [Output]

		lea   r15, [profile.cjmpcounts]

.CountLoop:
		mov   rax, qword[r15+8*0]
		 or   rax, qword[r15+8*1]
		 jz   .CountDone

		lea   rax, [r15-profile.cjmpcounts]
		shr   eax, 4
	       call   PrintUnsignedInteger
		mov   al, ':'
	      stosb
		mov   al, 10
	      stosb

	     szcall   PrintString, '  jmp not taken: '
		mov   rax, qword[r15+8*0]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb

	     szcall   PrintString, '  jmp taken:     '
		mov   rax, qword[r15+8*1]
	       call   PrintUnsignedInteger
		mov   al, 10
	      stosb

	     szcall   PrintString, '  jmp percent:   '
	  vcvtsi2sd   xmm0, xmm0, qword[r15+8*0]
	  vcvtsi2sd   xmm1, xmm1, qword[r15+8*1]
	     vaddsd   xmm0, xmm0, xmm1
	     vdivsd   xmm1, xmm1, xmm0
		mov   eax, 10000
	  vcvtsi2sd   xmm2, xmm2, eax
	     vmulsd   xmm1, xmm1, xmm2
	  vcvtsd2si   eax, xmm1
		xor   edx, edx
		mov   ecx, 100
		div   ecx
		mov   r12d, edx
	       call   PrintUnsignedInteger
		mov   al, '.'
	      stosb
		mov   eax, r12d
		xor   edx, edx
		mov   ecx, 10
		div   ecx
		add   al, '0'
	      stosb
		lea   eax, [rdx+'0']
	      stosb
		mov   al, '%'
	      stosb
		mov   al, 10
	      stosb

		add   r15, 16
		jmp   .CountLoop

.CountDone:

		jmp   UciWriteOut
end if

		jmp   UciGetInput




if VERBOSE > 0

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
		mov   dword[rbx+sizeof.State+State.currentMove], MOVE_NULL
	       call   Move_DoNull
		mov   qword[rbp+Pos.state], rbx
	       call   SetCheckInfo
		jmp   UciShow


UciShow:
		lea   rdi, [Output]
		mov   rbx, qword[rbp+Pos.state]
	       call   Position_Print
		jmp   UciWriteOut

UciUndo:
		mov   rbx, qword[rbp+Pos.state]
	       call   SkipSpaces
	       call   ParseInteger
		sub   eax, 1
		adc   eax, 0
		mov   r15d, eax
.Undo:
		cmp   rbx, qword[rbp+Pos.stateTable]
		jbe   UciShow
		mov   ecx, dword[rbx+State.currentMove]
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

end if


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