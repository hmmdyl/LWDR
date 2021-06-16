module lwdr.tracking;

import rtoslink;

void* lwdrInternal_alloc(size_t sz) nothrow @nogc pure
{
	return rtosbackend_heapalloc(sz);
}

void lwdrInternal_free(void* ptr) nothrow @nogc pure
{
	return rtosbackend_heapfreealloc(ptr);
}

ubyte[] lwdrInternal_allocBytes(size_t sz) nothrow pure @nogc
{
	return cast(ubyte[])lwdrInternal_alloc(sz)[0..sz];
}