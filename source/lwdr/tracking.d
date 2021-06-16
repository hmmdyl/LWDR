module lwdr.tracking;

import rtoslink;

version(LWDR_TrackMem)
{
	struct AllocationList(T, size_t MaxElements)
	{
		static assert(MaxElements > 0, "MaxElements should be at least 1!");

		private T[MaxElements] payload;
		private size_t length_ = 0;

		@property bool empty() const { return length_ == 0; }
		@property size_t length() const { return length_; }

		bool add(T t) nothrow @nogc
		{
			if(length_ + 1 >= MaxElements)
				return false;

			payload[length_++] = t;
			return true;
		}

		auto getLast() nothrow @nogc
		{
			return payload[length_ - 1];
		}

		void removeLast() nothrow @nogc
		{
			if(empty) return;

			payload[length_ - 1] = T.init;
			length_--;
		}

		bool removeLastOccurenceOf(T t) nothrow @nogc
		{
			if(empty) return false;

			size_t index;
			bool found = false;

			for(size_t i = length_ - 1; i > 0; i--)
			{
				if(payload[i] == t)
				{
					index = i;
					found = true;
				}
			}

			if(!found)
				return false;

			for(size_t i = index; i < length_ - 1; i++)
			{
				payload[i] = payload[i+1];
			}
			payload[length_ - 1] = T.init;
			length_--;
			return true;
		}
	}

	private __gshared AllocationList!(void*, 16) trackedAllocations;

	struct MemAlloc
	{
		size_t allocsAtScope;

		void free() nothrow @nogc
		{
			assert(allocsAtScope >= trackedAllocations.length);

			auto difference = trackedAllocations.length - allocsAtScope;
			foreach(d; 0 .. difference)
			{
				auto ptr = trackedAllocations.getLast;
				trackedAllocations.removeLast;
				rtosbackend_heapfreealloc(ptr);
			}
		}
	}

	MemAlloc enterMemoryTracking() nothrow @nogc
	{
		return MemAlloc(trackedAllocations.length);
	}

	private __gshared currentlyTracking = false;
	void enableMemoryTracking() nothrow @nogc { currentlyTracking = true; }
	void disableMemoryTracking() nothrow @nogc { currentlyTracking = false; }

	void* lwdrInternal_alloc(size_t sz) nothrow @nogc
	{
		auto ptr = rtosbackend_heapalloc(sz);
		if(currentlyTracking)
		{
			trackedAllocations.add(ptr);
		}
		return ptr;
	}

	void lwdrInternal_free(void* ptr) nothrow @nogc
	{
		trackedAllocations.removeLastOccurenceOf(ptr);
		rtosbackend_heapfreealloc(ptr);
	}

	ubyte[] lwdrInternal_allocBytes(size_t sz) nothrow @nogc
	{
		return cast(ubyte[])lwdrInternal_alloc(sz)[0..sz];
	}
}
else
{
	void* lwdrInternal_alloc(size_t sz) nothrow @nogc pure
	{
		return rtosbackend_heapalloc(sz);
	}

	void lwdrInternal_free(void* ptr) nothrow @nogc pure
	{
		return rtosbackend_heapfreealloc(ptr);
	}

	ubyte[] lwdrInternal_allocBytes(size_t sz) nothrow pure @nogc
	{
		return cast(ubyte[])lwdrInternal_alloc(sz)[0..sz];
	}
}