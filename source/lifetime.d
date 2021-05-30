module lifetime;

import rtoslink;

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

extern(C) Object _d_newclass(const TypeInfo_Class ti) 
{ 
	auto buff = internal_heapalloc(ti.m_init.length);
	foreach(i; 0 .. ti.m_init.length)
		buff[i] = ti.m_init[i];
	return cast(Object)buff.ptr;
}

extern(C) void _d_delclass(Object* o) 
{
	rtosbackend_heapfreealloc(cast(void*)*o);
	*o = null;
}

extern(C) Object _d_allocclass(TypeInfo_Class ti) 
{ 
	auto buff = internal_heapalloc(ti.m_init.length);
	foreach(i; 0 .. ti.m_init.length)
		buff[i] = ti.m_init[i];
	return cast(Object)buff.ptr;
}

/**
* Allocate an uninitialized non-array item.
* This is an optimization to avoid things needed for arrays like the __arrayPad(size).
*/
extern(C) void* _d_newitemU(scope const TypeInfo _ti) nothrow pure 
{
    auto ti = unqualify(_ti);
    immutable tiSize = structTypeInfoSize(ti);
    immutable itemSize = ti.tsize;
    immutable size = itemSize + tiSize;

    auto p = internal_heapalloc(size);
    
    if(tiSize) 
	{
        *cast(TypeInfo*)(p.ptr + itemSize) = null;
        *cast(TypeInfo*)(p.ptr + tiSize) = cast()ti;
	}
    return p.ptr;
}

/// Same as above, zero initializes the item.
extern(C) void* _d_newitemT(const TypeInfo ti) pure nothrow
{ 
    auto p = _d_newitemU(ti);
    foreach(i; 0 .. ti.tsize) 
	{
        (cast(ubyte*)p)[i] = 0;
	}
    return p;
}

/// Same as above, for item with non-zero initializer.
extern (C) void* _d_newitemiT(in TypeInfo _ti) pure nothrow
{
    auto p = _d_newitemU(_ti);
    const ubyte[] init = cast(const ubyte[])_ti.initializer();
    assert(init.length <= _ti.tsize);

    foreach(i; 0 .. init.length) {
        (cast(ubyte*)p)[i] = init[i];
	}

    return p;
}

extern (C) void _d_delmemory(void* *p)
{
    if (*p)
    {
        rtosbackend_heapfreealloc(*p);
        *p = null;
    }
}


nothrow extern(C) void _d_delThrowable(Throwable t) @trusted @nogc
{
	if(t is null) return;
	
	/+auto refcount = t.refcount();
	t.refcount() = --refcount;
	if(refcount > 1) return;+/
    t.refcount = t.refcount - 1;
	
	rt_finalize(cast(void*)t);
	rtosbackend_heapfreealloc(cast(void*)t);
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

extern (C):
@nogc:
nothrow:
pure:

/******************************************
 * Given a pointer:
 *      If it is an Object, return that Object.
 *      If it is an interface, return the Object implementing the interface.
 *      If it is null, return null.
 *      Else, undefined crash
 */
Object _d_toObject(return void* p)
{
    if (!p)
        return null;

    Object o = cast(Object) p;
    ClassInfo oc = typeid(o);
    Interface* pi = **cast(Interface***) p;

    /* Interface.offset lines up with ClassInfo.name.ptr,
     * so we rely on pointers never being less than 64K,
     * and Objects never being greater.
     */
    if (pi.offset < 0x10000)
    {
        debug(cast_) printf("\tpi.offset = %d\n", pi.offset);
        return cast(Object)(p - pi.offset);
    }
    return o;
}

/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */
void* _d_interface_cast(void* p, ClassInfo c)
{
    debug(cast_) printf("_d_interface_cast(p = %p, c = '%.*s')\n", p, c.name);
    if (!p)
        return null;

    Interface* pi = **cast(Interface***) p;

    debug(cast_) printf("\tpi.offset = %d\n", pi.offset);
    return _d_dynamic_cast(cast(Object)(p - pi.offset), c);
}

void* _d_dynamic_cast(Object o, ClassInfo c)
{
    debug(cast_) printf("_d_dynamic_cast(o = %p, c = '%.*s')\n", o, c.name);

    void* res = null;
    size_t offset = 0;
    if (o && _d_isbaseof2(typeid(o), c, offset))
    {
        debug(cast_) printf("\toffset = %d\n", offset);
        res = cast(void*) o + offset;
    }
    debug(cast_) printf("\tresult = %p\n", res);
    return res;
}

int _d_isbaseof2(scope ClassInfo oc, scope const ClassInfo c, scope ref size_t offset) @safe
{
    if (oc is c)
        return true;

    do
    {
        if (oc.base is c)
            return true;

        // Bugzilla 2013: Use depth-first search to calculate offset
        // from the derived (oc) to the base (c).
        foreach (iface; oc.interfaces)
        {
            if (iface.classinfo is c || _d_isbaseof2(iface.classinfo, c, offset))
            {
                offset += iface.offset;
                return true;
            }
        }

        oc = oc.base;
    } while (oc);

    return false;
}

int _d_isbaseof(scope ClassInfo oc, scope const ClassInfo c) @safe
{
    if (oc is c)
        return true;

    do
    {
        if (oc.base is c)
            return true;

        foreach (iface; oc.interfaces)
        {
            if (iface.classinfo is c || _d_isbaseof(iface.classinfo, c))
                return true;
        }

        oc = oc.base;
    } while (oc);

    return false;
}

extern(C) void __aeabi_read_tp() {}