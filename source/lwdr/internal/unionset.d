module lwdr.internal.unionset;
version(LWDR_ModuleCtors):
pragma(LDC_no_moduleinfo);

import lwdr.tracking;

pragma(LDC_no_typeinfo)
/++
Notice: for internal LWDR use! This container matches a key-value pair.
++/
struct LLUnionSet
{
	@system @nogc nothrow:
	private struct Item 
	{
		size_t key, value;
	}
	private Item[] items;
	private size_t length_;
	
	/// Alloc `capacity` number of slots.
	this(size_t capacity)
	{
		immutable size = capacity * Item.sizeof;
		items = cast(Item[])lwdrInternal_allocBytes(size);
	}

	~this() 
	{
		lwdrInternal_free(items.ptr);
	}

	/// Return reference to value that matches key. May return null.
	ref size_t opIndex(size_t key) { return *opBinaryRight!"in"(key); }

	/// Look for slot, if found return pointer to the value. If not, return null
	size_t* opBinaryRight(string op)(size_t k) if(op == "in")
	{
		foreach(ref item; items)
			if(item.key == k)
				return &item.value;
		return null;
	}

	/// Attempt to add or update value and key. If could do neither, return false.
	bool opIndexAssign(size_t value, size_t key)
	{
		// Check if key already present
		foreach(ref item; items)
		{
			if(item.key == key)
			{
				// If key present, update value and return
				item.value = value;
				return true;
			}
		}

		// Attempt to add to array, over 0 values
		foreach(ref item; items)
		{
			if(item.key == 0)
			{
				// Found open item, set it
				item.value = value;
				item.key = key;
				return true;
			}
		}

		// Failed to update or append.
		return false;
	}
}