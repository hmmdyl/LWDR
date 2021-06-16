module lifetime.item;

import lifetime.common;

/**
* Allocate an uninitialized non-array item.
* This is an optimization to avoid things needed for arrays like the __arrayPad(size).
*/
extern(C) void* _d_newitemU(scope const TypeInfo _ti) nothrow 
{
    auto ti = unqualify(_ti);
    immutable tiSize = structTypeInfoSize(ti);
    immutable itemSize = ti.tsize;
    immutable size = itemSize + tiSize;

    auto p = lwdrInternal_allocBytes(size);

    if(tiSize) 
	{
        *cast(TypeInfo*)(p.ptr + itemSize) = null;
        *cast(TypeInfo*)(p.ptr + tiSize) = cast()ti;
	}
    return p.ptr;
}

/// Same as above, zero initializes the item.
extern(C) void* _d_newitemT(const TypeInfo ti) nothrow
{ 
    auto p = _d_newitemU(ti);
    foreach(i; 0 .. ti.tsize) 
	{
        (cast(ubyte*)p)[i] = 0;
	}
    return p;
}

/// Same as above, for item with non-zero initializer.
extern (C) void* _d_newitemiT(in TypeInfo _ti) nothrow
{
    auto p = _d_newitemU(_ti);
    const ubyte[] init = cast(const ubyte[])_ti.initializer();
    assert(init.length <= _ti.tsize);

    foreach(i; 0 .. init.length) {
        (cast(ubyte*)p)[i] = init[i];
	}

    return p;
}