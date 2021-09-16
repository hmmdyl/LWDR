module lifetime.delegate_;

import lwdr.internal.arr;
import lwdr.tracking;

version(LWDR_ManualDelegate):

private shared LLArray delegateContextAllocations;

/++
Allocate `sz` amount of bytes for a delegate context.
The ptr to the context will be stored in an internal array
for book keeping.
++/
extern(C) void* _d_allocmemory(size_t sz)
{
	void* ptr = lwdrInternal_alloc(sz);
	bool added = delegateContextAllocations.add(ptr);
	assert(added); // TODO, depending on policy, extend list or terminate
	return ptr;
}

/++
Deallocate the context for a delegate. If the pointer isn't valid,
then no action is taken. Hence, it is safe to call this for all types
of delegate context types.
++/
void freeDelegate(void* contextPtr)
{
	if(delegateContextAllocations.invalidate(contextPtr))
	{
		import lifetime.common;
		_d_delmemory(&contextPtr);
	}
}