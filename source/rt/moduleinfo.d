module rt.moduleinfo;
pragma(LDC_no_moduleinfo):

import rt.sections;
import lwdr.tracking;
import lwdr.internal.unionset;

version(LWDR_ModuleCtors):

//extern(C) int _d_eh_personality(int, void*, void*) { return 0; }

private __gshared immutable(ModuleInfo*)[] modules;
private __gshared immutable(ModuleInfo)*[] ctors;
private __gshared immutable(ModuleInfo)*[] tlsctors;

private immutable(ModuleInfo*)[] getModules() nothrow @nogc
out(result) {
	foreach(r; result)
		assert(r !is null);
}
do {
	size_t count;
	foreach(m; allModules)
		count++;

	immutable(ModuleInfo)*[] result = (cast(immutable(ModuleInfo)**)lwdrInternal_alloc(size_t.sizeof * count))[0..count];
	size_t i;
	foreach(m; allModules)
		result[i++] = m;
	return cast(immutable)result;
}

void sortCtors() nothrow @nogc
{
	import core.bitop : bts, btr, bt, BitRange;

	immutable len = modules.length;
	if(len == 0) 
		return; // nothing to do

	// allocate some stack arrays that will be used throughout the process.
	immutable nwords = (len + 8 * size_t.sizeof - 1) / (8 * size_t.sizeof);
	immutable flagbytes = nwords * size_t.sizeof;
	auto ctorstart = cast(size_t*)lwdrInternal_alloc(flagbytes); // ctor/dtor seen
	auto ctordone = cast(size_t*)lwdrInternal_alloc(flagbytes); // ctor/dtor processed
	auto relevant = cast(size_t*)lwdrInternal_alloc(flagbytes); // has ctors/dtors
	scope(exit)
	{
		lwdrInternal_free(ctorstart);
		lwdrInternal_free(ctordone);
		lwdrInternal_free(relevant);
	}

	void clearFlags(size_t* flags) @nogc nothrow
	{
		import util;
		memset(flags, 0, flagbytes);
	}

	// build the edges between each module. We may need this for printing,
	// and also allows avoiding keeping a hash around for module lookups.
	int[][] edges = (cast(int[]*)lwdrInternal_alloc((int[]).sizeof * modules.length))[0 .. modules.length];
	{
		LLUnionSet modIndexes = LLUnionSet(modules.length);
		foreach(i, m; modules)
			modIndexes[cast(size_t)m] = i;
		
		auto reachable = cast(size_t*)lwdrInternal_alloc(flagbytes);
		scope(exit) lwdrInternal_free(reachable);

		foreach(i, m; modules)
		{
			clearFlags(reachable);
			int* edge = cast(int*)lwdrInternal_alloc(int.sizeof * modules.length);
			size_t nEdges = 0;
			foreach(imp; m.importedModules)
			{
				if(imp is m)
					continue; // self-import
				if(auto impidx = cast(size_t)imp in modIndexes)
					if(!bts(reachable, *impidx))
						edge[nEdges++] = *impidx;
			}
			edges[i] = edge[0 .. nEdges];
			// cannot trim edges[i]
		}
	}

	scope(exit)
	{
		foreach(e; edges)
			if(e.ptr)
				lwdrInternal_free(e.ptr);
		lwdrInternal_free(edges.ptr);
	}

	/++ find all the non-trivial dependencies (that is, dependencies that have a
	 ctor or dtor) of a given module.  Doing this, we can 'skip over' the
	 trivial modules to get at the non-trivial ones.
	 If a cycle is detected, returns the index of the module that completes the cycle.
	 Returns: true for success, false for a deprecated cycle error ++/
	bool findDeps(size_t idx, size_t* reachable) nothrow @nogc
	{
		static struct StackFrame
		{
			size_t curMod, curDep;
		}

		auto stack = cast(StackFrame*)lwdrInternal_alloc(StackFrame.sizeof * len);
		scope(exit) lwdrInternal_free(stack);
		auto stackTop = stack + len;
		auto sp = stack;
		sp.curMod = cast(int)idx;
		sp.curDep = 0;

		clearFlags(reachable);
		bts(reachable, idx);

		for(;;)
		{
			auto m = modules[sp.curMod];
			if(sp.curDep >= edges[sp.curMod].length)
			{
				if(sp == stack) // finished the algorithm
					break;
				--sp;
			} 
			else
			{
				auto midx = edges[sp.curMod][sp.curDep];
				if(!bts(reachable, midx))
				{
					if(bt(relevant, midx))
					{
						// need to process this node, don't recurse.
						if(bt(ctorstart, midx))
						{
							// was already started, this is a cycle.
							assert(false, "Module cycle detected!");
						}
					}
					else if(!bt(ctordone, midx))
					{
						 // non-relevant, and hasn't been exhaustively processed, recurse.
						if(++sp >= stackTop)
							assert(false, "Stack overflow on module dependency search!");  // stack overflow, this shouldn't happen.
						sp.curMod = midx;
						sp.curDep = 0;
						continue;
					}
				}
			}
			// next depedency
			++sp.curDep;
		}
		return true;
	}

	// This function will determine the order of construction/destruction and
	// check for cycles. If a cycle is found, the cycle path is transformed
	// into a string and thrown as an error.
	//
	// Each call into this function is given a module that has static
	// ctor/dtors that must be dealt with. It recurses only when it finds
	// dependencies that also have static ctor/dtors.
	// Returns: true for success, false for a deprecated cycle error
	bool processMod(size_t curidx, immutable(ModuleInfo)** c, ref size_t ctoridx) nothrow @nogc
	{
		immutable ModuleInfo* current = modules[curidx];

		// First, determine which modules are reachable.
		auto reachable = cast(size_t*)lwdrInternal_alloc(flagbytes);
		scope(exit) lwdrInternal_free(reachable);
		if(!findDeps(curidx, reachable))
			return false; // deprecated cycle error

		// process the dependencies. First, we process all relevant ones
		bts(ctorstart, curidx);
		auto brange = BitRange(reachable, len);
		foreach(i; brange)
			// note, don't check for cycles here, because the config could have been set to ignore cycles.
			// however, don't recurse if there is one, so still check for started ctor.
			if(i != curidx && bt(relevant, i) && !bt(ctordone, i) && !bt(ctorstart, i))
				if(!processMod(i, c, ctoridx))
					return false; // deprecated cycle error

		// now mark this node, and all nodes reachable from this module as done.
		bts(ctordone, curidx);
		btr(ctorstart, curidx);
		foreach(i; brange)
			// Since relevant dependencies are already marked as done
			// from recursion above (or are going to be handled up the call
			// stack), no reason to check for relevance, that is a wasted
			// op.
			bts(ctordone, i);
		
		c[ctoridx++] = current;
		return true;
	}

	// returns `false` if deprecated cycle error otherwise set `result`.
	bool doSort(size_t relevantFlags, ref immutable(ModuleInfo)*[] result) nothrow @nogc
	{
		clearFlags(relevant);
		clearFlags(ctorstart);
		clearFlags(ctordone);

		// pre-allocate enough space to hold all modules.
		immutable(ModuleInfo)** ctors = cast(immutable(ModuleInfo)**)lwdrInternal_alloc(len * (void*).sizeof);
		size_t ctoridx = 0;
		foreach(idx, m; modules)
		{
			if(m.flags & relevantFlags)
			{
				if(m.flags & MIstandalone)
					ctors[ctoridx++] = m; // can run at any time. Just run it first.
				else 
					bts(relevant, idx);
			}
		}

		// now run the algorithm in the relevant ones
		foreach(idx; BitRange(relevant, len))
		{
			if(!bt(ctordone, idx))
				if(!processMod(idx, ctors, ctoridx))
					return false;
		}
		if(ctoridx == 0)
			// no ctors in the list
			lwdrInternal_free(ctors);
		else
			// cannot trim ctors :(
			result = ctors[0 .. ctoridx];
		return true;
	}

	if(!doSort(MIctor | MIdtor, ctors) || !doSort(MItlsctor | MItlsdtor, tlsctors))
		assert(false, "Module cycle deprecation 16211 warning!");
}

extern(C) int printf(const char* format, ...) nothrow @nogc;

extern(C)
{
	void __lwdr_moduleInfo_runModuleCtors() nothrow @nogc
	{
		modules = getModules;
		sortCtors;
		foreach(m; modules) // independent ctors
		{
			// must cast or won't call
			auto ct = cast(void function() nothrow @nogc)m.ictor;
			if(ct !is null) ct();
		}
		foreach(m; ctors) // sorted module ctors
		{
			auto ct = cast(void function() nothrow @nogc)m.ctor;
			if(ct !is null) ct();
		}
	}

	void __lwdr_moduleInfo_runTlsCtors() nothrow @nogc
	{
		foreach(m; tlsctors)
		{
			auto tlsct = cast(void function() nothrow @nogc)m.tlsctor;
			if(tlsct !is null) tlsct();
		}
	}

	void __lwdr_moduleInfo_runTlsDtors() nothrow @nogc
	{
		foreach_reverse(m; tlsctors)
		{
			auto tlsdt = cast(void function() nothrow @nogc)m.tlsdtor;
			if(tlsdt !is null) tlsdt();
		}
	}

	void __lwdr_moduleInfo_runModuleDtors() nothrow @nogc
	{
		foreach_reverse(m; ctors)
		{
			auto dt = cast(void function() nothrow @nogc)m.dtor;
			if(dt !is null) dt();
		}

		if(ctors.ptr)
			lwdrInternal_free(ctors.ptr);
		ctors = null;
		if(tlsctors.ptr)
			lwdrInternal_free(tlsctors.ptr);
		tlsctors = null;
	}
}