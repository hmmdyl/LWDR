module lifetime.common;

public import rtoslink;

extern (C) void _d_delmemory(void* *p)
{
    if (*p)
    {
        rtosbackend_heapfreealloc(*p);
        *p = null;
    }
}

// strip const/immutable/shared/inout from type info
inout(TypeInfo) unqualify(inout(TypeInfo) cti) pure nothrow @nogc
{
    TypeInfo ti = cast() cti;
    while (ti)
    {
        // avoid dynamic type casts
        auto tti = typeid(ti);
        if (tti is typeid(TypeInfo_Const))
            ti = (cast(TypeInfo_Const)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Invariant))
            ti = (cast(TypeInfo_Invariant)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Shared))
            ti = (cast(TypeInfo_Shared)cast(void*)ti).base;
        else if (tti is typeid(TypeInfo_Inout))
            ti = (cast(TypeInfo_Inout)cast(void*)ti).base;
        else
            break;
    }
    return ti;
}

// size used to store the TypeInfo at the end of an allocation for structs that have a destructor
size_t structTypeInfoSize(const TypeInfo ti) pure nothrow @nogc
{
    if (ti && typeid(ti) is typeid(TypeInfo_Struct)) // avoid a complete dynamic type cast
    {
        auto sti = cast(TypeInfo_Struct)cast(void*)ti;
        if (sti.xdtor)
            return size_t.sizeof;
    }
    return 0;
}

extern(C) void rt_finalize(void* p, bool det = true, bool resetMemory = true) nothrow @nogc @trusted
{
	auto ppv = cast(void**)p;
	if(!p || !*ppv) return;

	auto pc = cast(ClassInfo*)*ppv;
	if(det)
	{
		auto c = *pc;
		do
		{
			if(c.destructor)
				(cast(void function(Object) @nogc nothrow)c.destructor)(cast(Object)p);
		}
		while((c = c.base) !is null);

		if(resetMemory)
		{
			p[0 .. pc.m_init.length] = (*pc).m_init[];
		}
	}
}

package void zeroMem(void* ptr, const size_t length) pure nothrow @nogc {
    ubyte* ptru = cast(ubyte*)ptr;
    foreach(i; 0 .. length) {
        ptru[i] = 0;
	}
}