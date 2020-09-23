module object;

import util;
import rtoslink;

alias string = immutable(char)[];
alias size_t = uint;

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
	
	int opCmp(Object o) { return 0; }
	bool opEquals(Object o) { return this is o; }
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
	TypeInfo_Class classinfo;
	void*[] vtbl;
	size_t offset;
}

struct OffsetTypeInfo
{
	size_t offset;
	TypeInfo ti;
}
//enum immutable(void)* rtinfoHasPointers = cast(void*)1;

class TypeInfo 
{
	/+size_t getHash(scope const void* p) @trusted nothrow const { return 0; }
	bool equals(in void* p1, in void* p2) const { return p1 == p2; }
	int compare(in void* p1, in void* p2) const { return 0; }
	@property size_t tsize() nothrow pure const @safe @nogc { return 0; }
	void swap(void* p1, void* p2) const {}
	@property inout(TypeInfo) next() nothrow pure inout @nogc { return null; }
	
	version(LDC)
	{
		const(void)[] initializer() nothrow pure const @trusted @nogc
		{
			return (cast(const(void)*) null)[0 .. typeof(null).sizeof];
		}
	}
	else
	{
		abstract const(void)[] initializer() nothrow pure const @safe @nogc;
	}

	@property uint flags() nothrow pure const @safe @nogc { return 0; }
	const(OffsetTypeInfo)[] offTi() const { return null; }
	void destroy(void* p) const {}
	void postblit(void* p) const {}
	
	@property size_t talign() nothrow pure const @safe @nogc { return tsize; }
	@property immutable(void)* rtInfo() nothrow pure const @safe @nogc { return rtinfoHasPointers; } +/
}

class TypeInfo_Enum : TypeInfo {
	TypeInfo base;
	string name;
	void[] m_init; 
	
	/+override string toString() const { return name; }

    override bool opEquals(Object o)
    {
        if (this is o)
            return true;
        auto c = cast(const TypeInfo_Enum)o;
        return c && this.name == c.name &&
                    this.base == c.base;
    }

    override size_t getHash(scope const void* p) const { return base.getHash(p); }
    override bool equals(in void* p1, in void* p2) const { return base.equals(p1, p2); }
    override int compare(in void* p1, in void* p2) const { return base.compare(p1, p2); }
    override @property size_t tsize() nothrow pure const { return base.tsize; }
    override void swap(void* p1, void* p2) const { return base.swap(p1, p2); }

    override @property inout(TypeInfo) next() nothrow pure inout { return base.next; }
    override @property uint flags() nothrow pure const { return base.flags; }

    override const(void)[] initializer() const
    {
        return m_init.length ? m_init : base.initializer();
    }

    override @property size_t talign() nothrow pure const { return base.talign; }
	override @property immutable(void)* rtInfo() const { return base.rtInfo; }+/
}

class TypeInfo_Pointer : TypeInfo 
{ 
TypeInfo m_next; 
}

class TypeInfo_Array : TypeInfo {
	TypeInfo value;
}

class TypeInfo_StaticArray : TypeInfo { 
	TypeInfo value;
	size_t len;
}

class TypeInfo_AssociativeArray : TypeInfo {
	TypeInfo value, key;
}

class TypeInfo_Function : TypeInfo {
	string deco;
}

class TypeInfo_Delegate : TypeInfo {
	string deco; 
}

class TypeInfo_Interface : TypeInfo 
{
	TypeInfo_Class info;
	
	/+override string toString() const { return info.name; }
	override bool opEquals(Object o)
	{
		if(this is o) return true;
		auto c = cast(const TypeInfo_Interface)o;
		return c && this.info.name == typeid(c).name;
	}
	override size_t getHash(scope const void* p) @trusted const
	{
		if(!*cast(void**)p) return 0;
		Interface* pi = **cast(Interface ***)*cast(void**)p;
		Object o = cast(Object)(*cast(void**)p - pi.offset);
		return o.toHash();
	}
	override bool equals(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);

        return o1 == o2 || (o1 && o1.opCmp(o2) == 0);
    }
    override int compare(in void* p1, in void* p2) const
    {
        Interface* pi = **cast(Interface ***)*cast(void**)p1;
        Object o1 = cast(Object)(*cast(void**)p1 - pi.offset);
        pi = **cast(Interface ***)*cast(void**)p2;
        Object o2 = cast(Object)(*cast(void**)p2 - pi.offset);
        int c = 0;

        // Regard null references as always being "less than"
        if (o1 != o2)
        {
            if (o1)
            {
                if (!o2)
                    c = 1;
                else
                    c = o1.opCmp(o2);
            }
            else
                c = -1;
        }
        return c;
    }
    override @property size_t tsize() nothrow pure const
    {
        return Object.sizeof;
    }
    override const(void)[] initializer() const @trusted
    {
        return (cast(void *)null)[0 .. Object.sizeof];
    }
    override @property uint flags() nothrow pure const { return 1; }+/
}

class TypeInfo_Class : TypeInfo {
	//override string toString() const { return name; }

	ubyte[] m_init; /// class static initializer (length gives class size)
	string name; /// name of class
	void*[] vtbl; // virtual function pointer table
	void*[] interfaces;
	TypeInfo_Class base;
	void* destructor;
	void function(Object) classInvariant;
	uint m_flags;
	void* deallocator;
	void*[] m_offTi;
	void function(Object) defaultConstructor;
	immutable(void)* rtInfo;
}
alias ClassInfo = TypeInfo_Class;

class TypeInfo_Const : TypeInfo {
	size_t getHash(scope const void*) const nothrow { return 0; }
	/* Fixes error:
	 Error: TypeInfo_Const: mismatch between compiler (12 bytes) 
	 and object.d or object.di (8 bytes) found. Check 
	 installation and import paths with -v compiler switch.
	 */
	void* p; 
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