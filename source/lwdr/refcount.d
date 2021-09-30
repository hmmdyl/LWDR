module lwdr.refcount;

pragma(LDC_no_moduleinfo);

import lwdr : LWDR;
import lwdr.tracking;

// Based on AutoMem

/// Detects if a type is ref countable (is an interface, class, pointer or dynamic array)
enum isRefCountable(T) = 
	is(T == interface) || // interface
	is(T == class) || // class
	is(T == U*, U) || // pointer to something
	is(T == U[], U); // dynamic array

/++
Reference count for item of type `T`. Intended for use with
interfaces, classes, pointers to structs, and arrays.
++/
struct RefCount(T)
	if(isRefCountable!T)
{
	/// Begin reference counting an existing item
	this(auto ref T t)
	{
		version(LWDR_TrackMem)
		{
			bool tracking = isCurrentTracking();

			if(tracking)
				disableMemoryTracking();

			scope(exit)
			{
				if(tracking)
					enableMemoryTracking();
			}
		}

		interior = new Interior(t);
	}

	/// Create a new item and reference count it
	this(Args...)(auto ref Args args)
	{
		version(LWDR_TrackMem)
		{
			bool tracking = isCurrentTracking();

			if(tracking)
				disableMemoryTracking();

			scope(exit)
			{
				if(tracking)
					enableMemoryTracking();
			}
		}

		static if(is(T == class))
			interior = new Interior(new T(args));
        static if(is(T == U*, U))
        {
            alias root = rootType!T;
            static if(is(root == struct) || is(root == union))
                interior = new Interior(new root(args));
            else
            {
                interior = new Interior(new root);
                *interior.item = args[0];
            }
        }
        static if(is(T == U[], U))
        {
            alias root = rootType!T;
            interior = new Interior([args]);
        }
	}

	/// Copy
	this(this)
	{
		if(interior !is null)
			inc;
	}

	~this()
	{
		release;
	}

	/// Assign from an l-value RefCount
	void opAssign(ref RefCount other)
	{
		if(interior == other.interior) return;
		if(interior !is null) release;
		interior = other.interior;
		inc;
	}

	/// Dereference the RefCount and access the contained item
	ref auto opUnary(string s)() inout if(s == "*")
	{
		return interior.item;
	}

	static if(is(T == U[], U)) // if an array
    {
        /// Expose array's opSlice and opIndex
        auto ref opSlice(B, E)(auto ref B b, auto ref E e)
        {
            return interior.item[b .. e];
        }
        /// ditto
        auto ref opIndex(A...)(auto ref A args)
        {
            return interior.item[args];
        }
        /// ditto
        auto ref opIndexAssign(I, V)(auto ref V v, auto ref I i)
        {
            return interior.item[i] = v;
        }
    }
    else
    {
        /// Expose item's opSlice and opIndex
        auto ref opSlice(A...)(auto ref A args)
            if(__traits(compiles, (rootType!T).init.opSlice(args)))
		{
			return interior.item.opSlice(args);
		}
        /// ditto
        auto ref opIndex(A...)(auto ref A args)
            if(__traits(compiles, (rootType!T).init.opIndex(args)))
		{
			return interior.item.opIndex(args);
		}
        /// ditto
        auto ref opIndexAssign(A...)(auto ref A args)
            if(__traits(compiles, (rootType!T).init.opIndexAssign(args)))
		{
			return interior.item.opIndexAssign(args);
		}
    }

	/// A heap allocated struct which contains the item and number of references
	static struct Interior
	{
		static if(is(T == shared))
			shared size_t count;
		else 
			size_t count;

		T item;
		alias item this;

		private this(T item) 
		{
			count = 1;
			this.item = item;
		}

		/// Increment number of references
		private void inc() 
		{
			static if(is(T == shared))
			{
				import core.atomic : atomicOp;
				count.atomicOp!"+="(1);
			}
			else
				count++;
		}

		/// Decrement number of references
		private void dec() 
		{
			static if(is(T == shared))
			{
				import core.atomic : atomicOp;
				count.atomicOp!"-="(1);
			}
			else
				count--;
		}
	}

	static if(is(T == shared))
		shared Interior* interior;
	else
		Interior* interior;
	alias interior this;

	/// Release reference to the interior. If count is zero, then deallocate
	private void release()
	{
		if(interior is null) return;
		assert(interior.count > 0, "Try to release RefCount but count is <=0");

		dec;

		if(interior.count == 0)
			LWDR.free(interior.item);
	}
}