module invariant_;

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
