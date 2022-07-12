module lifetime.destruction;

//Copy pasted from druntime

void __ArrayDtor(T)(scope T[] a)
{
    foreach_reverse (ref T e; a)
        e.__xdtor();
}

public void destructRecurse(E, size_t n)(ref E[n] arr)
{
    import core.internal.traits : hasElaborateDestructor;

    static if (hasElaborateDestructor!E)
    {
        foreach_reverse (ref elem; arr)
            destructRecurse(elem);
    }
}

public void destructRecurse(S)(ref S s)
    if (is(S == struct))
{
    static if (__traits(hasMember, S, "__xdtor") &&
            // Bugzilla 14746: Check that it's the exact member of S.
            __traits(isSame, S, __traits(parent, s.__xdtor)))
        s.__xdtor();
}