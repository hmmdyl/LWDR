module lifetime.array_;

import lifetime.common;

extern(C) void[] _d_newarrayU(const TypeInfo ti, size_t length) pure nothrow
{
	auto tinext = unqualify(ti.next);
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

void finalize_array(void* p, size_t size, const TypeInfo_Struct si)
{
    // Due to the fact that the delete operator calls destructors
    // for arrays from the last element to the first, we maintain
    // compatibility here by doing the same.
    auto tsize = si.tsize;
    for (auto curP = p + size - tsize; curP >= p; curP -= tsize)
    {
        // call destructor
        si.dtor(curP);
    }
}

extern(C) void _d_delarray_t(void[]* p, const TypeInfo_Struct ti) 
{
	if(!p) return;

	if(ti) // ti non-null only if ti is a struct with dtor
	{
		finalize_array(p.ptr, p.length * ti.tsize, ti);
	}

	rtosbackend_heapfreealloc((*p).ptr);
	*p = null;
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

extern(C) byte[] _d_arrayappendcTX(const TypeInfo ti, return scope ref byte[] px, size_t n)
{
	auto tinext = unqualify(ti.next);
	auto elemSize = tinext.tsize;

	auto length = px.length;
	auto size = length * elemSize;
	auto newLength = length + n;
	auto newSize = newLength * elemSize;

	auto newArray = _d_newarrayU(ti, newLength);

	import core.stdc.string;

	memcpy(newArray.ptr, cast(void*)px.ptr, size);
	(cast(void **)(&px))[1] = newArray.ptr;
	*cast(size_t *)&px = cast(size_t)newLength;
	
	return px;
}