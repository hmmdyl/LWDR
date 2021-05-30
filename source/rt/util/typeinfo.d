module rt.util.typeinfo;

import rt.util.utility;

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