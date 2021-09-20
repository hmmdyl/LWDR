module lwdr.internal.arr;

import lwdr;
import core.atomic : cas, atomicLoad;

/++
For usage within LWDR only. This is mostly intended for book keeping of memory allocations.
A contiguous array is preferred on embedded environments to prevent heap memory fragmentation.
++/
struct LLArray
{
	private size_t[] items;
	private enum size_t nullVal = 0;

	this(size_t length) nothrow
	{
		items = new size_t[](length);
	}

	~this() nothrow
	{
		if(items !is null)
			dealloc;
	}

	void dealloc() nothrow
	{
		scope(exit) items = null;
		LWDR.free(cast(size_t[])items);
	}

	/// Add a pointer to the list. Returns a boolean indicating success of the addition.
	bool add(void* ptr) nothrow
	{
		foreach(i; 0 .. items.length)
		{
			if(cas(&items[i], nullVal, cast(size_t)ptr))
				return true;
		}
		return false;
	}

	/// Check if pointer is in list. Returns true if pointer is present, false if not.
	bool has(void* ptr) nothrow
	{
		foreach(i; 0 .. items.length)
		{
			if(atomicLoad(items[i]) == cast(size_t)ptr)
				return true;
		}
		return false;
	}

	/// Remove a pointer from the list and set it to null. Returns true if the pointer is in the list and was nullified, false if not.
	bool invalidate(void* ptr) nothrow
	{
		foreach(i; 0 .. items.length)
		{
			if(cas(&items[i], cast(size_t)ptr, nullVal))
			   return true;
		}
		return false;
	}

	/// Get an unsafe, unsynchronised range over the pointers.
	auto unsafeRange() nothrow
	{
		return Range(items);
	}

	static struct Range
	{
		private size_t[] array;
		private size_t index;

		@disable this();

		this(size_t[] arr) nothrow
		{
			this.array = arr;
		}

		@property bool empty() const nothrow
		{
			return array is null || index >= array.length;
		}

		ref size_t front() nothrow
		{
			return *(&array[index]);
		}

		void popFront() nothrow
		{
			index++;
		}
	}
}