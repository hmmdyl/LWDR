module lwdr;

static final class LWDR
{
	version(LWDR_TLS)
	{
		static void registerCurrentThread() nothrow @nogc
		{
			import rt.sections;
			initTLSRanges();
		}
	}
}