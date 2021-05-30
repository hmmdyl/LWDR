module object;

import util;
import rtoslink;
import lifetime.throwable;

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

class TypeInfo 
{
    /// Compares two instances for equality.
	bool equals(in void* p1, in void* p2) const { return p1 == p2; }

    /// Returns size of the type.
    @property size_t tsize() nothrow pure const @safe @nogc { return 0; }

	/** Get TypeInfo for 'next' type, as defined by what kind of type this is,
    null if none. */
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

    override @property inout(TypeInfo) next() nothrow pure inout 
	{ return value; }
}

class TypeInfo_AssociativeArray : TypeInfo {
	TypeInfo value, key;

	override const(void)[] initializer() const @trusted
    { return (cast(void *)null)[0 .. (char[int]).sizeof]; }

    override @property inout(TypeInfo) next() nothrow pure inout { return value; }
}

class TypeInfo_Vector : TypeInfo 
{
    TypeInfo base;

    override bool equals(in void* p1, in void* p2) const { return base.equals(p1, p2); }

	override const(void)[] initializer() nothrow pure const
    { return base.initializer(); }

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

// Reduces to `T` if `cond` is `true` or `U` otherwise.
private template Select(bool cond, T, U)
{
    static if (cond) alias Select = T;
    else alias Select = U;
}

template Floating(T)
if (is(T == float) || is(T == double) || is(T == real))
{
	pure nothrow @safe:

    bool equals(T f1, T f2)
    {
        return f1 == f2;
    }

    int compare(T d1, T d2)
    {
        if (d1 != d1 || d2 != d2) // if either are NaN
        {
            if (d1 != d1)
            {
                if (d2 != d2)
                    return 0;
                return -1;
            }
            return 1;
        }
        return (d1 == d2) ? 0 : ((d1 < d2) ? -1 : 1);
    }
}

// @@@DEPRECATED_2.105@@@
template Floating(T)
if (isComplex!T)
{
	pure nothrow @safe:

    bool equals(T f1, T f2)
    {
        return f1.re == f2.re && f1.im == f2.im;
    }

    int compare(T f1, T f2)
    {
        int result;

        if (f1.re < f2.re)
            result = -1;
        else if (f1.re > f2.re)
            result = 1;
        else if (f1.im < f2.im)
            result = -1;
        else if (f1.im > f2.im)
            result = 1;
        else
            result = 0;
        return result;
    }

    size_t hashOf(scope const T val)
    {
        return 0;
        //return core.internal.hash.hashOf(val.re, core.internal.hash.hashOf(val.im));
    }
}

template Array(T)
if (is(T == float) || is(T == double) || is(T == real))
{
	pure nothrow @safe:

    bool equals(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!Floating!T.equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    int compare(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (int c = Floating!T.compare(s1[u], s2[u]))
                return c;
        }
        return (s1.length > s2.length) - (s1.length < s2.length);
    }

    //public alias hashOf = core.internal.hash.hashOf;
}

// @@@DEPRECATED_2.105@@@
template Array(T)
if (isComplex!T)
{
	pure nothrow @safe:

    bool equals(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (len != s2.length)
            return false;
        for (size_t u = 0; u < len; u++)
        {
            if (!Floating!T.equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    int compare(T[] s1, T[] s2)
    {
        size_t len = s1.length;
        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (int c = Floating!T.compare(s1[u], s2[u]))
                return c;
        }
        return (s1.length > s2.length) - (s1.length < s2.length);
    }

    size_t hashOf(scope const T[] val)
    {
        return 0;
        /+size_t hash = 0;
        foreach (ref o; val)
        {
            hash = core.internal.hash.hashOf(Floating!T.hashOf(o), hash);
        }
        return hash;+/
    }
}


private struct _Complex(T) { T re; T im; }

private enum __c_complex_float : _Complex!float;
private enum __c_complex_double : _Complex!double;
private enum __c_complex_real : _Complex!real;  // This is why we don't use stdc.config

private alias d_cfloat = __c_complex_float;
private alias d_cdouble = __c_complex_double;
private alias d_creal = __c_complex_real;

private enum isComplex(T) = is(T == d_cfloat) || is(T == d_cdouble) || is(T == d_creal);

/*
TypeInfo information for built-in types.
A `Base` type may be specified, which must be a type with the same layout, alignment, hashing, and
equality comparison as type `T`. This saves on code size because parts of `Base` will be reused. Example:
`char` and `ubyte`. The implementation assumes `Base` and `T` hash the same, swap
the same, have the same ABI flags, and compare the same for equality. For ordering comparisons, we detect
during compilation whether they have different signedness and override appropriately. For initializer, we
detect if we need to override. The overriding initializer should be nonzero.
*/
private class TypeInfoGeneric(T, Base = T) : Select!(is(T == Base), TypeInfo, TypeInfoGeneric!Base)
if (T.sizeof == Base.sizeof && T.alignof == Base.alignof)
{
const: nothrow: pure: @trusted:

    // Returns the type name.
    override string toString() const pure nothrow @safe { return T.stringof; }

    // `getHash` is the same for `Base` and `T`, introduce it just once.
    static if (is(T == Base))
        /+override size_t getHash(scope const void* p)
        {
            static if (__traits(isFloating, T) || isComplex!T)
                return Floating!T.hashOf(*cast(T*)p);
            else
                return hashOf(*cast(const T *)p);
        }+/

    // `equals` is the same for `Base` and `T`, introduce it just once.
    static if (is(T == Base))
        override bool equals(in void* p1, in void* p2)
        {
            static if (__traits(isFloating, T) || isComplex!T)
                return Floating!T.equals(*cast(T*)p1, *cast(T*)p2);
            else
                return *cast(T *)p1 == *cast(T *)p2;
        }

    // `T` and `Base` may have different signedness, so this function is introduced conditionally.
    static if (is(T == Base) || (__traits(isIntegral, T) && T.max != Base.max))
        /+override int compare(in void* p1, in void* p2)
        {
            static if (__traits(isFloating, T) || isComplex!T)
            {
                return Floating!T.compare(*cast(T*)p1, *cast(T*)p2);
            }
            else static if (T.sizeof < int.sizeof)
            {
                // Taking the difference will always fit in an int.
                return int(*cast(T *) p1) - int(*cast(T *) p2);
            }
            else
            {
                auto lhs = *cast(T *) p1, rhs = *cast(T *) p2;
                return (lhs > rhs) - (lhs < rhs);
            }
        +/

    static if (is(T == Base))
        override @property size_t tsize() nothrow pure
        {
            return T.sizeof;
        }

    static if (is(T == Base))
        /+override @property size_t talign() nothrow pure
        {
            return T.alignof;
        }+/

    // Override initializer only if necessary.
    static if (is(T == Base) || T.init != Base.init)
        override const(void)[] initializer() @trusted
        {
            static if (__traits(isZeroInit, T))
            {
                return (cast(void *)null)[0 .. T.sizeof];
            }
            else
            {
                static immutable T[1] c;
                return c;
            }
        }

    // `swap` is the same for `Base` and `T`, so introduce only once.
    static if (is(T == Base))
        /+override void swap(void *p1, void *p2)
        {
            auto t = *cast(T *) p1;
            *cast(T *)p1 = *cast(T *)p2;
            *cast(T *)p2 = t;
        }+/

    static if (is(T == Base) || RTInfo!T != RTInfo!Base)
        /+override @property immutable(void)* rtInfo() nothrow pure const @safe
        {
            return RTInfo!T;
        }+/

    static if (is(T == Base))
    {
        /+static if ((__traits(isFloating, T) && T.mant_dig != 64) ||
                   (isComplex!T && T.re.mant_dig != 64))
            // FP types except 80-bit X87 are passed in SIMD register.
            override @property uint flags() const { return 2; }+/
    }
}


/*
TypeInfo information for arrays of built-in types.
A `Base` type may be specified, which must be a type with the same layout, alignment, hashing, and
equality comparison as type `T`. This saves on code size because parts of `Base` will be reused. Example:
`char` and `ubyte`. The implementation assumes `Base` and `T` hash the same, swap
the same, have the same ABI flags, and compare the same for equality. For ordering comparisons, we detect
during compilation whether they have different signedness and override appropriately. For initializer, we
detect if we need to override. The overriding initializer should be nonzero.
*/
private class TypeInfoArrayGeneric(T, Base = T) : Select!(is(T == Base), TypeInfo_Array, TypeInfoArrayGeneric!Base)
{
    static if (is(T == Base))
        override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override string toString() const { return (T[]).stringof; }

    /+static if (is(T == Base)) {
        override size_t getHash(scope const void* p) @trusted const
        {
            return 0;
        }
    }+/

    static if (is(T == Base)) {
        override bool equals(in void* p1, in void* p2) const
        {
            static if (__traits(isFloating, T) || isComplex!T)
            {
                return Array!T.equals(*cast(T[]*)p1, *cast(T[]*)p2);
            }
            else
            {
                import core.stdc.string;
                auto s1 = *cast(T[]*)p1;
                auto s2 = *cast(T[]*)p2;
                return s1.length == s2.length &&
                    memcmp(s1.ptr, s2.ptr, s1.length) == 0;
            }
        }
    }

    static if (is(T == Base) || (__traits(isIntegral, T) && T.max != Base.max)) {
        /+override int compare(in void* p1, in void* p2) const
        {
            static if (__traits(isFloating, T) || isComplex!T)
            {
                return Array!T.compare(*cast(T[]*)p1, *cast(T[]*)p2);
            }
            else
            {
                auto s1 = *cast(T[]*)p1;
                auto s2 = *cast(T[]*)p2;
                auto len = s1.length;

                if (s2.length < len)
                    len = s2.length;
                for (size_t u = 0; u < len; u++)
                {
                    if (int result = (s1[u] > s2[u]) - (s1[u] < s2[u]))
                        return result;
                }
                return (s1.length > s2.length) - (s1.length < s2.length);
            }
        }+/
	}

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout) typeid(T);
    }
}

// void
class TypeInfo_v : TypeInfoGeneric!ubyte
{
const: nothrow: pure: @trusted:

    override string toString() const pure nothrow @safe { return "void"; }

    /+override size_t getHash(scope const void* p)
    {
        assert(0);
    }

    override @property uint flags() nothrow pure
    {
        return 1;
    }

    unittest
    {
        assert(typeid(void).toString == "void");
        assert(typeid(void).flags == 1);
    }+/
}

class TypeInfo_h : TypeInfoGeneric!ubyte {}
class TypeInfo_b : TypeInfoGeneric!(bool, ubyte) {}
class TypeInfo_g : TypeInfoGeneric!(byte, ubyte) {}
class TypeInfo_a : TypeInfoGeneric!(char, ubyte) {}
class TypeInfo_t : TypeInfoGeneric!ushort {}
class TypeInfo_s : TypeInfoGeneric!(short, ushort) {}
class TypeInfo_u : TypeInfoGeneric!(wchar, ushort) {}
class TypeInfo_w : TypeInfoGeneric!(dchar, uint) {}
class TypeInfo_k : TypeInfoGeneric!uint {}
class TypeInfo_i : TypeInfoGeneric!(int, uint) {}
class TypeInfo_m : TypeInfoGeneric!ulong {}
class TypeInfo_l : TypeInfoGeneric!(long, ulong) {}
static if (is(cent)) class TypeInfo_zi : TypeInfoGeneric!cent {}
static if (is(ucent)) class TypeInfo_zk : TypeInfoGeneric!ucent {}

// All simple floating-point types.
class TypeInfo_f : TypeInfoGeneric!float {}
class TypeInfo_d : TypeInfoGeneric!double {}
class TypeInfo_e : TypeInfoGeneric!real {}

class TypeInfo_Ah : TypeInfoArrayGeneric!ubyte {}
class TypeInfo_Ab : TypeInfoArrayGeneric!(bool, ubyte) {}
class TypeInfo_Ag : TypeInfoArrayGeneric!(byte, ubyte) {}
class TypeInfo_Aa : TypeInfoArrayGeneric!(char, ubyte) {}
class TypeInfo_Axa : TypeInfoArrayGeneric!(const char) {}
class TypeInfo_Aya : TypeInfoArrayGeneric!(immutable char)
{
    // Must override this, otherwise "string" is returned.
    override string toString() const { return "immutable(char)[]"; }
}
class TypeInfo_At : TypeInfoArrayGeneric!ushort {}
class TypeInfo_As : TypeInfoArrayGeneric!(short, ushort) {}
class TypeInfo_Au : TypeInfoArrayGeneric!(wchar, ushort) {}
class TypeInfo_Ak : TypeInfoArrayGeneric!uint {}
class TypeInfo_Ai : TypeInfoArrayGeneric!(int, uint) {}
class TypeInfo_Aw : TypeInfoArrayGeneric!(dchar, uint) {}
class TypeInfo_Am : TypeInfoArrayGeneric!ulong {}
class TypeInfo_Al : TypeInfoArrayGeneric!(long, ulong) {}

// Arrays of all simple floating-point types.
class TypeInfo_Af : TypeInfoArrayGeneric!float {}
class TypeInfo_Ad : TypeInfoArrayGeneric!double {}
class TypeInfo_Ae : TypeInfoArrayGeneric!real {}

// typeof(null)
class TypeInfo_n : TypeInfo
{
    override string toString() const @safe { return "typeof(null)"; }

    /+override size_t getHash(scope const void* p) const
    {
        return 0;
    }+/

    override bool equals(in void* p1, in void* p2) const @trusted
    {
        return true;
    }

    /+override int compare(in void* p1, in void* p2) const @trusted
    {
        return 0;
    }+/

    override @property size_t tsize() const
    {
        return typeof(null).sizeof;
    }

    override const(void)[] initializer() const @trusted
    {
        __gshared immutable void[typeof(null).sizeof] init;
        return init;
    }

    /+override void swap(void *p1, void *p2) const @trusted
    {
    }+/

    //override @property immutable(void)* rtInfo() nothrow pure const @safe { return rtinfoNoPointers; }

    unittest
    {
        with (typeid(typeof(null)))
        {
            assert(toString == "typeof(null)");
            assert(getHash(null) == 0);
            assert(equals(null, null));
            assert(compare(null, null) == 0);
            assert(tsize == typeof(null).sizeof);
            assert(initializer == new ubyte[(void*).sizeof]);
            assert(rtInfo == rtinfoNoPointers);
        }
    }
}

// void[] is a bit different, behaves like ubyte[] for comparison purposes.
class TypeInfo_Av : TypeInfo_Ah
{
    override string toString() const { return "void[]"; }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout) typeid(void);
    }

    unittest
    {
        assert(typeid(void[]).toString == "void[]");
        assert(typeid(void[]).next == typeid(void));
    }
}

// Used in Exception Handling LSDA tables to 'wrap' C++ type info
// so it can be distinguished from D TypeInfo
class __cpp_type_info_ptr
{
    void* ptr;          // opaque pointer to C++ RTTI type info
}
