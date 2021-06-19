module rtoslink;

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
}