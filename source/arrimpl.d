module arrimpl;

extern(C) void[] _d_arraycopy(size_t size, void[] from, void[] to) nothrow @nogc
{
    auto fromBytes = cast(ubyte[])from;
    auto toBytes = cast(ubyte[])to;

    foreach(size_t i; 0 .. size)
        toBytes[i] = fromBytes[i];

    return to;
}

extern(C) int _adEq2(void[] a1, void[] a2, TypeInfo ti) 
{
    if(a1.length != a2.length) return 0;
    if(!ti.equals(&a1, &a2)) return 0;

    return 1;
}