module lwdr.tracking;

import rtoslink;

version(LWDR_TrackMem)
{
	/// Keeps track of allocations
	struct AllocationList(T, size_t MaxElements)
	{
		static assert(MaxElements > 0, "MaxElements should be at least 1!");

		private T[MaxElements] payload;
		private size_t length_ = 0;

		@property bool empty() const { return length_ == 0; }
		@property size_t length() const { return length_; }

		/// Track an allocation
		bool add(T t) nothrow @nogc
		{
			if(length_ + 1 >= MaxElements)
				return false;

			payload[length_++] = t;
			return true;
		}

		/// Get last allocation
		auto getLast() nothrow @nogc
		{
			return payload[length_ - 1];
		}

		/// Remove last allocation
		void removeLast() nothrow @nogc
		{
			if(empty) return;

			payload[length_ - 1] = T.init;
			length_--;
		}

		/// Find the last occurence of `t` and remove it
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

	version(LWDR_TLS)
		private AllocationList!(void*, 16) trackedAllocations; /// Track allocations per-thread
	else
		private __gshared AllocationList!(void*, 16) trackedAllocations; /// Track allocations across all threads
	
	/// Stores state of allocations at specific scope
	struct MemAlloc
	{
		size_t allocsAtScope; /// number of allocations when this struct was initiated

		/// free allocations until `trackedAllocations.length` matches `this.allocsAtScope`.
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

	/// Get the current state of allocations
	MemAlloc enterMemoryTracking() nothrow @nogc
	{
		return MemAlloc(trackedAllocations.length);
	}

	version(LWDR_TLS)
		private bool currentlyTracking = false; /// Are we currently tracking allocations?
	else
		private __gshared bool currentlyTracking = false; /// Are we currently tracking allocations?
	/// Are we currently allocations?
	bool isCurrentTracking() nothrow @nogc { return currentlyTracking; }
	/// Begin tracking allocations
	void enableMemoryTracking() nothrow @nogc { currentlyTracking = true; }
	/// Stop tracking allocations
	void disableMemoryTracking() nothrow @nogc { currentlyTracking = false; }

	/// Allocate heap memory of `sz` bytes. If tracking allocations, the resultant pointer will be added to `trackedAllocations`
	void* lwdrInternal_alloc(size_t sz) nothrow @nogc
	{
		auto ptr = rtosbackend_heapalloc(sz);
		if(currentlyTracking)
		{
			trackedAllocations.add(ptr);
		}
		return ptr;
	}

	/// Dealloc heap memory
	void lwdrInternal_free(void* ptr) nothrow @nogc
	{
		trackedAllocations.removeLastOccurenceOf(ptr);
		rtosbackend_heapfreealloc(ptr);
	}

	/// Allocate `sz` bytes heap memory represented by a slice of ubytes. If tracking allocations, the resultant slice will be added to `trackedAllocations`
	ubyte[] lwdrInternal_allocBytes(size_t sz) nothrow @nogc
	{
		return cast(ubyte[])lwdrInternal_alloc(sz)[0..sz];
	}
}
else
{
	/// Allocate heap memory of `sz` bytes
	void* lwdrInternal_alloc(size_t sz) nothrow @nogc pure
	{
		return rtosbackend_heapalloc(sz);
	}

	/// Free heap memory
	void lwdrInternal_free(void* ptr) nothrow @nogc pure
	{
		return rtosbackend_heapfreealloc(ptr);
	}

	/// Allocate `sz` bytes of heap memory represented by a slice of ubytes.
	ubyte[] lwdrInternal_allocBytes(size_t sz) nothrow pure @nogc
	{
		return cast(ubyte[])lwdrInternal_alloc(sz)[0..sz];
	}
}