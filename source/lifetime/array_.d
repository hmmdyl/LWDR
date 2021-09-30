module lifetime.array_;

pragma(LDC_no_moduleinfo);

import lifetime.common;

/// Copy an array byte-by-byte from `from` to `to`.
extern(C) void[] _d_arraycopy(size_t size, void[] from, void[] to) nothrow @nogc
{
    auto fromBytes = cast(ubyte[])from;
    auto toBytes = cast(ubyte[])to;

    foreach(size_t i; 0 .. size)
        toBytes[i] = fromBytes[i];

    return to;
}

/// Determine equivalence of two arrays
extern(C) int _adEq2(void[] a1, void[] a2, TypeInfo ti) 
{
    if(a1.length != a2.length) return 0;
    if(!ti.equals(&a1, &a2)) return 0;

    return 1;
}

/// Copy items from one slice into another
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

version(LWDR_DynamicArray):

/**
* Allocate a new uninitialized array of length elements.
* ti is the type of the resulting array, or pointer to element.
*/
extern(C) void[] _d_newarrayU(const TypeInfo ti, size_t length) nothrow
{
	auto tinext = unqualify(ti.next);
	auto size = tinext.tsize;

	void* ptr = lwdrInternal_alloc(size * length);
	zeroMem(ptr, size * length);
	return ptr[0 .. size * length];
}

/**
* Allocate a new array of length elements.
* ti is the type of the resulting array, or pointer to element.
* (For when the array is initialized to 0)
*/
extern(C) void[] _d_newarrayT(const TypeInfo ti, size_t length) nothrow
{
	return _d_newarrayU(ti, length);
}

/**
* For when the array has a non-zero initializer.
*/
extern (C) void[] _d_newarrayiT(const TypeInfo ti, size_t length) nothrow
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

/// Finalize the elements in array `p`
void finalize_array(void* p, size_t size, const TypeInfo_Struct si) nothrow
{
    // Due to the fact that the delete operator calls destructors
    // for arrays from the last element to the first, we maintain
    // compatibility here by doing the same.
	if(si.dtor is null)
		return;

    auto tsize = si.tsize;
    for (auto curP = p + size - tsize; curP >= p; curP -= tsize)
    {
        // call destructor
        (cast(void function(void*) nothrow)si.dtor)(curP); // pretend to be nothrow
		// TODO: depending on exception support flag, enforce nothrow or throw dtor in type info???
    }
}

/// Finalize (if possible) and deallocate target array `p`
extern(C) void _d_delarray_t(void[]* p, const TypeInfo_Struct ti) nothrow
{
	if(!p) return;

	if(ti) // ti non-null only if ti is a struct with dtor
	{
		finalize_array(p.ptr, p.length * ti.tsize, ti);
	}

	lwdrInternal_free((*p).ptr);
	*p = null;
}

/**
* Extend an array by n elements.
* Caller must initialize those elements.
*/
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

/// Concatenate two arrays
extern(C) byte[] _d_arraycatT(const TypeInfo ti, byte[] x, byte[] y)
{
	auto tiNext = unqualify(ti.next);
	auto sizeElem = tiNext.tsize;

	size_t xlen = x.length * sizeElem;
	size_t ylen = y.length * sizeElem;
	size_t len = xlen + ylen;

	byte[] newArr = cast(byte[])lwdrInternal_alloc(len)[0..len];
	
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
    size_t _d_arraysetlengthT(return scope ref Tarr arr, size_t newlength) @trusted nothrow
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

/// Figure out how many elements to copy
private size_t getCopyLength(size_t newlength, size_t originalLength) nothrow @nogc 
{
	if(newlength > originalLength)
		return originalLength;
	else return newlength; // newlength less than originalLength
}

/**
* Resize dynamic arrays with 0 initializers.
*/
extern (C) void[] _d_arraysetlengthT(const TypeInfo ti, size_t newlength, void[]* p) nothrow
{
	auto tiNext = unqualify(ti.next);
	auto sizeElem = tiNext.tsize;
	auto newArr = _d_newarrayU(ti, newlength);

	import core.stdc.string;

	auto numElemToCopy = getCopyLength(newlength, p.length);
	memcpy(newArr.ptr, p.ptr, numElemToCopy * sizeElem);

	*p = newArr[0 .. newlength];
	return *p;
}

/**
* Resize arrays for non-zero initializers.
*      p               pointer to array lvalue to be updated
*      newlength       new .length property of array
*      sizeelem        size of each element of array
*      initsize        size of initializer
*      ...             initializer
*/
extern (C) void[] _d_arraysetlengthiT(const TypeInfo ti, size_t newlength, void[]* p) nothrow
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

	size_t numElemToCopy = getCopyLength(newlength, p.length);
	memcpy(newArr.ptr, p.ptr, numElemToCopy * sizeElem);

	if(newlength >= p.length) {
		doInitialize(newArr.ptr + p.length * sizeElem, 
					 newArr.ptr + newlength * sizeElem,
					 tiNext.initializer);
	}

	*p = newArr[0 .. newlength];
	return *p;
}