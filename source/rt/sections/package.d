module rt.sections;

version(LWDR_ModuleCtors):

version(ARM)
{
	version(LDC)
		public import rt.sections.ldc;
	else static assert(0, "Module info not supported on this platform");
}
else static assert(0, "Module info not supported on this platform");