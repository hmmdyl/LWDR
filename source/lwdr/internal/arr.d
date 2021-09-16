module lwdr.internal.arr;

import lwdr;
import core.atomic : cas, atomicLoad;

/++
For usage within LWDR only. This is mostly intended for book keeping of memory allocations.
A contiguous array is preferred on embedded environments to prevent heap memory fragmentation.
++/
struct LLArray
{
	private shared size_t[] items;
	private enum size_t nullVal = 0;

	this(size_t length)
	{
		items = new shared size_t[](length);
	}

	~this()
	{
		LWDR.free(cast(size_t[])items);
	}

	shared bool add(void* ptr)
	{
		foreach(i; 0 .. items.length)
		{
			if(cas(&items[i], nullVal, cast(size_t)ptr))
				return true;
		}
		return false;
	}

	shared bool has(void* ptr)
	{
		foreach(i; 0 .. items.length)
		{
			if(atomicLoad(items[i]) == cast(size_t)ptr)
				return true;
		}
		return false;
	}

	shared bool invalidate(void* ptr)
	{
		foreach(i; 0 .. items.length)
		{
			if(cas(&items[i], cast(size_t)ptr, nullVal))
			   return true;
		}
		return false;
	}
}