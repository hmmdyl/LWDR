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

extern(C) byte[] _d_arraycatT(const TypeInfo ti, byte[] x, byte[] y)
{
	auto tiNext = unqualify(ti.next);
	auto sizeElem = tiNext.tsize;

	size_t xlen = x.length * sizeElem;
	size_t ylen = y.length * sizeElem;
	size_t len = xlen + ylen;

	byte[] newArr = cast(byte[])rtosbackend_heapalloc(len)[0..len];
	
	import core.stdc.string;

	memcpy(newArr.ptr, x.ptr, xlen);
	memcpy(newArr.ptr + xlen, y.ptr, ylen);

	return newArr[0..x.length + y.length];
}

template _d_arraysetlengthTImpl(Tarr : T[], T)
{
    /**
	* Resize dynamic array
	* Params:
	*  arr = the array that will be resized, taken as a reference
	*  newlength = new length of array
	* Returns:
	*  The new length of the array
	* Bugs:
	*   The safety level of this function is faked. It shows itself as `@trusted pure nothrow` to not break existing code.
	*/
    size_t _d_arraysetlengthT(return scope ref Tarr arr, size_t newlength) @trusted pure nothrow
    {
        pragma(inline, false);
        version (D_TypeInfo)
        {
            auto ti = typeid(Tarr);

            static if (__traits(isZeroInit, T))
                ._d_arraysetlengthT(ti, newlength, cast(void[]*)&arr);
            else
                ._d_arraysetlengthiT(ti, newlength, cast(void[]*)&arr);

            return arr.length;
        }
        else
            assert(0, errorMessage);
    }
}

private size_t getCopyLength(size_t newlength, size_t originalLength) pure nothrow @nogc 
{
	// call stdlib max??

	// if new length is smaller than current length,
	// only copy the new length amount of elements.
	// copying the origin length will cause a bounds error.
	auto numElemToCopy = p.length;
	if(newlength > numElemToCopy)
		numElemToCopy = true; 
}

extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) pure nothrow
{
	auto tiNext = unqualify(ti.next);
	auto sizeElem = tiNext.tsize;
	auto newArr = _d_newarrayU(ti, newlength);

	import core.stdc.string;


	//auto numElemToCopy = getCopyLength(newlength, p.length);
	memcpy(newArr.ptr, p.ptr, p.length * sizeElem);

	*p = newArr[0 .. newlength];
	return *p;
}

extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p) pure nothrow
{
	import core.stdc.string;
	static void doInitialize(void *start, void *end, const void[] initializer)
    {
        if (initializer.length == 1)
        {
            memset(start, *(cast(ubyte*)initializer.ptr), end - start);
        }
        else
        {
            auto q = initializer.ptr;
            immutable initsize = initializer.length;
            for (; start < end; start += initsize)
            {
                memcpy(start, q, initsize);
            }
        }
    }

	auto tiNext = unqualify(ti.next);
	auto sizeElem = tiNext.tsize;
	auto newArr = _d_newarrayU(ti, newlength);

	import core.stdc.string;

	memcpy(newArr.ptr, p.ptr, p.length * sizeElem);

	doInitialize(newArr.ptr + p.length * sizeElem, 
				 newArr.ptr + newlength * sizeElem,
				 tiNext.initializer);

	*p = newArr[0 .. newlength];
	return *p;
}