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
