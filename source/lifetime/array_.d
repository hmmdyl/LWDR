module lifetime.array_;

import lifetime.common;

extern(C) void[] _d_newarrayU(const TypeInfo ti, size_t length) pure nothrow
{
	auto tinext = unqualify(ti);
	auto size = tinext.tsize;

	void* ptr = rtosbackend_heapalloc(size * length);
	zeroMem(ptr, size * length);
	return ptr[0 .. size * length];
}

extern(C) void[] _d_newarrayT(const TypeInfo ti, size_t length) pure nothrow
{
	return _d_newarrayU(ti, length);
}

/**
* For when the array has a non-zero initializer.
*/
extern (C) void[] _d_newarrayiT(const TypeInfo ti, size_t length) pure nothrow
{
    import core.internal.traits : AliasSeq;

    void[] result = _d_newarrayU(ti, length);
    auto tinext = unqualify(ti.next);
    auto size = tinext.tsize;

    auto init = tinext.initializer();

    switch (init.length)
    {
		foreach (T; AliasSeq!(ubyte, ushort, uint, ulong))
		{
			case T.sizeof:
				(cast(T*)result.ptr)[0 .. size * length / T.sizeof] = *cast(T*)init.ptr;
				return result;
		}

		default:
			{
				import core.stdc.string;
				immutable sz = init.length;
				for (size_t u = 0; u < size * length; u += sz)
					memcpy(result.ptr + u, init.ptr, sz);
				return result;
			}
    }
}

extern(C) void _d_array_slice_copy(void* dst, size_t dstlen, void* src, size_t srclen, size_t elemsz)
{
	auto d = cast(ubyte*) dst;
	auto s = cast(ubyte*) src;
	auto len = dstlen * elemsz;

	while(len) 
	{
		*d = *s;
		d++;
		s++;
		len--;
	}
}