module invariant_;

/// Invokes o`s and derived classes invariant(s).
extern(D) void _d_invariant(Object o)
{
	ClassInfo c;

	assert(o !is null);

	c = typeid(o);
	do
	{
		if(c.classInvariant)
			(*c.classInvariant)(o);
		c = c.base;
	} while(c);
}
