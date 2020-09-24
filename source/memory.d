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
	
	auto refcount = t.refcount();
	t.refcount() = --refcount;
	if(refcount > 1) return;
	
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