module memory;

import rtoslink;

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

extern(C) void* _d_newitemT(const TypeInfo ti) { return null; }

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