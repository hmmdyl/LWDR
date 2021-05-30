module rtoslink;

@nogc nothrow:

extern(C) void* rtosbackend_heapalloc(uint sz) nothrow pure;
extern(C) void rtosbackend_heapfreealloc(void* ptr) nothrow pure;

extern(C) void rtosbackend_arrayBoundFailure(string file, uint line) nothrow pure;
extern(C) void rtosbackend_assert(string file, uint line) nothrow pure;
extern(C) void rtosbackend_assertmsg(string msg, string file, uint line) nothrow pure;

extern(C) void rotsbackend_terminate();

ubyte[] internal_heapalloc(uint sz) pure {
	return cast(ubyte[])(rtosbackend_heapalloc(sz)[0..sz]);
}