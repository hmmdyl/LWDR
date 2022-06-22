module object;

import util;
import rtoslink;
import lifetime.throwable;



version(LWDR_DynamicArray)
public import lifetime.array_ : _d_arraysetlengthTImpl, _d_newarrayU;


public import core.internal.switch_ : __switch_error; //final switch


public import rt.arrcast : __ArrayCast;

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

private U[] _dup(T, U)(T[] a) // pure nothrow depends on postblit
{
    if (__ctfe)
    {
        static if (is(T : void))
            assert(0, "Cannot dup a void[] array at compile time.");
        else
        {
            U[] res;
            foreach (ref e; a)
                res ~= e;
            return res;
        }
    }

    import core.stdc.string : memcpy;

    void[] arr = _d_newarrayU(typeid(T[]), a.length);
    memcpy(arr.ptr, cast(const(void)*)a.ptr, T.sizeof * a.length);
    auto res = *cast(U[]*)&arr;

    static if (__traits(hasPostblit, T))
        _doPostblit(res);
    return res;
}

@property T[] dup(T)(const(T)[] a)
    if (is(const(T) : T))
{
    return _dup!(const(T), T)(a);
}


/// Provide the .idup array property.
@property immutable(T)[] idup(T)(T[] a)
{
    static assert(is(T : immutable(T)), "Cannot implicitly convert type "~T.stringof~
                  " to immutable in idup.");
    return _dup!(T, immutable(T))(a);
}

/// ditto
@property immutable(T)[] idup(T:void)(const(T)[] a)
{
    return a.dup;
}



/// assert(bool exp) was called
extern(C) void _d_assert(string f, uint l) { rtosbackend_assert(f, l); }
/// assert(bool exp, string msg) was called
extern(C) void _d_assert_msg(string msg, string f, uint l) { rtosbackend_assertmsg(msg, f, l); }
/// A D array was incorrectly accessed
extern(C) void _d_arraybounds(string f, size_t l) {rtosbackend_arrayBoundFailure(f, l);}

/// Called when an out of range slice of an array is created
extern(C) void _d_arraybounds_slice(string file, uint line, size_t, size_t, size_t)
{
    // Ignore additional information for now
    _d_arraybounds(file, line);
}

/// Called when an out of range array index is accessed
extern(C) void _d_arraybounds_index(string file, uint line, size_t, size_t)
{
    // Ignore additional information for now
    _d_arraybounds(file, line);
}



extern(C) bool _xopEquals(in void*, in void*) { return false; }
extern(C) int _xopCmp(in void*, in void*) { return 0; }

template _arrayOp(Args...)
{
    import core.internal.array.operations;
    alias _arrayOp = arrayOp!Args;
}


/// Base Object class. All other classes implicitly inherit this.
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
	
    /// Compare against another object. NOT IMPLEMENTED!
	int opCmp(Object o) { assert(false, "not implemented"); }
    /// Check equivalence againt another object
	bool opEquals(Object o) { return this is o; }
	
    /++ Object factory. NOT IMPLEMENTED!
    ++/
	static Object factory(string classname) { return null; }

    version(LWDR_Sync)
	{
        interface Monitor 
	    {
            /// Lock the monitor
            void lock();
            /// Unlock the monitor
            void unlock();
	    }
	}
}

/// Compare to objects
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

/// Raw implementation of an interface
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

/// TypeInfo contains necessary RTTI for a target type.
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

// Contents of Moduleinfo._flags
enum
{
    MIctorstart  = 0x1,   // we've started constructing it
    MIctordone   = 0x2,   // finished construction
    MIstandalone = 0x4,   // module ctor does not depend on other module
	// ctors being done first
    MItlsctor    = 8,
    MItlsdtor    = 0x10,
    MIctor       = 0x20,
    MIdtor       = 0x40,
    MIxgetMembers = 0x80,
    MIictor      = 0x100,
    MIunitTest   = 0x200,
    MIimportedModules = 0x400,
    MIlocalClasses = 0x800,
    MIname       = 0x1000,
}

/*****************************************
* An instance of ModuleInfo is generated into the object file for each compiled module.
*
* It provides access to various aspects of the module.
* It is not generated for betterC.
*/
version(LWDR_ModuleCtors)
struct ModuleInfo
{
    uint _flags; // MIxxxx
    uint _index; // index into _moduleinfo_array[]

    version (all)
    {
        deprecated("ModuleInfo cannot be copy-assigned because it is a variable-sized struct.")
			void opAssign(const scope ModuleInfo m) { _flags = m._flags; _index = m._index; }
    }
    else
    {
        @disable this();
    }

const:
    private void* addrOf(int flag) return nothrow pure @nogc
		in
		{
			assert(flag >= MItlsctor && flag <= MIname);
			assert(!(flag & (flag - 1)) && !(flag & ~(flag - 1) << 1));
		}
    do
    {
        import core.stdc.string : strlen;

        void* p = cast(void*)&this + ModuleInfo.sizeof;

        if (flags & MItlsctor)
        {
            if (flag == MItlsctor) return p;
            p += typeof(tlsctor).sizeof;
        }
        if (flags & MItlsdtor)
        {
            if (flag == MItlsdtor) return p;
            p += typeof(tlsdtor).sizeof;
        }
        if (flags & MIctor)
        {
            if (flag == MIctor) return p;
            p += typeof(ctor).sizeof;
        }
        if (flags & MIdtor)
        {
            if (flag == MIdtor) return p;
            p += typeof(dtor).sizeof;
        }
        if (flags & MIxgetMembers)
        {
            if (flag == MIxgetMembers) return p;
            p += typeof(xgetMembers).sizeof;
        }
        if (flags & MIictor)
        {
            if (flag == MIictor) return p;
            p += typeof(ictor).sizeof;
        }
        if (flags & MIunitTest)
        {
            if (flag == MIunitTest) return p;
            version(unittest)
                p += typeof(unitTest).sizeof;
            else
                p += (void function()).sizeof;
        }
        if (flags & MIimportedModules)
        {
            if (flag == MIimportedModules) return p;
            p += size_t.sizeof + *cast(size_t*)p * typeof(importedModules[0]).sizeof;
        }
        if (flags & MIlocalClasses)
        {
            if (flag == MIlocalClasses) return p;
            p += size_t.sizeof + *cast(size_t*)p * typeof(localClasses[0]).sizeof;
        }
        if (true || flags & MIname) // always available for now
        {
            if (flag == MIname) return p;
            p += strlen(cast(immutable char*)p);
        }
        assert(0);
    }

    @property uint index() nothrow pure @nogc { return _index; }

    @property uint flags() nothrow pure @nogc { return _flags; }

    /************************
	* Returns:
	*  module constructor for thread locals, `null` if there isn't one
	*/
    @property void function() tlsctor() nothrow pure @nogc
    {
        return flags & MItlsctor ? *cast(typeof(return)*)addrOf(MItlsctor) : null;
    }

    /************************
	* Returns:
	*  module destructor for thread locals, `null` if there isn't one
	*/
    @property void function() tlsdtor() nothrow pure @nogc
    {
        return flags & MItlsdtor ? *cast(typeof(return)*)addrOf(MItlsdtor) : null;
    }

    /*****************************
	* Returns:
	*  address of a module's `const(MemberInfo)[] getMembers(string)` function, `null` if there isn't one
	*/
    @property void* xgetMembers() nothrow pure @nogc
    {
        return flags & MIxgetMembers ? *cast(typeof(return)*)addrOf(MIxgetMembers) : null;
    }

    /************************
	* Returns:
	*  module constructor, `null` if there isn't one
	*/
    @property void function() ctor() nothrow pure @nogc
    {
        return flags & MIctor ? *cast(typeof(return)*)addrOf(MIctor) : null;
    }

    /************************
	* Returns:
	*  module destructor, `null` if there isn't one
	*/
    @property void function() dtor() nothrow pure @nogc
    {
        return flags & MIdtor ? *cast(typeof(return)*)addrOf(MIdtor) : null;
    }

    /************************
	* Returns:
	*  module order independent constructor, `null` if there isn't one
	*/
    @property void function() ictor() nothrow pure @nogc
    {
        return flags & MIictor ? *cast(typeof(return)*)addrOf(MIictor) : null;
    }

    /*************
	* Returns:
	*  address of function that runs the module's unittests, `null` if there isn't one
	*/
    version(unittest)
    @property void function() unitTest() nothrow pure @nogc
    {
        return flags & MIunitTest ? *cast(typeof(return)*)addrOf(MIunitTest) : null;
    }

    /****************
	* Returns:
	*  array of pointers to the ModuleInfo's of modules imported by this one
	*/
    @property immutable(ModuleInfo*)[] importedModules() return nothrow pure @nogc
    {
        if (flags & MIimportedModules)
        {
            auto p = cast(size_t*)addrOf(MIimportedModules);
            return (cast(immutable(ModuleInfo*)*)(p + 1))[0 .. *p];
        }
        return null;
    }

    /****************
	* Returns:
	*  array of TypeInfo_Class references for classes defined in this module
	*/
    @property TypeInfo_Class[] localClasses() return nothrow pure @nogc
    {
        if (flags & MIlocalClasses)
        {
            auto p = cast(size_t*)addrOf(MIlocalClasses);
            return (cast(TypeInfo_Class*)(p + 1))[0 .. *p];
        }
        return null;
    }

    /********************
	* Returns:
	*  name of module, `null` if no name
	*/
    @property string name() return nothrow pure @nogc
    {
        import core.stdc.string : strlen;

        auto p = cast(immutable char*) addrOf(MIname);
        return p[0 .. strlen(p)];
    }
}