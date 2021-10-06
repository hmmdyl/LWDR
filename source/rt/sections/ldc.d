module rt.sections.ldc;

version(LWDR_ModuleCtors):

version(LDC):
pragma(LDC_no_moduleinfo);

/// A linked list of ModuleInfos
private extern(C) __gshared ModuleRef* _Dmodule_ref;

private struct ModuleRef
{
	ModuleRef* next; /// next node in linked list
	immutable(ModuleInfo)* moduleInfo;
}

/// Returns a range over all modules present. 
auto allModules() nothrow @nogc
{
	static struct Modules
	{
		nothrow @nogc:
		ModuleRef* current;
		this(ModuleRef* c) { this.current = c; }

		@property bool empty() const { return current is null; }

		immutable(ModuleInfo)* front()
		{ return current.moduleInfo; }

		void popFront()
		{ current = current.next; }
	}
	return Modules(_Dmodule_ref);
}