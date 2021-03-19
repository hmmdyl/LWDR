module util;

int stringCmpInternal(scope const char[] s1, scope const char[] s2) @trusted {
	immutable tlen = s1.length <= s2.length ? s1.length : s2.length;
	foreach(const u; 0 .. tlen) {
		if(s1[u] != s2[u]) return s1[u] > s2[u] ? 1 : -1;
	}
	return s1.length < s2.length ? -1 : (s1.length > s2.length);
}

extern(C) void* memset(void* s, int c, size_t n) {
	auto d = cast(ubyte*)s;
	while(n) {
		*d++ = cast(ubyte)c;
		n--;
	}
	return s;
}
