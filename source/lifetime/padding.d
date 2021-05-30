module lifetime.padding;

package 
{
	enum : size_t 
	{
		PAGESIZE = 4096,
		BIGLENGTHMASK = ~(PAGESIZE - 1),
		SMALLPAD = 1,
		MEDPAD = ushort.sizeof,
		LARGEPREFIX = 16, // 16 bytes padding at the front of the array
		LARGEPAD = LARGEPREFIX + 1,
		MAXSMALLSIZE = 256-SMALLPAD,
		MAXMEDSIZE = (PAGESIZE / 2) - MEDPAD
	}
}