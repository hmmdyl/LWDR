module rt.sections;

pragma(LDC_no_moduleinfo);

import rtoslink;

version(LWDR_TLS):

private {
	extern(C) {
		__gshared void* _tdata; /// TLS data (declared in linker script)
		__gshared void* _tdata_size; /// Size of TLS data
		__gshared void* _tbss; /// TLS BSS (declared in linker script)
		__gshared void* _tbss_size; /// Size of TLS BSS
	}

	/// Wrapper around TLS data defined by linker script
	pragma(LDC_no_typeinfo)
	{
	struct TlsLinkerParams
	{
		void* data;
		size_t dataSize;
		void* bss;
		size_t bssSize; 
		size_t fullSize;
	}
	}

	/// Get TLS data defined in linker script
	TlsLinkerParams getTlsLinkerParams() nothrow @nogc 
	{
		TlsLinkerParams param;
		param.data = cast(void*)&_tdata;
		param.dataSize = cast(size_t)&_tdata_size;
		param.bss = cast(void*)&_tbss;
		param.bssSize = cast(size_t)&_tbss_size;
		param.fullSize = param.dataSize + param.bssSize;
		return param;
	}

	/// TCB (Thread Control Block) size as defined by ARM EABI.
	enum ARM_EABI_TCB_SIZE = 8;
}

/// TLS support stores its pointer at index 1 in the TCB (Thread Control Block)
enum tlsPointerIndex = 1;

/// Initialise TLS memory for current thread
void[] initTLSRanges() nothrow @nogc
{
	TlsLinkerParams tls = getTlsLinkerParams;
	void* memory = rtosbackend_heapalloc(tls.fullSize);

	import core.stdc.string : memcpy, memset;

	memcpy(memory, tls.data, tls.dataSize);
	memset(memory + tls.dataSize, 0, tls.bssSize);

	rtosbackend_setTLSPointerCurrThread(memory, tlsPointerIndex);

	return memory[0 .. tls.fullSize];
}

/// Free TLS memory for current thread
void freeTLSRanges() nothrow @nogc
{
	auto memory = rtosbackend_getTLSPointerCurrThread(tlsPointerIndex);
	rtosbackend_heapfreealloc(memory);
}

/// Get pointer to TLS memory for current thread.
extern(C) void* __aeabi_read_tp() nothrow @nogc
{
	return rtosbackend_getTLSPointerCurrThread(tlsPointerIndex) - ARM_EABI_TCB_SIZE;
}