module lwdr;

pragma(LDC_no_moduleinfo);

import lifetime.delegate_;
public import lwdr.tracking;

/// A static class by which to interface with core features of LWDR.
static final class LWDR
{
	/+/// Finalise and deallocate object `obj`
	static void free(ref Object obj) nothrow @nogc
	{
		import lifetime.class_;
		_d_delclass(&obj);
		obj = null;
	}+/
	
	static void free(T)(ref T obj) nothrow @nogc @trusted
		if(is(T == class) || is(T == interface))
	{
		import lifetime.class_;
		Object o = cast(Object)obj;
		_d_delclass(&o);
		obj = null;
	}

	version(LWDR_DynamicArray)
	/// Finalise (if possible) and deallocate dynamic array `arr`
	static void free(TArr : T[], T)(ref TArr arr) nothrow @trusted
	{
		import lifetime.array_;
		_d_delarray_t(cast(void[]*)&arr, cast(TypeInfo_Struct)typeid(TArr)); // cast to TypeInfo_Struct is acceptable
		arr = null;
	}

	/// Deallocate `ptr`
	static void free(TPtr : T*, T)(ref TPtr ptr) nothrow @trusted
		if(!is(T == struct))
	{
		import lifetime.common;
		_d_delmemory(cast(void**)&ptr);
		ptr = null;
	}

	/// Finalise (if possible) and deallocate struct pointed to by `ptr`.
	static void free(TPtr : T*, T)(ref TPtr ptr) nothrow @trusted
		if(is(T == struct))
	{
		import lifetime.common;
		TypeInfo_Struct s = cast(TypeInfo_Struct)typeid(T);
		s.dtor(ptr);
		_d_delmemory(cast(void**)&ptr);
		ptr = null;
	}

	version(LWDR_ManualDelegate)
	{
		/++
		Deallocate the context for a delegate. If the pointer isn't valid,
		then no action is taken. Hence, it is safe to call this for all types
		of delegate context types.
		++/
		static void freeDelegateContext(void* contextPtr) nothrow @trusted
		{
			freeDelegate(contextPtr);
		}
	}

	/// Start the runtime. Must be called once per process and before any runtime functionality is used!
	static void startRuntime() @trusted nothrow
	{
		version(LWDR_ModuleCtors)
		{
			import rt.moduleinfo;
			__lwdr_moduleInfo_runModuleCtors();
		}
		version(LWDR_ManualDelegate)
		{
			__lwdr_initLifetimeDelegate();
		}
	}

	/// Stop the runtime. Must be called once per process after all D code has exited.
	static void stopRuntime() @trusted nothrow
	{
		version(LWDR_ModuleCtors)
		{
			import rt.moduleinfo;
			__lwdr_moduleInfo_runModuleDtors();
		}
		version(LWDR_ManualDelegate)
		{
			__lwdr_deinitLifetimeDelegate();
		}
	}

	version(LWDR_TLS)
	{
		/++ Register the current thread with LWDR.
		 + This will perform the necessary TLS allocations for this thread. ++/
		static void registerCurrentThread() nothrow @trusted
		{
			import rt.sections;
			initTLSRanges();
			import rt.moduleinfo;
			__lwdr_moduleInfo_runTlsCtors();
		}

		/++ Deregister the current thread from LWDR.
		 + If this thread was not registered, it will cause unknown behaviour.
		 + This will deallocate TLS memory for this thread. ++/
		static void deregisterCurrentThread() nothrow @trusted
		{
			import rt.sections;
			freeTLSRanges();
			import rt.moduleinfo;
			__lwdr_moduleInfo_runTlsDtors();
		}
	}
}

/// Initialise LWDR. This forwards to `LWDR.startRuntime`. It is intended for external C code.
extern(C) void lwdrStartRuntime() @system nothrow
{ LWDR.startRuntime; }

/// Terminate LWDR. This forwards to `LWDR.stopRuntime`. It is intended for external C code.
extern(C) void lwdrStopRuntime() @system nothrow
{ LWDR.stopRuntime; }