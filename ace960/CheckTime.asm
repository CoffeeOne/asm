CheckTime:
		cmp   byte[limits.ponder], 0
		jnz   .return

	       call   _GetTime
		sub   rax, qword[time.startTime]
		add   rax, 10
		cmp   byte[limits.useTimeMgmt], 0
		 je   @f
		cmp   rax, qword[time.maximumTime]
		 ja   .stop
	@@:
		cmp   byte[limits.movetime], 0
		 je   @f
		sub   rax, 10
		cmp   eax, dword[limits.movetime]
		 ja   .stop
	@@:
		cmp   byte[limits.nodes], 0
		 je   @f
	       call   ThreadPool_NodesSearched
		cmp   rax, qword[limits.nodes]
		 ja   .stop
	@@:
.return:
		ret

.stop:

	       push   rax
	    VerboseDisplay 'setting signals.stop in CheckTime'
		pop   rax

		mov   byte[signals.stop], -1
		ret