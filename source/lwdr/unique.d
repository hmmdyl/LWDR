module lwdr.unique;

import lwdr.util.traits;
import lwdr : LWDR;

/++ Check if T is suitable for a unique pointer. 
	T must be a class, interface, pointer or dynamic array. ++/
enum isSuitableForUnique(T) = 
	is(T == class) ||
	is(T == interface) ||
	is(T == U*, U) ||
	is(T == U[], U);

/++ A unique pointer. Only one pointer to a target may exist at a time.
	Pointers can be explicitly moved, but not copied. ++/
struct Unique(T)
	if(isSuitableForUnique!T)
{
	@disable this(this); /// Disable copy semantics

	T payload; /// Payload
	alias payload this;

	/// Assign a payload to this unique pointer
	this(T t)
	{
		payload = t;
	}

	/// Allocate the payload
	this(Args...)(auto ref Args args)
	{
        static if(is(T == class))
            payload = new T(args);
        static if(is(T == U*, U))
        {
            alias root = rootType!T;
            static if(is(root == struct) || is(root == union))
                payload = new root(args);
            else
            {
                payload = new root;
                *payload = args[0];
            }
        }
        static if(is(T == U[], U))
        {
            alias root = rootType!T;
            payload = [args];
        }
	}

	~this()
	{
		if(payload !is null)
		{
			LWDR.free(payload);
			payload = null;
		}
	}

	/// Move to a new instance
	Unique move() 
	{
		Unique ret;
		ret.payload = this.payload;
		this.payload = null;
		return ret;
	}

	/// Borrow the pointer
	inout auto borrow() @system { return payload; }

	/// Check if this unique instance has a payload
	@property auto bool hasPayload() const 
	{ return payload !is null; }

	/// ditto.
	auto opCast(CastTarget)() if(is(CastTarget == bool))
	{ return hasPayload; }
}