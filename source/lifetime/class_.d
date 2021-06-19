module lifetime.class_;

import lifetime.common;

extern(C) Object _d_newclass(const TypeInfo_Class ti) 
{
	auto buff = lwdrInternal_allocBytes(ti.m_init.length);
	foreach(i; 0 .. ti.m_init.length)
		buff[i] = ti.m_init[i];
	return cast(Object)buff.ptr;
}

extern(C) void _d_delclass(Object* o) nothrow @nogc
{
    if(*o)
	{
        rt_finalize(cast(void*)*o);

	    lwdrInternal_free(cast(void*)*o);
	    *o = null;
    }
}

extern(C) Object _d_allocclass(TypeInfo_Class ti) 
{ 
	auto buff = lwdrInternal_allocBytes(ti.m_init.length);
	foreach(i; 0 .. ti.m_init.length)
		buff[i] = ti.m_init[i];
	return cast(Object)buff.ptr;
}

/******************************************
* Given a pointer:
*      If it is an Object, return that Object.
*      If it is an interface, return the Object implementing the interface.
*      If it is null, return null.
*      Else, undefined crash
*/
extern(C) Object _d_toObject(return void* p) pure nothrow @nogc
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
extern(C) void* _d_interface_cast(void* p, ClassInfo c) pure nothrow @nogc
{
    debug(cast_) printf("_d_interface_cast(p = %p, c = '%.*s')\n", p, c.name);
    if (!p)
        return null;

    Interface* pi = **cast(Interface***) p;

    debug(cast_) printf("\tpi.offset = %d\n", pi.offset);
    return _d_dynamic_cast(cast(Object)(p - pi.offset), c);
}



extern(C) void* _d_dynamic_cast(Object o, ClassInfo c) pure nothrow @nogc
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

extern(C) int _d_isbaseof2(scope ClassInfo oc, scope const ClassInfo c, scope ref size_t offset) @safe pure nothrow @nogc
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

extern(C) int _d_isbaseof(scope ClassInfo oc, scope const ClassInfo c) @safe pure nothrow @nogc
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