module rtoslink;

extern(C) void* rtosbackend_heapalloc(uint sz);
extern(C) void rtosbackend_heapfreealloc(void* ptr);

extern(C) void rtosbackend_arrayBoundFailure(string file, uint line);
extern(C) void rtosbackend_assert(string file, uint line);
extern(C) void rtosbackend_assertmsg(string msg, string file, uint line);

ubyte[] internal_heapalloc(uint sz) {
	return cast(ubyte[])(rtosbackend_heapalloc(sz)[0..sz]);
}