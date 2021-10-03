module rt.arrcast;

version(LDC)
	pragma(LDC_no_moduleinfo);

/++
Compiler lowers cast(TTo[])TFrom[] to this implementation. It reinterprets the given parameter. No new allocations.
++/
TTo[] __ArrayCast(TFrom, TTo)(return scope TFrom[] from) @nogc pure @trusted
{
	immutable fromSize = from.length * TFrom.sizeof;
	immutable toLength = fromSize / TTo.sizeof;

	if((fromSize % TTo.sizeof) != 0)
		assert(false, "Array cast fail.");

	struct Array
	{
		size_t length;
		void* ptr;
	}
	auto a = cast(Array*)&from;
	a.length = toLength;
	return *cast(TTo[]*)a;
}