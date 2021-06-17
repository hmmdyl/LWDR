module rt.sections;

import rtoslink;

version(LWDR_TLS):

private {
	extern(C) {
		__gshared void* _tdata;
		__gshared void* _tdata_size;
		__gshared void* _tbss;
		__gshared void* _tbss_size;
	}

	struct TlsLinkerParams
	{
		void* data;
		size_t dataSize;
		void* bss;
		size_t bssSize; 
		size_t fullSize;
	}

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

	enum ARM_EABI_TCB_SIZE = 8;
}

enum tlsPointerIndex = 1;

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

extern(C) void* __aeabi_read_tp() nothrow @nogc
{
	return rtosbackend_getTLSPointerCurrThread(tlsPointerIndex) - ARM_EABI_TCB_SIZE;
}