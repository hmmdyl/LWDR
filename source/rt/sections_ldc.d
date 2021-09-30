module rt.sections_ldc;

version(LDC):
pragma(LDC_no_moduleinfo);

/// A linked list of ModuleInfos
private extern(C) __gshared ModuleRef* _Dmodule_ref;

private struct ModuleRef
{
	ModuleRef* next; /// next node in linked list
	immutable(ModuleInfo)* moduleInfo;
}

void runCtors() nothrow
{
	ModuleRef* mref = _Dmodule_ref;
	do
	{
		auto ct = cast(void function() nothrow)mref.moduleInfo.ctor;
		if(ct !is null)
			ct();
	} while((mref = mref.next) !is null);
}