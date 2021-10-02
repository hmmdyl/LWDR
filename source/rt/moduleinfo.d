module rt.moduleinfo;
pragma(LDC_no_moduleinfo):

import rt.sections_ldc;
import lwdr.tracking;

version(LWDR_ModuleCtors):

private __gshared immutable(ModuleInfo*)[] modules;
private __gshared immutable(ModuleInfo)*[] ctors;
private __gshared immutable(ModuleInfo)*[] tlsctors;

private immutable(ModuleInfo*)[] getModules()
out(result) {
	foreach(r; result)
		assert(r !is null);
}
do {
	size_t count;
	foreach(m; allModules)
		count++;

	auto result = cast(immutable(ModuleInfo)*[])lwdrInternal_allocBytes(size_t.sizeof * count);
	size_t i;
	foreach(m; allModules)
		result[i++] = m;
	return cast(immutable)result;
}

void sortCtors()
{
	immutable len = modules.length;
	if(len == 0) 
		return; // nothing to do

	
}

extern(C)
{
	void __lwdr_moduleInfo_runModuleCtors()
	{
		modules = getModules;
	}
}