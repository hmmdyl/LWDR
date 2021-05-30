module rt.util.utility;

package struct _Complex(T) { T re; T im; }

package enum __c_complex_float : _Complex!float;
package enum __c_complex_double : _Complex!double;
package enum __c_complex_real : _Complex!real;  // This is why we don't use stdc.config

package alias d_cfloat = __c_complex_float;
package alias d_cdouble = __c_complex_double;
package alias d_creal = __c_complex_real;

package enum isComplex(T) = is(T == d_cfloat) || is(T == d_cdouble) || is(T == d_creal);
