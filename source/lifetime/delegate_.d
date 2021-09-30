module lifetime.delegate_;

pragma(LDC_no_moduleinfo);

import lwdr.internal.arr;
import lwdr.tracking;

version(LWDR_ManualDelegate):

version(LWDR_ManualDelegate_16Dels)
	private enum numDelegatesTrack = 16; // Can track 16 delegate contexts, maximum
version(LWDR_ManualDelegate_32Dels)
	private enum numDelegatesTrack = 32; // Can track 32 delegate contexts, maximum
version(LWDR_ManualDelegate_64Dels)
	private enum numDelegatesTrack = 64; // Can track 64 delegate contexts, maximum
else
	private enum numDelegatesTrack = 8; // Can track 8 delegate contexts, maximum

/// Keeps track of delegate context allocations
private __gshared LLArray delegateContextAllocations;

/++
Allocate `sz` amount of bytes for a delegate context.
The ptr to the context will be stored in an internal array
for book keeping.
++/
extern(C) void* _d_allocmemory(size_t sz) @trusted
{
	void* ptr = lwdrInternal_alloc(sz);
	bool added = delegateContextAllocations.add(ptr);
	assert(added); // Panic if out of room to store the context
	return ptr;
}

/++
Deallocate the context for a delegate. If the pointer isn't valid,
then no action is taken. Hence, it is safe to call this for all types
of delegate context types.
++/
void freeDelegate(void* contextPtr) @trusted nothrow
{
	if(delegateContextAllocations.invalidate(contextPtr))
	{
		import lifetime.common;
		_d_delmemory(&contextPtr);
	}
}

/// INTERNAL LWDR USE! Allocates the book keeping system for delegate context allocations.
void __lwdr_initLifetimeDelegate() @system nothrow
{
	delegateContextAllocations = LLArray(numDelegatesTrack);
}

/// INTERNAL LWDR USE! Deallocates the book keeping system and any residual contexts.
void __lwdr_deinitLifetimeDelegate() @system nothrow
{
	foreach(ref size_t ptr; delegateContextAllocations.unsafeRange)
	{
		// If the runtime is exiting, assume safe to unload any memory not already freed
		import lifetime.common;
		_d_delmemory(cast(void**)&ptr);
	}
	delegateContextAllocations.dealloc;
}