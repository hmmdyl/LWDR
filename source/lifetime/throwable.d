module lifetime.throwable;

import lifetime.common;

/// Delete a `Throwable` (exception handling support)
nothrow extern(C) void _d_delThrowable(Throwable t) @trusted @nogc
{
	if(t is null) return;

	/+auto refcount = t.refcount();
	t.refcount() = --refcount;
	if(refcount > 1) return;+/
    t.refcount = t.refcount - 1;

	rt_finalize(cast(void*)t);
	lwdrInternal_free(cast(void*)t);
}