class A
{
	int a;
	
	this()
	{
		a = 10;
	}
	
	void inc()
	in { assert(a < 11); }
	do { 
	a++; 
	}
	int get() const { return a; }
}

extern(C) void runDMain()
{
	A a = new A;
	a.inc;
	a.inc;
	a.inc;
	a.inc;
	int b = a.get;
	delete a;
	
	int dlang = 1;
	dlang++;
	dlang *= 2;
	

	while(true) {}
}
