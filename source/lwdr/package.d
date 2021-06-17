module lwdr;

static final class LWDR
{
	static void free(ref Object obj) nothrow @nogc
	{
		import lifetime.class_;
		_d_delclass(&obj);
		obj = null;
	}

	version(LWDR_DynamicArray)
	static void free(TArr : T[], T)(ref TArr arr)
	{
		import lifetime.array_;
		_d_delarray_t(cast(void[]*)&arr, typeid(T));
		arr = null;
	}

	static void free(TPtr : T*, T)(ref TPtr ptr) 
		if(!is(T == struct))
	{
		import lifetime.common;
		_d_delmemory(cast(void**)&ptr);
		ptr = null;
	}

	static void free(TPtr : T*, T)(ref TPtr ptr) 
		if(is(T == struct))
	{
		import lifetime.common;
		TypeInfo_Struct s = cast(TypeInfo_Struct)typeid(T);
		s.dtor(ptr);
		_d_delmemory(cast(void**)&ptr);
		ptr = null;
	}

	version(LWDR_TLS)
	{
		static void registerCurrentThread() nothrow @nogc
		{
			import rt.sections;
			initTLSRanges();
		}

		static void deregisterCurrentThread() nothrow @nogc
		{
			import rt.sections;
			freeTLSRanges();
		}
	}
}