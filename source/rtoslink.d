module rtoslink;

pragma(LDC_no_moduleinfo);

/++
These are the basic hooks to be implemented in C/C++ land. LWDR will call
these hooks depending on what is requested of the runtime by user code.
++/

@disable ubyte[] internal_heapalloc(uint sz) pure @nogc nothrow {
	return cast(ubyte[])(rtosbackend_heapalloc(sz)[0..sz]);
}

@nogc nothrow pure extern(C) {
	/// Called when LWDR requests heap memory
	void* rtosbackend_heapalloc(uint sz);
	/// Called when LWDR wants to free heap memory
	void rtosbackend_heapfreealloc(void* ptr);

	/// Called when a D array is access incorrectly.
	void rtosbackend_arrayBoundFailure(string file, uint line);
	/// Called when assert(bool exp) fails.
	void rtosbackend_assert(string file, uint line);
	/// Called when assert(bool exp, string msg) fails.
	void rtosbackend_assertmsg(string msg, string file, uint line);

	/// Set pointer at index in the current thread's TCB (Thread Control Block)
	void rtosbackend_setTLSPointerCurrThread(void* ptr, int index);
	/// Get pointer at index in the current thread's TCB (Thread Control Block)
	void* rtosbackend_getTLSPointerCurrThread(int index);

	/// Called when LWDR cannot allocate
	void rtosbackend_outOfMemory();

	/// Called when LWDR wishes to terminate prematurely.
	void rtosbackend_terminate();

	version(LWDR_Sync)
	{
		/// Called when LWDR wants to create a mutex.
		void* rtosbackend_mutexInit();
		/// Called when LWDR wants to destroy a mutex.
		void rtosbackend_mutexDestroy(void*);
		/// LWDR wants to lock a mutex (eg, via synchronized).
		void rtosbackend_mutexLock(void*);
		/// LWDR wants to unlock a mutex (eg, via synchronized).
		void rtosbackend_mutexUnlock(void*);
		/// Attempt to lock a mutex. Returns 0 if couldn't, 1 if locked.
		int rtosbackend_mutexTryLock(void*);
		/// LWDR stores a single, global mutex for its own implementation. This function creates it. Called on runtime start.
		void* rtosbackend_globalMutexInit();
		/// Destroy LWDR's global mutex. Called on runtime shutdown.
		void rtosbackend_globalMutexDestroy(void*);
	}
}