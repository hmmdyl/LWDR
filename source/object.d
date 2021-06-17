module object;

import util;
import rtoslink;
import lifetime.throwable;

version(LWDR_DynamicArray)
public import lifetime.array_ : _d_arraysetlengthTImpl;

version (D_LP64)
{
    alias size_t = ulong;
    alias ptrdiff_t = long;
}
else
{
    alias size_t = uint;
    alias ptrdiff_t = int;
}

alias sizediff_t = ptrdiff_t; //For backwards compatibility only.

alias hash_t = size_t; //For backwards compatibility only.
alias equals_t = bool; //For backwards compatibility only.

alias string  = immutable(char)[];
alias wstring = immutable(wchar)[];
alias dstring = immutable(dchar)[];

extern(C) void _d_assert(string f, uint l) { rtosbackend_assert(f, l); }
extern(C) void _d_assert_msg(string msg, string f, uint l) { rtosbackend_assertmsg(msg, f, l); }
extern(C) void _d_arraybounds(string f, size_t l) {rtosbackend_arrayBoundFailure(f, l);}

extern(C) bool _xopEquals(in void*, in void*) { return false; }
extern(C) int _xopCmp(in void*, in void*) { return 0; }

class Object 
{
	/// Convert Object to human readable string
	string toString() { return "Object"; }
	/// Compute hash function for Object
	size_t toHash() @trusted nothrow
	{
		auto addr = cast(size_t)cast(void*)this;
		return addr ^ (addr >>> 4);
	}
	
	int opCmp(Object o) { assert(false, "not implemented"); }
	bool opEquals(Object o) { return this is o; }
	
	static Object factory(string classname) { return null; }
}

bool opEquals(Object lhs, Object rhs)
{
    // If aliased to the same object or both null => equal
    if (lhs is rhs) return true;

    // If either is null => non-equal
    if (lhs is null || rhs is null) return false;

    if (!lhs.opEquals(rhs)) return false;

    // If same exact type => one call to method opEquals
    if (typeid(lhs) is typeid(rhs) ||
        !__ctfe && typeid(lhs).opEquals(typeid(rhs)))
            /* CTFE doesn't like typeid much. 'is' works, but opEquals doesn't
            (issue 7147). But CTFE also guarantees that equal TypeInfos are
            always identical. So, no opEquals needed during CTFE. */
    {
        return true;
    }

    // General case => symmetric calls to method opEquals
    return rhs.opEquals(lhs);
}

/************************
* Returns true if lhs and rhs are equal.
*/
bool opEquals(const Object lhs, const Object rhs)
{
    // A hack for the moment.
    return opEquals(cast()lhs, cast()rhs);
}

struct Interface
{
    TypeInfo_Class   classinfo;  /// .classinfo for this interface (not for containing class)
    void*[]     vtbl;
    size_t      offset;     /// offset to Interface 'this' from Object 'this'
}

/**
 * Array of pairs giving the offset and type information for each
 * member in an aggregate.
 */
struct OffsetTypeInfo
{
    size_t   offset;    /// Offset of member from start of object
    TypeInfo ti;        /// TypeInfo for this member
}
//enum immutable(void)* rtinfoHasPointers = cast(void*)1;

version(LWDR_DynamicArray)
{
    version = LWDR_INTERNAL_ti_next;
}

class TypeInfo 
{
    /// Compares two instances for equality.
	bool equals(in void* p1, in void* p2) const { return p1 == p2; }

    /// Returns size of the type.
    @property size_t tsize() nothrow pure const @safe @nogc { return 0; }

	/** Get TypeInfo for 'next' type, as defined by what kind of type this is,
    null if none. */
    version(LWDR_INTERNAL_ti_next)
    @property inout(TypeInfo) next() nothrow pure inout @nogc { return null; }

    /**
	* Return default initializer.  If the type should be initialized to all
	* zeros, an array with a null ptr and a length equal to the type size will
	* be returned. For static arrays, this returns the default initializer for
	* a single element of the array, use `tsize` to get the correct size.
	*/
    abstract const(void)[] initializer() nothrow pure const @safe @nogc;
}

class TypeInfo_Enum : TypeInfo 
{
	TypeInfo base;
	string name;
	void[] m_init; 
	
	override bool equals(in void* p1, in void* p2) const
	{ return base.equals(p1, p2); }
    override @property size_t tsize() nothrow pure const { return base.tsize; }

	override const(void)[] initializer() const
    { return m_init.length ? m_init : base.initializer(); }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return base.next; }
}

class TypeInfo_Pointer : TypeInfo 
{ 
    TypeInfo m_next; 

    override bool equals(in void* p1, in void* p2) const
	{ return *cast(void**)p1 == *cast(void**)p2; }
    override @property size_t tsize() nothrow pure const { return (void*).sizeof; }

	override const(void)[] initializer() const @trusted
    { return (cast(void *)null)[0 .. (void*).sizeof]; }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return m_next; }
}

class TypeInfo_Array : TypeInfo 
{
	TypeInfo value;

    override bool equals(in void* p1, in void* p2) const
	{
        void[] a1 = *cast(void[]*)p1;
        void[] a2 = *cast(void[]*)p2;
        if(a1.length != a2.length) return false;
        immutable sz = value.tsize;
        foreach(size_t i; 0 .. a1.length)
            if(!value.equals(a1.ptr + i * sz, a2.ptr + i * sz))
                return false;
        return true;
	}

    override @property size_t tsize() nothrow pure const
    { return (void[]).sizeof; }

	override const(void)[] initializer() const @trusted
    { return (cast(void *)null)[0 .. (void[]).sizeof]; }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout
    { return value; }
}

class TypeInfo_StaticArray : TypeInfo 
{ 
	TypeInfo value;
	size_t len;

	override bool equals(in void* p1, in void* p2) const
    {
        size_t sz = value.tsize;

        for (size_t u = 0; u < len; u++)
            if (!value.equals(p1 + u * sz, p2 + u * sz))
                return false;
        return true;
    }

    override @property size_t tsize() nothrow pure const
    { return len * value.tsize; }

    override const(void)[] initializer() nothrow pure const
    { return value.initializer(); }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return value; }
}

class TypeInfo_AssociativeArray : TypeInfo {
	TypeInfo value, key;

	override const(void)[] initializer() const @trusted
    { return (cast(void *)null)[0 .. (char[int]).sizeof]; }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout { return value; }
}

class TypeInfo_Vector : TypeInfo 
{
    TypeInfo base;

    override bool equals(in void* p1, in void* p2) const { return base.equals(p1, p2); }

	override const(void)[] initializer() nothrow pure const
    { return base.initializer(); }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return base.next; }
}

class TypeInfo_Function : TypeInfo 
{
	string deco;

    override const(void)[] initializer() const @safe
    {
        return null;
    }
}

class TypeInfo_Delegate : TypeInfo 
{
	string deco; 

    override bool equals(in void* p1, in void* p2) const
    {
        auto dg1 = *cast(void delegate()*)p1;
        auto dg2 = *cast(void delegate()*)p2;
        return dg1 == dg2;
    }

    override const(void)[] initializer() const @trusted
    {
        return (cast(void *)null)[0 .. (int delegate()).sizeof];
    }
}

//class TypeInfo_v : TypeInfo { const: nothrow: pure: @trusted: }

class TypeInfo_Interface : TypeInfo 
{
	TypeInfo_Class info;
	
	override bool equals(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }

	override const(void)[] initializer() const @trusted
    {
        return (cast(void *)null)[0 .. Object.sizeof];
    }

    override @property size_t tsize() nothrow pure const
    {
        return Object.sizeof;
    }
}

class TypeInfo_Tuple : TypeInfo
{
    TypeInfo[] elements;

	override bool opEquals(Object o)
    {
        if (this is o)
            return true;

        auto t = cast(const TypeInfo_Tuple)o;
        if (t && elements.length == t.elements.length)
        {
            for (size_t i = 0; i < elements.length; i++)
                if (elements[i] != t.elements[i])
                    return false;
            return true;
        }
        return false;
    }

	override @property size_t tsize() nothrow pure const
    {
        assert(0);
    }

    override const(void)[] initializer() const @trusted
    {
        assert(0);
    }
}

class TypeInfo_Class : TypeInfo 
{
	ubyte[] m_init; /// class static initializer (length gives class size)
	string name; /// name of class
	void*[] vtbl; // virtual function pointer table
	Interface[] interfaces;
	TypeInfo_Class base;
	void* destructor;
	void function(Object) classInvariant;
	uint m_flags;
	void* deallocator;
	void*[] m_offTi;
	void function(Object) defaultConstructor;
	immutable(void)* rtInfo;

	override @property size_t tsize() nothrow pure const
    { return Object.sizeof; }

	override bool equals(in void* p1, in void* p2) const
    {
        Object o1 = *cast(Object*)p1;
        Object o2 = *cast(Object*)p2;

        return (o1 is o2) || (o1 && o1.opEquals(o2));
    }

	override const(void)[] initializer() nothrow pure const @safe
    {
        return m_init;
    }
}
alias ClassInfo = TypeInfo_Class;

class TypeInfo_Const : TypeInfo {
	size_t getHash(scope const void*) const nothrow { return 0; }
	TypeInfo base; 

    override bool equals(in void *p1, in void *p2) const { return base.equals(p1, p2); }

    override @property size_t tsize() nothrow pure const { return base.tsize; }

    version(LWDR_INTERNAL_ti_next)
    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return base.next; }

	override const(void)[] initializer() nothrow pure const
    { return base.initializer(); }
}

class TypeInfo_Struct : TypeInfo {
	string name;
	void[] m_init;
	void* xtohash;
	void* xopequals;
	void* xopcmp;
	void* xtostring;
	uint flags;
	union {
		void function(void*) dtor;
		void function(void*, const TypeInfo_Struct) xdtor;
	}
	void function(void*) postblit;
	uint align_;
	immutable(void)* rtinfo;

    override bool equals(in void* p1, in void* p2) @trusted pure nothrow const
    {
        if (!p1 || !p2)
            return false;
        else if (xopequals)
            return (*cast(bool function(in void*, in void*) pure nothrow @safe *)xopequals)(p1, p2);
        else if (p1 == p2)
            return true;
        else
		{
            immutable len = m_init.length;
            auto p1B = cast(ubyte[])p1[0..len];
            auto p2B = cast(ubyte[])p2[0..len];
            foreach(i; 0 .. len)
			    if(p1B[i] != p2B[i]) 
                    return false;
            return true;
		}
    }

    override @property size_t tsize() nothrow pure const
    {
        return initializer().length;
    }

    override const(void)[] initializer() nothrow pure const @safe
    {
        return m_init;
    }
}

class TypeInfo_Invariant : TypeInfo_Const {}
class TypeInfo_Shared : TypeInfo_Const {}
class TypeInfo_Inout : TypeInfo_Const {}

class Throwable : Object 
{
	interface TraceInfo
	{
		int opApply(scope int delegate(ref const(char[]))) const;
		int opApply(scope int delegate(ref size_t, ref const(char[]))) const;
		string toString() const;
	}
	
	string msg;
	string file;
	size_t line;
	TraceInfo info;
	
	private Throwable nextInChain;
	
	private uint _refcount;
	
	@property inout(Throwable) next() @safe inout return scope pure nothrow @nogc { return nextInChain; }
	@property void next(Throwable tail) @safe scope nothrow @nogc
    {
        if (tail && tail._refcount)
            ++tail._refcount;           // increment the replacement *first*

        auto n = nextInChain;
        nextInChain = null;             // sever the tail before deleting it

        if (n && n._refcount)
            _d_delThrowable(n);         // now delete the old tail

        nextInChain = tail;             // and set the new tail
    }
	 @system @nogc final pure nothrow ref uint refcount() return { return _refcount; }
	 int opApply(scope int delegate(Throwable) dg)
    {
        int result = 0;
        for (Throwable t = this; t; t = t.nextInChain)
        {
            result = dg(t);
            if (result)
                break;
        }
        return result;
    }
	static @__future @system @nogc pure nothrow Throwable chainTogether(return scope Throwable e1, return scope Throwable e2)
    {
        if (!e1)
            return e2;
        if (!e2)
            return e1;
        if (e2.refcount())
            ++e2.refcount();

        for (auto e = e1; 1; e = e.nextInChain)
        {
            if (!e.nextInChain)
            {
                e.nextInChain = e2;
                break;
            }
        }
        return e1;
    }
	@nogc @safe pure nothrow this(string msg, Throwable nextInChain = null)
    {
        this.msg = msg;
        this.nextInChain = nextInChain;
        //this.info = _d_traceContext();
    }
	@nogc @safe pure nothrow this(string msg, string file, size_t line, Throwable nextInChain = null)
    {
        this(msg, nextInChain);
        this.file = file;
        this.line = line;
        //this.info = _d_traceContext();
    }
	@trusted nothrow ~this()
    {
        if (nextInChain && nextInChain._refcount)
            _d_delThrowable(nextInChain);
    }
	
	@__future const(char)[] message() const
    {
        return this.msg;
    }
}

class Exception : Throwable
{
    @nogc @safe pure nothrow this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }

    @nogc @safe pure nothrow this(string msg, Throwable nextInChain, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, nextInChain);
    }
}

class Error : Throwable
{
    @nogc @safe pure nothrow this(string msg, Throwable nextInChain = null)
    {
        super(msg, nextInChain);
        bypassedException = null;
    }

    @nogc @safe pure nothrow this(string msg, string file, size_t line, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
        bypassedException = null;
    }
	
    Throwable bypassedException;
}

bool __equals(T1, T2)(scope const T1[] lhs, scope const T2[] rhs)
@nogc nothrow pure @trusted
if (__traits(isScalar, T1) && __traits(isScalar, T2))
{
    if (lhs.length != rhs.length)
        return false;

    foreach (const i; 0 .. lhs.length)
        if (lhs.ptr[i] != rhs.ptr[i])
            return false;
    return true;
}

// Used in Exception Handling LSDA tables to 'wrap' C++ type info
// so it can be distinguished from D TypeInfo
class __cpp_type_info_ptr
{
    void* ptr;          // opaque pointer to C++ RTTI type info
}
