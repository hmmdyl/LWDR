module rt.tls;

version(LWDR_TLS):

version(ARM)
	public import rt.tls.arm_eabi;
else
	static assert(0, "TLS implementation for this platform is not present!");