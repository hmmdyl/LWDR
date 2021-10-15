module rt.monitor_;

version(LDC)
	pragma(LDC_no_moduleinfo);

version(LWDR_Sync):

import rtoslink;
import lwdr.tracking;

import core.atomic;

/++
First field of any Object monitor must be a reference to Object.Monitor, even for custom implementations.
Failure to do so will result in memory corruption.
++/

package struct Monitor
{
	Object.Monitor userMonitor;
	size_t referenceCount;
	void* mutex;
}

/++
Called on entry to a `synchronized` statement. If `o` does not already have a monitor, it will be created.
The monitor will then be locked.

`o` must not be null.
++/
extern(C) void _d_monitorenter(Object o)
in(o !is null, "Cannot sync null object")
{
	auto m = cast(Monitor*)ensureMonitor(o);
	if(m.userMonitor is null)
		rtosbackend_mutexLock(m.mutex);
	else
		m.userMonitor.lock;
}

/++
Called on exit from a `synchronized` statement. It will will unlock the monitor.
++/
extern(C) void _d_monitorexit(Object o)
{
	// don't apply null checking, as thread will have already crashed.
	auto m = cast(Monitor*)getMonitor(o);
	if(m.userMonitor is null)
		rtosbackend_mutexUnlock(m.mutex);
	else 
		m.userMonitor.unlock;
}

/++
INTERNAL USE!
Called during finalisation to remove monitor.
++/
void _lwdr_monitorDelete(Object o)
{
	auto m = getMonitor(o);
	if(m is null) 
		return;

	scope(exit) setMonitor(o, null);

	// user monitor should outlive object (ie, core.sync.Mutex) or be destroyed in dtor.
	if(m.userMonitor !is null)
		return;

	if(atomicOp!"-="(m.referenceCount, cast(size_t)1) == 0)
	{
		// referenceCount == 0 means unshared -> no sync needed
		deleteMonitor(cast(Monitor*)m);
	}
}

private
{
	__gshared void* globalMutex;

	@property ref shared(Monitor*) monitor(return Object o) pure nothrow @nogc
	{ return *cast(shared Monitor**)&o.__monitor; }

	shared(Monitor)* getMonitor(Object o) pure @nogc
	{ return atomicLoad!(MemoryOrder.acq)(o.monitor); }

	void setMonitor(Object o, shared(Monitor)* m) pure @nogc
	{ atomicStore!(MemoryOrder.rel)(o.monitor, m); }

	/// Gets existing monitor, or assigns one.
	shared(Monitor)* ensureMonitor(Object o)
	{
		if(auto m = getMonitor(o))
			return m;

		auto monitor = cast(Monitor*)lwdrInternal_alloc(Monitor.sizeof);
		assert(monitor !is null);
		*monitor = Monitor();
		
		monitor.mutex = rtosbackend_mutexInit();

		bool success;
		rtosbackend_mutexLock(globalMutex);
		if(getMonitor(o) is null)
		{
			monitor.referenceCount = 1;
			setMonitor(o, cast(shared)monitor);
			success = true;
		}
		rtosbackend_mutexUnlock(globalMutex);

		if(success)
			return cast(shared(Monitor)*)monitor;
		else
		{
			deleteMonitor(monitor);
			return getMonitor(o);
		}
	}

	/// Deletes mutex and monitor
	void deleteMonitor(Monitor* m) @nogc nothrow
	{
		rtosbackend_mutexDestroy(m.mutex);
		lwdrInternal_free(m);
	}
}

void __lwdr_monitor_init() nothrow @nogc
{
	globalMutex = rtosbackend_globalMutexInit;
	assert(globalMutex !is null);
}

void __lwdr_monitor_deinit() nothrow @nogc
{
	rtosbackend_globalMutexDestroy(globalMutex);
	globalMutex = null;
}