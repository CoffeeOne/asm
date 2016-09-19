; Thanks to locklessinc.com and HaHaAnonymous for most of these functions



;;;;;;;;;
; mutex ;
;;;;;;;;;


LOCK_CONTEND	= 0x0101

_MutexCreate:
	; rcx: address of Mutex
	       push   rbx rsi rdi
		mov   rdi, rcx
		xor   eax, eax
		mov   dword[rdi], eax
		pop   rdi rsi rbx
		ret

_MutexDestroy:
	; rcx: address of Mutex
	       push   rbx rsi rdi
		mov   rdi, rcx
		xor   eax, eax
		pop   rdi rsi rbx
		ret

_MutexLock:
	; rcx: address of Mutex
	       push   rbx rsi rdi
		mov   rdi, rcx
		mov   ecx, 100
	; Spin a bit to try to get lock
.1:		mov   dl, 1
	       xchg   dl, byte[rdi]
	       test   dl, dl
		 jz   .4
	    rep nop
		sub   ecx, 1
		jnz   .1
	; Set up syscall details
		mov   edx, LOCK_CONTEND
		mov   esi, FUTEX_WAIT_PRIVATE
		xor   r10, r10
		jmp   .3
	; Wait loop
.2:		mov   eax, sys_futex
	    syscall
	   ; can this syscall fail in some cases?
	   ;  it has not been observed doing so
	   ;    test   eax, eax
	   ;      js   Failed_sys_futex_MutexLock
.3:		mov   eax, edx
	       xchg   eax, dword[rdi]
	       test   eax, 1
		jnz   .2
.4:		xor   eax, eax
		pop   rdi rsi rbx
		ret

_MutexUnlock:
	; rcx: address of Mutex
	       push   rbx rsi rdi
		mov   rdi, rcx
		cmp   dword[rdi], 1
		jne   .1
		mov   eax, 1
		xor   ecx, ecx
       lock cmpxchg   dword[rdi], ecx
		 jz   .3
.1:		mov   byte[rdi], 0
	; Spin, and hope someone takes the lock
		mov   ecx, 200
.2:	       test   byte[rdi], 1
		jnz   .3
	    rep nop
		sub   ecx, 1
		jnz   .2
	; Wake up someone
		mov   byte[rdi+1], 0
		mov   esi, FUTEX_WAKE_PRIVATE
		mov   edx, 1
		mov   eax, sys_futex
	    syscall
	       test   eax, eax
		 js   Failed_sys_futex_MutexUnlock

.3:		xor   eax, eax
		pop   rdi rsi rbx
		ret



;;;;;;;;;
; event ;
;;;;;;;;;


_EventCreate:
	; rcx: address of ConditionalVariable
_EventDestroy:
	; rcx: address of ConditionalVariable
		xor   eax, eax
		mov   qword[rcx], rax
		mov   qword[rcx+8], rax
		ret

_EventSignal:
	; rcx: address of ConditionalVariable
	       push   rbx rsi rdi
		mov   rdi, rcx
	   lock add   dword[rdi], 1
		mov   eax, sys_futex
		mov   esi, FUTEX_WAKE_PRIVATE
		mov   edx, 1
	    syscall
	       test   eax, eax
		 js   Failed_sys_futex_EventSignal
		xor   eax, eax
		pop   rdi rsi rbx
		ret

_EventWait:
	; rcx: address of ConditionalVariable
	; rdx: address of Mutex
	       push   rbx rsi rdi r14 r15
		mov   rdi, rcx
		mov   rsi, rdx
		cmp   rsi, qword[rdi+8]
		jne   .4
	; save seq into r14d
.1:		mov   r14d, dword[rdi]
	; save mutex into r15
		mov   r15, rsi
	; Unlock
		mov   rbx, rdi
		mov   rcx, rsi
	       call   _MutexUnlock
		mov   rdi, rbx
	; Setup for wait on seq
		mov   edx, r14d
		xor   r10, r10
		mov   esi, FUTEX_WAIT_PRIVATE
		mov   eax, sys_futex
	    syscall
	   ; this syscall can and should fail in some cases
	   ;    test   eax, eax
	   ;      js   Failed_sys_futex_EventWait
	; Set up for wait on mutex
		mov   rdi, r15
		mov   edx, LOCK_CONTEND
		jmp   .3
	; Wait loop
.2:		mov   eax, sys_futex
	    syscall
	   ; this syscall can and should fail in some cases
	   ;    test   eax, eax
	   ;      js   Failed_sys_futex_EventWait
.3:		mov   eax, edx
	       xchg   eax, dword[rdi]
	       test   eax, 1
		jnz   .2
		xor   eax, eax
		pop   r15 r14 rdi rsi rbx
		ret
	
.4:		xor   rax, rax
       lock cmpxchg   qword[rdi+8], rsi
		 jz   .1
		cmp   qword[rdi+8], rsi
		 je   .1
.5:
		jmp   Failed_EventWait



;;;;;;;;
; file ;
;;;;;;;;

_FileWrite:
	; in: rcx handle from CreateFile (win), fd (linux)
	;     rdx buffer
	;     r8d size (32bits)
	; out: eax !=0 success
	       push   rsi rdi rbx
		mov   rdi, rcx	; fd
		mov   rsi, rdx	; buffer
		mov   edx, r8d	; count
		mov   eax, sys_write
	    syscall
		sar   rax, 63
		add   eax, 1
		pop   rbx rdi rsi
		ret

_FileRead:
	; in: rcx handle from CreateFile (win), fd (linux)
	;     rdx buffer
	;     r8d size (32bits)
	; out: eax !=0 success
	       push   rsi rdi rbx
		mov   rdi, rcx	; fd
		mov   rsi, rdx	; buffer
		mov   edx, r8d	; count
		mov   eax, sys_read
	    syscall
		sar   rax, 63
		add   eax, 1
		pop   rbx rdi rsi
		ret


_FileSize:
	; in: rcx handle from CreateFile (win), fd (linux)
	; out:  rax size
	       push   rbx rsi rdi
		sub   rsp, 20*8
		mov   rdi, rcx
		mov   rsi, rsp 
		mov   eax, sys_fstat 
	    syscall
	       test   eax, eax
		jnz   Failed_sys_fstat
		mov   rax, qword[rsp+0x30] ; file size
		add   rsp, 20*8
		pop   rdi rsi rbx
		ret


_FileOpenWrite:
	; in: rcx path string
	; out: rax handle from CreateFile (win), fd (linux)
	;      rax=-1 on error
	       push   rbx rsi rdi
		mov   rdi, rcx
		mov   esi, O_WRONLY or O_CREAT
		mov   eax, sys_open
	    syscall
	       test   eax, eax
		jns   @f
		 or   rax, -1
	@@:	pop   rdi rsi rbx
		ret


_FileOpenRead:
	; in: rcx path string  
	; out: rax handle from CreateFile (win), fd (linux)
	;      rax=-1 on error
	       push   rbx rsi rdi
		mov   rdi, rcx
		mov   esi, O_RDONLY
		mov   eax, sys_open
	    syscall
	       test   eax, eax
		jns   @f
		 or   rax, -1
	@@:	pop   rdi rsi rbx
		ret

_FileClose:
	; in: rcx handle from CreateFile (win), fd (linux) 
	       push   rbx rsi rdi 
		mov   rdi, rcx 
		mov   eax, sys_close 
	    syscall 
		pop   rdi rsi rbx 
		ret

_FileMap:
	; in: rcx handle (win), fd (linux) 
	; out: rax base address 
	;      rdx handle from CreateFileMapping (win), size (linux) 
	; get file size 
	       push   rbp rbx rsi rdi r15
		sub   rsp, 20*8
		mov   rbp, rcx
		mov   rdi, rcx
		mov   rsi, rsp 
		mov   eax, sys_fstat 
	    syscall
	       test   eax, eax
		jnz   Failed_sys_fstat
		mov   rbx, qword[rsp+0x30] ; file size
	; map file
		xor   edi, edi		; addr
		mov   rsi, rbx		; length
		mov   edx, PROT_READ	; protection flags
		mov   r10, MAP_PRIVATE	; mapping flags
		mov   r8, rbp		; fd
		xor   r9d, r9d		; offset
		mov   eax, sys_mmap
	    syscall
	       test   rax, rax
		 js   Failed_sys_mmap
	; return size in rdx, base address in rax
		mov   rdx, rbx
		add   rsp, 20*8
		pop   r15 rdi rsi rbx rbp
		ret

_FileUnmap:
	; in: rcx base address 
	;     rdx handle from CreateFileMapping (win), size (linux) 
	       push   rbx rsi rdi
	       test   rcx, rcx
		 jz   @f
		mov   rdi, rcx	      ; addr 
		mov   rsi, rdx	      ; length 
		mov   eax, sys_munmap 
	    syscall
	       test   eax, eax
		jnz   Failed_sys_munmap_FileUnmap
	@@:	pop   rdi rsi rbx
		ret




;;;;;;;;;;
; thread ;
;;;;;;;;;;

_ThreadCreate:
	; in: rcx start address
	;     rdx parameter to pass
	;     r8  address of NumaNode struct
	;     r9  address of ThreadHandle Struct
	       push   rbx rsi rdi r12 r13 r14 r15
		mov   r12, r8
		mov   r13, r9
		mov   r14, rcx
		mov   r15, rdx
	; allocate memory for the thread stack
		mov   ecx, THREAD_STACK_SIZE
		mov   edx, dword[r12+NumaNode.nodeNumber]
	       call   _VirtualAllocNuma_GrowsDown
		mov   qword[r13+ThreadHandle.stackAddress], rax
		mov   rsi, rax
	; create child
		mov   edi, CLONE_VM or CLONE_FS or CLONE_FILES\
			or CLONE_SIGHAND or CLONE_THREAD	; flags
		add   rsi, THREAD_STACK_SIZE			; child_stack
		xor   edx, edx					; ptid
		xor   r10, r10					; ctid
		xor   r8, r8					; regs
		mov   eax, stub_clone
	    syscall
	       test   eax, eax
		 js   Failed_stub_clone
	; redirect child to function
	       test   eax, eax
		 jz   .WeAreChild
		pop   r15 r14 r13 r12 rdi rsi rbx
		ret
.WeAreChild:
		xor   edi, edi
		mov   esi, MAX_LINUXCPUS/8
		lea   rdx, [r12+NumaNode.cpuMask]
		xor   eax, eax
	repeat MAX_LINUXCPUS/64
		 or   rax, qword[rdx+8*(%-1)]
	end repeat
		 jz   .DontSetAffinity
		mov   eax, sys_sched_setaffinity
	    syscall
	       test   eax, eax
		jnz   Failed_sys_sched_setaffinity
.DontSetAffinity:

		mov   rcx, r15
	       call   r14
	; signal that we are done
		lea   rdi, [r13+ThreadHandle.mutex]
		mov   esi, FUTEX_WAKE_PRIVATE
		mov   edx, 1
		mov   dword[rdi], edx
		mov   eax, sys_futex
	    syscall
	       test   eax, eax			      ; existed before
		 js   Failed_sys_futex_ThreadCreate   ;
	; exit
		xor   edi, edi
		mov   eax, sys_exit
	    syscall
	       int3

_ThreadJoin:
	; rcx:  address of ThreadHandle struct
	       push   rbx rsi rdi
		mov   rbx, rcx

	; wait for the thread to return
		lea   rdi, [rbx+ThreadHandle.mutex]
		mov   esi, FUTEX_WAIT_PRIVATE
		xor   edx, edx
		xor   r10d, r10d
		mov   eax, sys_futex
	    syscall
	   ; this syscall can and should fail in some cases
	   ;    test   eax, eax                        ; existed before
	   ;      js   Failed_sys_futex_ThreadJoin     ;

	; free its stack
		mov   rdi, qword[rbx+ThreadHandle.stackAddress]
		mov   rsi, THREAD_STACK_SIZE
		mov   eax, sys_munmap
	    syscall
	       test   eax, eax
		jnz   Failed_sys_munmap_ThreadJoin
		pop   rdi rsi rbx
		ret

_ExitProcess:
	; rcx is exit code
	       push   rdi
		mov   rdi, rcx
		mov   eax, sys_exit_group
	    syscall


_ExitThread:
	; rcx is exit code
	; must not call _ExitThread on linux
	;  thread should just return
	       int3


;;;;;;;;;;
; timing ;
;;;;;;;;;;

_GetTime:
	; out: rax + rdx/2^64 = time in ms
	       push   rbx rsi rdi
		sub   rsp, 8*2
		mov   edi, CLOCK_MONOTONIC
		mov   rsi, rsp
		mov   eax, sys_clock_gettime
	    syscall				; todo: change to a faster vdso call  ?how?
		mov   eax, dword[rsp+8*1]	; tv_nsec
		mov   rcx, 18446744073709;551616   2^64/10^6
		mul   rcx
	       imul   rcx, qword[rsp+8*0], 1000
		add   rdx, rcx
	       xchg   rax, rdx
		add   rsp, 8*2
		pop   rdi rsi rbx
		ret

_SetFrequency:
	; no arguments
		ret

_Sleep:
	; ecx  ms
	       push   rbx rsi rdi
		sub   rsp, 8*2
		mov   eax, ecx
		xor   edx, edx
		mov   ecx, 1000
		div   ecx
	       imul   edx, 1000
		mov   qword[rsp+8*0], rax
		mov   qword[rsp+8*1], rdx
		mov   rdi, rsp
		xor   esi, esi
		mov   eax, sys_nanosleep
	    syscall
		add   rsp, 8*2
		pop   rdi rsi rbx
		ret


;;;;;;;;;;
; memory ;
;;;;;;;;;;


_VirtualAllocNuma_GrowsDown:	 ; this is called to allocate stack on created thread
	; rcx is size
	; edx is numa node
		mov   r10d, MAP_PRIVATE or MAP_ANONYMOUS or MAP_GROWSDOWN
		jmp   _VirtualAllocNuma.go

_VirtualAllocNuma:
	; rcx is size
	; edx is numa node
		mov   r10d, MAP_PRIVATE or MAP_ANONYMOUS
.go:
		cmp   edx, -1
		 je   _VirtualAlloc.go
	       push   rbp rbx rsi rdi r15
		sub   rsp, 16
		mov   ebx, edx
		mov   rbp, rcx
		xor   edi, edi
		mov   rsi, rcx
		mov   edx, PROT_READ or PROT_WRITE
		 or   r8, -1
		xor   r9, r9
		mov   eax, sys_mmap
	    syscall
		mov   r15, rax
	       test   rax, rax
		 js   Failed_sys_mmap

		mov   rdi, r15		; addr
		mov   rsi, rbp		; len
		mov   edx, MPOL_BIND	; mode
		xor   eax, eax
		bts   rax, rbx
		mov   qword[rsp], rax
		mov   r10, rsp		; nodemask
		mov   r8d, 32		; maxnode
		xor   r9, r9		; flags
		mov   eax, sys_mbind
	    syscall
	       test   eax, eax
		jnz   Failed_sys_mbind

		mov   rax, r15
		add   rsp, 16
		pop   r15 rdi rsi rbx rbp
		ret


_VirtualAlloc:
	; rcx is size
		mov   r10d, MAP_PRIVATE or MAP_ANONYMOUS
.go:
	       push   rsi rdi rbx
		xor   edi, edi
		mov   rsi, rcx
		mov   edx, PROT_READ or PROT_WRITE
		 or   r8, -1
		xor   r9, r9
		mov   eax, sys_mmap
	    syscall
	       test   rax, rax
		 js   Failed_sys_mmap
		pop   rbx rdi rsi
		ret


_VirtualFree:
	; rcx is address
	; rdx is size
	       push   rsi rdi rbx
	       test   rcx, rcx
		 jz   @f
		mov   rdi, rcx
		mov   rsi, rdx
		mov   eax, sys_munmap
	    syscall
	       test   eax, eax
		jnz   Failed_sys_munmap_VirtualFree
	@@:	pop   rbx rdi rsi
		ret



_VirtualAlloc_LargePages:
	; rcx is size
	;  if this fails, we want to return 0
	;  so that _VirtualAlloc can be called
	;
	;  global var LargePageMinSize could be
	;    <0 : tried to use large pages and failed
	;    =0 : haven't tried to use larges yet
	;    >0 : succesfully used large pages
	;
	; out:
	;  rax address of base
	;  rdx size allocated
	;        should be multiple of qword[LargePageMinSize]

		xor   eax, eax
		xor   edx, edx
		ret






;;;;;;;;;;;;;;;;
; input/output ;
;;;;;;;;;;;;;;;;

_GetCommandLine:
	; out: rax address of string

	; we are supposed to return the command line string
	;  for now, just return junk that won't break the command line processor
	       lea   rax, [@f]
	       ret
	@@: db ' ',0

_SetStdHandles:
	; no arguments
	; these are always 0,1,2
		ret


_WriteOut_Output:
		lea   rcx, [Output]
_WriteOut:
	; in: rcx  address of string start
	;     rdi  address of string end
	       push   rsi rdi rbx
		mov   rsi, rcx
		mov   rdx, rdi
		sub   rdx, rcx
		mov   edi, 1
.go:
		mov   eax, sys_write
	    syscall
	       test   rax, rax
		 js   Failed_sys_write
		pop   rbx rdi rsi
		ret


_WriteError:
	; in: rcx  address of string start
	;     rdi  address of string end
	       push   rsi rdi rbx
		mov   rsi, rcx
		mov   rdx, rdi
		sub   rdx, rcx
		mov   edi, 2
		jmp   _WriteOut.go



_ReadIn:
	; out: eax =  0 if not file end 
	;      eax = -1 if file end 
	;      rsi address of string start 
	;      ecx length of string
	; 
	; uses global InputBuffer and InputBufferSizeB 
	; reads one line and then returns 
	; a line is a string of characters where the last
	;  and only the last character is below 0x20 (the space char)
	       push   rdi rbx r13 r14 r15
		xor   ebx, ebx				; ebx = length of return string
		mov   r15, qword[InputBuffer]		; r15 = buffer
		mov   r14, qword[InputBufferSizeB]	; r14 = size
.ReadLoop:
		cmp   rbx, r14
		jae   .ReAlloc
.ReAllocRet:
		mov   edi, stdin
		lea   rsi, [r15+rbx]
		mov   edx, 1
		mov   eax, sys_read 
	    syscall
	; check for file end 
		cmp   rax, 1
		 jl  .FileEnd
	; check for new line
		add   ebx, 1
		cmp   byte[rsi], ' '
		jae   .ReadLoop

		xor   eax, eax
.Return:
		mov   rsi, r15
		mov   ecx, ebx
		pop   r15 r14 r13 rbx rdi
		ret
.FileEnd:
		 or   eax, -1
		jmp  .Return
.ReAlloc:
	; get new buffer
		lea   rcx, [r14+4096]
	       call   _VirtualAlloc
		mov   r13, rax
		mov   rdi, rax
	; copy data
		mov   rsi, r15
		mov   rcx, r14
	  rep movsb
	; free old buffer
		mov   rcx, r15
		mov   rdx, r14
	       call   _VirtualFree
	; set new data
		mov   r15, r13
		add   r14, 4096
		mov   qword[InputBuffer], r13
		mov   qword[InputBufferSizeB], r14
		jmp   .ReAllocRet


;;;;;;;;;;;;;;;;;;
; priority class ;
;;;;;;;;;;;;;;;;;;

_SetPriority_Realtime:
	; must be root to set "higher" priority, normal user can only lower priority 
		mov   edx, -15		   ; priority
	@@:    push   rsi rdi rbx
		mov   edi, PRIO_PROCESS    ; which 
		xor   esi, esi		   ; who
		mov   eax, sys_setpriority
	    syscall 
		pop   rbx rdi rsi 
		ret

_SetPriority_Normal:
		xor   edx, edx
		jmp   @b

_SetPriority_Low:
		mov   edx, 10
		jmp   @b

_SetPriority_Idle:
		mov   edx, 19
		jmp   @b




;;;;;;;;;;;;;;;;;;;;;;;
; system capabilities ;
;;;;;;;;;;;;;;;;;;;;;;;


_SetThreadPoolInfo:
	; see ThreadPool.asm for what this is supposed to do

	       push   rbx rsi rdi r12 r13 r14 r15
virtual at rsp
	   rq 1
 .Affinity rq 1
 .buffer   rb 512
 .fstat    rq 24
 .fstring  rb 96
 .lend	   rb 0
end virtual
.localsize = ((.lend-rsp+15) and (-16))

	 _chkstk_ms   rsp, .localsize
		sub   rsp, .localsize

		mov   qword[.Affinity], rcx
		xor   eax, eax
		mov   dword[threadPool.nodeCnt], eax
		mov   dword[threadPool.coreCnt], eax


	; read node data
	;  suppose that node0 has cpu0-cpu3 and cpu8-cpu11
	;  then /sys/devices/system/node/node0/cpumap
	;   contains "f0f\n"

		lea   rbx, [threadPool.nodeTable]
		 or   r12d, -1
	;  r12d = N

.TryNextNode:
		add   r12d, 1
		cmp   r12d, MAX_NUMANODES
		jae   .TryNodesDone

		mov   ecx, r12d
		 or   edx, -1
		mov   r8, qword[.Affinity]
	       call   QueryNodeAffinity
	       test   eax, eax
		 jz   .TryNextNode


	; look at /sys/devices/system/node/nodeN/cpumap
		lea   rdi, [.fstring]
		mov   rax, '/sys/dev'
	      stosq
		mov   rax, 'ices/sys'
	      stosq
		mov   rax, 'tem/node'
	      stosq
		mov   rax, '/node'
	      stosq
		sub   rdi, 3
		mov   eax, r12d
	       call   PrintUnsignedInteger
		mov   rax, '/cpumap'
	      stosq
		xor   eax, eax
	      stosd

		lea   rcx, [.fstring]
	       call   _FileOpenRead
		mov   r15, rax
		cmp   rax, -1
		 je   .TryNextNode
		mov   rdi, r15
		lea   rsi, [.buffer]
		mov   edx, 50+MAX_LINUXCPUS ; hacky
		mov   eax, sys_read 
	    syscall
		mov   rsi, rax
		mov   rcx, r15
	       call   _FileClose
		cmp   rsi, 1
		 jb   .TryNextNode

	; at this point, N is a valid node number
		xor   edx, edx
		mov   dword[rbx+NumaNode.nodeNumber], r12d
		mov   dword[rbx+NumaNode.coreCnt], edx	; will increment later
		mov   qword[rbx+NumaNode.cmhTable], rdx ; initialize to NULL, will allocate as needed
		mov   qword[rbx+NumaNode.parent], rbx	; initialize to self

	repeat MAX_LINUXCPUS/64
		mov   qword[rbx+NumaNode.cpuMask+8*(%-1)], rdx
	end repeat

.ReadNextB:
		cmp   edx, MAX_LINUXCPUS
		jae   .ReadDone
		sub   esi, 1
		 js   .ReadDone
	      movzx   ecx, byte[.buffer+rsi]
		sub   ecx, '0'
		 js   .ReadNextB
		cmp   ecx, 10
		 jb   .ReadOk
		sub   ecx, 'a'-'0'
		 js   .ReadNextB
		cmp   ecx, 'f'+1
		jae   .ReadNextB
		add   ecx, 10
.ReadOk:
	; each ascii char 0-9, a-f encodes 4 bits
      irps i, 1 2 4 8 {
	       test   ecx, i
		 jz   @f
		bts   [rbx+NumaNode.cpuMask], rdx
	  @@:	add   edx, 1
      }
		jmp   .ReadNextB
.ReadDone:
		add   rbx, sizeof.NumaNode
		add   dword[threadPool.nodeCnt], 1
		jmp   .TryNextNode
.TryNodesDone:


	; if we didn't find any nodes, assume that numa is not present
		mov   ebx, dword[threadPool.nodeCnt]
	       test   ebx, ebx
		 jz   .Absent


	; assign parents
		xor   r15d, r15d
    .Outer:    imul   esi, r15d, sizeof.NumaNode
		lea   rsi, [rsi+threadPool.nodeTable]
		xor   r14d, r14d
      .Inner:  imul   edi, r14d, sizeof.NumaNode
		lea   rdi, [rdi+threadPool.nodeTable]
		mov   ecx, dword[rsi+NumaNode.nodeNumber]
		mov   edx, dword[rdi+NumaNode.nodeNumber]
		mov   r8, qword[.Affinity]
	       call   QueryNodeAffinity
	       test   eax, eax
		 jz   .InnerNext
		mov   qword[rsi+NumaNode.parent], rdi
		jmp   .OuterNext
.InnerNext:	add   r14d, 1
		cmp   r14d, dword[threadPool.nodeCnt]
		 jb   .Inner
.OuterNext:	add   r15d, 1
		cmp   r15d, dword[threadPool.nodeCnt]
		 jb   .Outer


	; read core data
	;  suppose that cpu0 and cpu4 share the same core
	;  then both /sys/devices/system/cpu/cpu0/topology/thread_siblings
	;        and /sys/devices/system/cpu/cpu4/topology/thread_siblings
	;   contain "11\n"


		 or   r12d, -1
	;  r12d = N
.TryNextCore:
		add   r12d, 1
		cmp   r12d, MAX_LINUXCPUS
		jae   .TryCoresDone

	; look at /sys/devices/system/cpu/cpu0/topology/thread_siblings
		lea   rdi, [.fstring]
		mov   rax, '/sys/dev'
	      stosq
		mov   rax, 'ices/sys'
	      stosq
		mov   rax, 'tem/cpu/'
	      stosq
		mov   rax, 'cpu'
	      stosd
		sub   rdi, 1
		mov   eax, r12d
	       call   PrintUnsignedInteger
		mov   rax, '/topolog'
	      stosq
		mov   rax, 'y/thread'
	      stosq
		mov   rax, '_sibling'
	      stosq
		mov   eax, 's'
	      stosd

		lea   rcx, [.fstring]
	       call   _FileOpenRead
		mov   r15, rax
		cmp   rax, -1
		 je   .TryNextCore
		mov   rdi, r15
		lea   rsi, [.buffer]
		mov   edx, 50+MAX_LINUXCPUS ; hacky
		mov   eax, sys_read 
	    syscall
		mov   rsi, rax
		mov   rcx, r15
	       call   _FileClose
		cmp   rsi, 1
		 jb   .TryNextCore

		xor   edx, edx
	; get the lsb of bit set
.ReadNextB2:
		cmp   edx, MAX_LINUXCPUS
		jae   .TryNextCore
		sub   esi, 1
		 js   .TryNextCore
	      movzx   ecx, byte[.buffer+rsi]
		sub   ecx, '0'
		 js   .ReadNextB2
		cmp   ecx, 10
		 jb   .ReadOk2
		sub   ecx, 'a'-'0'
		 js   .ReadNextB2
		cmp   ecx, 'f'+1
		jae   .ReadNextB2
		add   ecx, 10
.ReadOk2:
	       test   ecx, ecx
		jnz   .found
		add   edx, 4
		jmp   .ReadNextB2
.found:
		bsf   ecx, ecx
		add   edx, ecx

	; edx is now lsb of this thread_siblings
	; loop through nodes and add up cores
		lea   rsi, [threadPool.nodeTable]
	       imul   ebx, dword[threadPool.nodeCnt], sizeof.NumaNode
		add   rbx, rsi
.CoreCountNextNode:
		xor   eax, eax
		 bt   [rsi+NumaNode.cpuMask], rdx
		adc   eax, eax
		add   dword[rsi+NumaNode.coreCnt], eax
		add   dword[threadPool.coreCnt], eax
		add   rsi, sizeof.NumaNode
		cmp   rsi, rbx
		 jb   .CoreCountNextNode

		jmp   .TryNextCore
.TryCoresDone:

	; if coreCnt=0, go to numa unaware state
		mov   eax, dword[threadPool.coreCnt]
	       test   eax, eax
		 jz   .Absent

.Return:
		add   rsp, .localsize
		pop   r15 r14 r13 r12 rdi rsi rbx
		ret

.Absent:
		mov   ecx, 1
		mov   dword[threadPool.nodeCnt], ecx
		mov   dword[threadPool.coreCnt], ecx

		xor   eax, eax

		lea   rdi, [threadPool.nodeTable]
		mov   dword[rdi+NumaNode.nodeNumber], -1
		mov   dword[rdi+NumaNode.coreCnt], ecx
		mov   qword[rdi+NumaNode.cmhTable], rax
		mov   qword[rdi+NumaNode.parent], rdi
	repeat MAX_LINUXCPUS/64
		mov   qword[rdi+NumaNode.cpuMask+8*(%-1)], rax
	end repeat

		jmp   .Return





_DisplayThreadPoolInfo:
	       push   rbx rsi rdi r14 r15
		lea   rsi, [threadPool.nodeTable]
	       imul   ebx, dword[threadPool.nodeCnt], sizeof.NumaNode
		add   rbx, rsi
.PrintNextNode:
		lea   rdi, [Output]
		mov   rax, 'info str'
	      stosq
		mov   rax, 'ing node'
	      stosq
		mov   al, ' '
	      stosb
	     movsxd   rax, dword[rsi+NumaNode.nodeNumber]
	       call   PrintSignedInteger
		mov   rax, ' parent '
	      stosq
		mov   rax, qword[rsi+NumaNode.parent]
	     movsxd   rax, dword[rax+NumaNode.nodeNumber]
	       call   PrintSignedInteger
		mov   rax, ' cores '
	      stosq
		sub   rdi, 1
		mov   eax, dword[rsi+NumaNode.coreCnt]
	       call   PrintUnsignedInteger
		mov   rax, ' mask 0x'
	      stosq
		mov   r15d, (MAX_LINUXCPUS/64)-1
	@@:	mov   rcx, qword[rsi+NumaNode.cpuMask+8*r15]
	       test   rcx, rcx
		jnz   .PrintMaskLoop
		sub   r15d, 1
		jnz   @b
	.PrintMaskLoop:
		mov   rcx, qword[rsi+NumaNode.cpuMask+8*r15]
	       call   PrintHex
	       test   r15d, r15d
		 jz   @f
		mov   al, '_'
	      stosb
	@@:	sub   r15d, 1
		jns   .PrintMaskLoop
       PrintNewLine
	       call   _WriteOut_Output
		add   rsi, sizeof.NumaNode
		cmp   rsi, rbx
		 jb   .PrintNextNode
.Return:
		pop  r15 r14 rdi rsi rbx
		ret




_CheckCPU:
	       push   rbp rbx r15

match =1, CPU_HAS_POPCNT {
		lea   r15, [szCPUError.POPCNT]
		mov   eax, 1
		xor   ecx, ecx
	      cpuid
		and   ecx, (1 shl 23)
		cmp   ecx, (1 shl 23)
		jne   .Failed
}

match =1, CPU_HAS_AVX1 {
		lea   r15, [szCPUError.AVX1]
		mov   eax, 1
		xor   ecx, ecx
	      cpuid
		and   ecx, (1 shl 27) + (1 shl 28)
		cmp   ecx, (1 shl 27) + (1 shl 28)
		jne   .Failed
		mov   ecx, 0
	     xgetbv
		and   eax, (1 shl 1) + (1 shl 2)
		cmp   eax, (1 shl 1) + (1 shl 2)
		jne   .Failed
}

match =1, CPU_HAS_AVX2 {
		lea   r15, [szCPUError.AVX2]
		mov   eax, 7
		xor   ecx, ecx
	      cpuid
		and   ebx, (1 shl 5)
		cmp   ebx, (1 shl 5)
		jne   .Failed
}

match =1, CPU_HAS_BMI1 {
		lea   r15, [szCPUError.BMI1]
		mov   eax, 7
		xor   ecx, ecx
	      cpuid
		and   ebx, (1 shl 3)
		cmp   ebx, (1 shl 3)
		jne   .Failed
}

match =1, CPU_HAS_BMI2 {
		lea   r15, [szCPUError.BMI2]
		mov   eax, 7
		xor   ecx, ecx
	      cpuid
		and   ebx, (1 shl 8)
		cmp   ebx, (1 shl 8)
		jne   .Failed
}

		pop  r15 rbx rbp
		ret

.Failed:
		lea   rdi, [Output]
		lea   rcx, [szCPUError]
	       call   PrintString
		mov   rcx, r15
	       call   PrintString
		xor   eax, eax
	      stosd
		lea   rdi, [Output]
		jmp   Failed


;;;;;;;;;
; fails ;
;;;;;;;;;

Failed:
	; rdi : null terminated string
	       push   rax
		mov   rcx, rdi
		lea   rdi, [Output]
	       call   PrintString
		mov   rax, ' rax: 0x'
	      stosq
		pop   rcx
	       call   PrintHex
		xor   eax, eax
	      stosb
		lea   rdi, [Output]
	       call   _ErrorBox
		mov   ecx, 1
	       call   _ExitProcess


Failed_HashmaxTooLow:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'HSHMAX too low!',0
Failed_sys_write:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_write failed',0
Failed_sys_mmap:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_mmap failed',0
Failed_sys_fstat:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_fstat failed',0



Failed_sys_munmap_VirtualFree:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_munmap in _VirtualFree failed',0
Failed_sys_munmap_ThreadJoin:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_munmap in _ThreadJoin failed',0
Failed_sys_munmap_FileUnmap:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_munmap in _FileUnmap failed',0


Failed_sys_munmap:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_munmap failed',0
Failed_stub_clone:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'stub_clone failed',0

Failed_sys_futex:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_futex failed',0
Failed_sys_futex_MutexUnlock:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_futex in _MutexUnlock failed',0
Failed_sys_futex_EventSignal:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_futex in _EventSignal failed',0
;Failed_sys_futex_EventWait:
;                lea   rdi, [@f]
;                jmp   Failed
;                @@: db 'sys_futex in _EventWait failed',0
Failed_sys_futex_ThreadCreate:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_futex in _ThreadCreate failed',0
;Failed_sys_futex_ThreadJoin:
;                lea   rdi, [@f]
;                jmp   Failed
;                @@: db 'sys_futex in _ThreadJoin failed',0
;Failed_sys_futex_MutexLock:
;                lea   rdi, [@f]
;                jmp   Failed
;                @@: db 'sys_futex in _MutexLock failed',0




Failed_sys_sched_setaffinity:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_sched_setaffinity failed',0
Failed_sys_mbind:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'sys_mbind failed',0
Failed_EventWait:
		lea   rdi, [@f]
		jmp   Failed
		@@: db '_EventWait failed',0
Failed_MatchingCore:
		lea   rdi, [@f]
		jmp   Failed
		@@: db 'matching core to node failed',0





_ErrorBox:
	; rdi points to null terminated string to write to message box 
	; this may be called from a leaf with no stack allignment 
	; one purpose is a hard exit on failure
		mov   rcx, rdi
	       call   strlen
	       push   rdi rsi rbx 
		mov   rsi, rdi 
		mov   edi, stderr 
		mov   rdx, rax 
		mov   eax, sys_write 
	    syscall
		lea   rsi, [sz_NewLine]
		mov   edi, stderr 
		mov   rdx, 1
		mov   eax, sys_write 
	    syscall
		pop   rbx rsi rdi 
		ret
