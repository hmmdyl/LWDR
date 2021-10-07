module core.sync.mutex;

version(LDC)
	pragma(LDC_no_moduleinfo);

version(LWDR_Sync):

import rtoslink;

/++
This class represents a general purpose, recursive (may differ on implementation) mutex.

If mutex is assigned to an object's monitor and manual memory management is being used,
then the mutex must outlive the object!
++/
class Mutex : Object.Monitor
{
	private struct MonitorInternal
	{
		Object.Monitor userMonitor; // must satisfy requirements in rt.monitor_
	}
	private MonitorInternal proxy;
	private void* mutexHandle;

	/// Constructor implementation
	private mixin template Ctor()
	{
		mutexHandle = rtosbackend_mutexInit;
		proxy.userMonitor = this;
		this.__monitor = cast(void*)proxy;
	}

	/// Initialise a new mutex object
	this() @trusted nothrow @nogc
	{
		mixin(Ctor);
	}

	/// ditto
	shared this() @trusted nothrow @nogc
	{
		mixin(Ctor);
	}

	/// Create mutex and assign it to the object's monitor. 
	private mixin template ObjCtor()
	{
		assert(obj !is null);
		assert(obj.__monitor is null);
		this();
		obj.__monitor = cast(void*)proxy;
	}

	/// Create mutex and assign it to the object's monitor. 
	this(Object o) @trusted nothrow @nogc
	{
		mixin(ObjCtor);
	}

	/// ditto
	shared this(Object o) @trusted nothrow @nogc
	{
		mixin(ObjCtor);
	}

	~this() @trusted nothrow @nogc
	{
		rtosbackend_mutexDestroy(mutexHandle);
		this.__monitor = null;
	}

	/**
	* If this lock is not already held by the caller, the lock is acquired,
	* then the internal counter is incremented by one.
	*
	* Note:
	*    `Mutex.lock` does not throw, but a class derived from Mutex can throw.
	*    Use `lock_nothrow` in `nothrow @nogc` code.
	*/
	void lock() @trusted { lock_nothrow; }
	/// ditto
	shared void lock() @trusted { lock_nothrow; }
	// ditto
	final void lock_nothrow(this Q)() nothrow @trusted @nogc
		if(is(Q == Mutex) || is(Q == shared Mutex))
	{
		rtosbackend_mutexLock(mutexHandle);
	}

	/**
	* Decrements the internal lock count by one.  If this brings the count to
	* zero, the lock is released.
	*
	* Note:
	*    `Mutex.unlock` does not throw, but a class derived from Mutex can throw.
	*    Use `unlock_nothrow` in `nothrow @nogc` code.
	*/
	void unlock() @trusted { unlock_nothrow; }
	/// ditto
	shared void unlock() @trusted { unlock_nothrow; }
	/// ditto
	final void unlock_nothrow(this Q)() nothrow @trusted @nogc
	{
		rtosbackend_mutexUnlock(mutexHandle);
	}

	/**
	* If the lock is held by another caller, the method returns.  Otherwise,
	* the lock is acquired if it is not already held, and then the internal
	* counter is incremented by one.
	*
	* Returns:
	*  true if the lock was acquired and false if not.
	*
	* Note:
	*    `Mutex.tryLock` does not throw, but a class derived from Mutex can throw.
	*    Use `tryLock_nothrow` in `nothrow @nogc` code.
	*/
	bool tryLock() @trusted { return tryLock_nothrow; }
	/// ditto
	shared bool tryLock() @trusted { return tryLock_nothrow; }
	/// ditto
	final bool tryLock_nothrow(this Q)() @trusted nothrow @nogc
	{
		return rtosbackend_mutexTryLock(void*) == 1; 
	}
}