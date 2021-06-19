module lwdr.util.traits;

/// Get the base type of T
private template rootType(T)
{
	static if(is(T == class) || is(T == interface))
		alias rootType = T;
	static if(is(T == U*, U))
	{
		private alias inner(T : U*) = U;
		alias rootType = inner!T;
	}
	static if(is(T == U[], U))
	{
		private alias inner(T : U[]) = U;
		alias rootType = inner!T;
	}
}