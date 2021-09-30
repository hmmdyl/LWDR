module unwind;

pragma(LDC_no_moduleinfo);

// src:https://github.com/ldc-developers/druntime/blob/ldc/src/rt/unwind.d

version(ARM)
{
	version(iOS) {}
	else version = ARM_EABI_UNWINDER;
}

//version = GNU_ARM_EABI_Unwinder;

extern(C):

alias intptr_t  = ptrdiff_t;
alias uintptr_t = size_t;  

alias _Unwind_Word = uintptr_t;
alias _Unwind_Sword = intptr_t;
alias _Unwind_Ptr = uintptr_t;
alias _Unwind_Internal_Ptr = uintptr_t;

alias _uleb128_t = uintptr_t;
alias _sleb128_t = intptr_t;

alias _uw = _Unwind_Word;
alias _uw64 = ulong;
alias _uw16 = ushort;
alias _uw8 = ubyte;

@nogc:

enum
{
    DW_EH_PE_absptr   = 0x00,
    DW_EH_PE_omit     = 0xff,

    DW_EH_PE_uleb128  = 0x01,
    DW_EH_PE_udata2   = 0x02,
    DW_EH_PE_udata4   = 0x03,
    DW_EH_PE_udata8   = 0x04,
    DW_EH_PE_sleb128  = 0x09,
    DW_EH_PE_sdata2   = 0x0A,
    DW_EH_PE_sdata4   = 0x0B,
    DW_EH_PE_sdata8   = 0x0C,
    DW_EH_PE_signed   = 0x08,

    DW_EH_PE_pcrel    = 0x10,
    DW_EH_PE_textrel  = 0x20,
    DW_EH_PE_datarel  = 0x30,
    DW_EH_PE_funcrel  = 0x40,
    DW_EH_PE_aligned  = 0x50,

    DW_EH_PE_indirect = 0x80
}


enum int UNWIND_STACK_REG = 13;
// Use IP as a scratch register within the personality routine.
enum int UNWIND_POINTER_REG = 12;

version (linux)
    enum _TTYPE_ENCODING = (DW_EH_PE_pcrel | DW_EH_PE_indirect);
else version (NetBSD)
    enum _TTYPE_ENCODING = (DW_EH_PE_pcrel | DW_EH_PE_indirect);
else version (FreeBSD)
    enum _TTYPE_ENCODING = (DW_EH_PE_pcrel | DW_EH_PE_indirect);
else version (Symbian)
    enum _TTYPE_ENCODING = (DW_EH_PE_absptr);
else version (uClinux)
    enum _TTYPE_ENCODING = (DW_EH_PE_absptr);
else
    enum _TTYPE_ENCODING = (DW_EH_PE_pcrel);

// Return the address of the instruction, not the actual IP value.
_Unwind_Word _Unwind_GetIP(_Unwind_Context* context)
{
    return _Unwind_GetGR(context, 15) & ~ cast(_Unwind_Word) 1;
}

void _Unwind_SetIP(_Unwind_Context* context, _Unwind_Word val)
{
    return _Unwind_SetGR(context, 15, val | (_Unwind_GetGR(context, 15) & 1));
}

_Unwind_Word _Unwind_GetIPInfo(_Unwind_Context* context, int* ip_before_insn)
{
    *ip_before_insn = 0;
    return _Unwind_GetIP(context);
}

// Placed outside @nogc in order to not constrain what the callback does.
// ??? Does this really need to be extern(C) alias?
extern(C) alias _Unwind_Exception_Cleanup_Fn
    = void function(_Unwind_Reason_Code, _Unwind_Exception*);

extern(C) alias personality_routine
    = _Unwind_Reason_Code function(_Unwind_State,
                                   _Unwind_Control_Block*,
                                   _Unwind_Context*);

extern(C) alias _Unwind_Stop_Fn
    =_Unwind_Reason_Code function(int, _Unwind_Action,
                                  _Unwind_Exception_Class,
                                  _Unwind_Control_Block*,
                                  _Unwind_Context*, void*);

extern(C) alias _Unwind_Trace_Fn
    = _Unwind_Reason_Code function(_Unwind_Context*, void*);
	
	alias _Unwind_Reason_Code = uint;
enum : _Unwind_Reason_Code
{
    _URC_OK = 0,        // operation completed successfully
    _URC_FOREIGN_EXCEPTION_CAUGHT = 1,
    _URC_END_OF_STACK = 5,
    _URC_HANDLER_FOUND = 6,
    _URC_INSTALL_CONTEXT = 7,
    _URC_CONTINUE_UNWIND = 8,
    _URC_FAILURE = 9    // unspecified failure of some kind
}

alias _Unwind_State = int;
enum : _Unwind_State
{
    _US_VIRTUAL_UNWIND_FRAME = 0,
    _US_UNWIND_FRAME_STARTING = 1,
    _US_UNWIND_FRAME_RESUME = 2,
    _US_ACTION_MASK = 3,
    _US_FORCE_UNWIND = 8,
    _US_END_OF_STACK = 16
}

// Provided only for for compatibility with existing code.
alias _Unwind_Action = int;
enum : _Unwind_Action
{
    _UA_SEARCH_PHASE = 1,
    _UA_CLEANUP_PHASE = 2,
    _UA_HANDLER_FRAME = 4,
    _UA_FORCE_UNWIND = 8,
    _UA_END_OF_STACK = 16,
    _URC_NO_REASON = _URC_OK
}

struct _Unwind_Context;
alias _Unwind_EHT_Header = _uw;

struct _Unwind_Control_Block
{
    _Unwind_Exception_Class exception_class = '\0';
    _Unwind_Exception_Cleanup_Fn exception_cleanup;
    // Unwinder cache, private fields for the unwinder's use
    struct _unwinder_cache
    {
        _uw reserved1;  // Forced unwind stop fn, 0 if not forced
        _uw reserved2;  // Personality routine address
        _uw reserved3;  // Saved callsite address
        _uw reserved4;  // Forced unwind stop arg
        _uw reserved5;
    }
    _unwinder_cache unwinder_cache;
    // Propagation barrier cache (valid after phase 1):
    struct _barrier_cache
    {
        _uw sp;
        _uw[5] bitpattern;
    }
    _barrier_cache barrier_cache;
    // Cleanup cache (preserved over cleanup):
    struct _cleanup_cache
    {
        _uw[4] bitpattern;
    }
    _cleanup_cache cleanup_cache;
    // Pr cache (for pr's benefit):
    struct _pr_cache
    {
        _uw fnstart;                // function start address */
        _Unwind_EHT_Header* ehtp;   // pointer to EHT entry header word
        _uw additional;             // additional data
        _uw reserved1;
    }
    _pr_cache pr_cache;
    long[0] _force_alignment;       // Force alignment to 8-byte boundary
}

// Virtual Register Set
alias _Unwind_VRS_RegClass = int;
enum : _Unwind_VRS_RegClass
{
    _UVRSC_CORE = 0,    // integer register
    _UVRSC_VFP = 1,     // vfp
    _UVRSC_FPA = 2,     // fpa
    _UVRSC_WMMXD = 3,   // Intel WMMX data register
    _UVRSC_WMMXC = 4    // Intel WMMX control register
}

alias _Unwind_VRS_DataRepresentation = int;
enum : _Unwind_VRS_DataRepresentation
{
    _UVRSD_UINT32 = 0,
    _UVRSD_VFPX = 1,
    _UVRSD_FPAX = 2,
    _UVRSD_UINT64 = 3,
    _UVRSD_FLOAT = 4,
    _UVRSD_DOUBLE = 5
}

alias _Unwind_VRS_Result = int;
enum : _Unwind_VRS_Result
{
    _UVRSR_OK = 0,
    _UVRSR_NOT_IMPLEMENTED = 1,
    _UVRSR_FAILED = 2
}

// Frame unwinding state.
struct __gnu_unwind_state
{
    _uw data;           // The current word (bytes packed msb first).
    _uw* next;          // Pointer to the next word of data.
    _uw8 bytes_left;    // The number of bytes left in this word.
    _uw8 words_left;    // The number of words pointed to by ptr.
}

_Unwind_VRS_Result _Unwind_VRS_Set(_Unwind_Context*, _Unwind_VRS_RegClass,
                                   _uw, _Unwind_VRS_DataRepresentation,
                                   void*);

_Unwind_VRS_Result _Unwind_VRS_Get(_Unwind_Context*, _Unwind_VRS_RegClass,
                                   _uw, _Unwind_VRS_DataRepresentation,
                                   void*);

_Unwind_VRS_Result _Unwind_VRS_Pop(_Unwind_Context*, _Unwind_VRS_RegClass,
                                   _uw, _Unwind_VRS_DataRepresentation);


// Support functions for the PR.
alias _Unwind_Exception = _Unwind_Control_Block;
alias _Unwind_Exception_Class = char[8];

void* _Unwind_GetLanguageSpecificData(_Unwind_Context*);
_Unwind_Ptr _Unwind_GetRegionStart(_Unwind_Context*);

_Unwind_Ptr _Unwind_GetDataRelBase(_Unwind_Context*);
// This should never be used.
_Unwind_Ptr _Unwind_GetTextRelBase(_Unwind_Context*);

// Interface functions:
_Unwind_Reason_Code _Unwind_RaiseException(_Unwind_Control_Block*);
void _Unwind_Resume(_Unwind_Control_Block*);
_Unwind_Reason_Code _Unwind_Resume_or_Rethrow(_Unwind_Control_Block*);

_Unwind_Reason_Code _Unwind_ForcedUnwind(_Unwind_Control_Block*,
                                         _Unwind_Stop_Fn, void*);

// @@@ Use unwind data to perform a stack backtrace.  The trace callback
// is called for every stack frame in the call chain, but no cleanup
// actions are performed.
_Unwind_Reason_Code _Unwind_Backtrace(_Unwind_Trace_Fn, void*);

_Unwind_Word _Unwind_GetCFA(_Unwind_Context*);
void _Unwind_Complete(_Unwind_Control_Block*);
void _Unwind_DeleteException(_Unwind_Exception*);

_Unwind_Reason_Code __gnu_unwind_frame(_Unwind_Control_Block*,
                                       _Unwind_Context*);
_Unwind_Reason_Code __gnu_unwind_execute(_Unwind_Context*,
                                         __gnu_unwind_state*);

_Unwind_Word _Unwind_GetGR(_Unwind_Context* context, int regno)
{
    _uw val;
    _Unwind_VRS_Get(context, _UVRSC_CORE, regno, _UVRSD_UINT32, &val);
    return val;
}

void _Unwind_SetGR(_Unwind_Context* context, int regno, _Unwind_Word val)
{
    _Unwind_VRS_Set(context, _UVRSC_CORE, regno, _UVRSD_UINT32, &val);
}

// Read an unsigned leb128 value from P, *P is incremented past the value.
// We assume that a word is large enough to hold any value so encoded;
// if it is smaller than a pointer on some target, pointers should not be
// leb128 encoded on that target.
_uleb128_t read_uleb128(const(ubyte)** p)
{
    auto q = *p;
    _uleb128_t result = 0;
    uint shift = 0;

    while (1)
    {
        ubyte b = *q++;
        result |= cast(_uleb128_t)(b & 0x7F) << shift;
        if ((b & 0x80) == 0)
            break;
        shift += 7;
    }

    *p = q;
    return result;
}

// Similar, but read a signed leb128 value.
_sleb128_t read_sleb128(const(ubyte)** p)
{
    auto q = *p;
    _sleb128_t result = 0;
    uint shift = 0;
    ubyte b = void;

    while (1)
    {
        b = *q++;
        result |= cast(_sleb128_t)(b & 0x7F) << shift;
        shift += 7;
        if ((b & 0x80) == 0)
            break;
    }

    // Sign-extend a negative value.
    if (shift < result.sizeof * 8 && (b & 0x40))
        result |= -(cast(_sleb128_t)1 << shift);

    *p = q;
    return result;
}

// Load an encoded value from memory at P.  The value is returned in VAL;
// The function returns P incremented past the value.  BASE is as given
// by base_of_encoded_value for this encoding in the appropriate context.
_Unwind_Ptr read_encoded_value_with_base(ubyte encoding, _Unwind_Ptr base,
                                         const(ubyte)** p)
{
    auto q = *p;
    _Unwind_Internal_Ptr result;

    if (encoding == DW_EH_PE_aligned)
    {
        _Unwind_Internal_Ptr a = cast(_Unwind_Internal_Ptr)q;
        a = cast(_Unwind_Internal_Ptr)((a + (void*).sizeof - 1) & - (void*).sizeof);
        result = *cast(_Unwind_Internal_Ptr*)a;
        q = cast(ubyte*) cast(_Unwind_Internal_Ptr)(a + (void*).sizeof);
    }
    else
    {
        switch (encoding & 0x0f)
        {
            case DW_EH_PE_uleb128:
                result = cast(_Unwind_Internal_Ptr)read_uleb128(&q);
                break;

            case DW_EH_PE_sleb128:
                result = cast(_Unwind_Internal_Ptr)read_sleb128(&q);
                break;

            case DW_EH_PE_udata2:
                result = cast(_Unwind_Internal_Ptr) *cast(ushort*)q;
                q += 2;
                break;
            case DW_EH_PE_udata4:
                result = cast(_Unwind_Internal_Ptr) *cast(uint*)q;
                q += 4;
                break;
            case DW_EH_PE_udata8:
                result = cast(_Unwind_Internal_Ptr) *cast(ulong*)q;
                q += 8;
                break;

            case DW_EH_PE_sdata2:
                result = cast(_Unwind_Internal_Ptr) *cast(short*)q;
                q += 2;
                break;
            case DW_EH_PE_sdata4:
                result = cast(_Unwind_Internal_Ptr) *cast(int*)q;
                q += 4;
                break;
            case DW_EH_PE_sdata8:
                result = cast(_Unwind_Internal_Ptr) *cast(long*)q;
                q += 8;
                break;

            case DW_EH_PE_absptr:
                if (size_t.sizeof == 8)
                    goto case DW_EH_PE_udata8;
                else
                    goto case DW_EH_PE_udata4;

            default: break;
                //__builtin_abort();
        }

        if (result != 0)
        {
            result += ((encoding & 0x70) == DW_EH_PE_pcrel
                       ? cast(_Unwind_Internal_Ptr)*p : base);
            if (encoding & DW_EH_PE_indirect)
                result = *cast(_Unwind_Internal_Ptr*)result;
        }
    }

    *p = q;
    return result;
}

// Like read_encoded_value_with_base, but get the base from the context
// rather than providing it directly.
_Unwind_Ptr read_encoded_value(_Unwind_Context* context, ubyte encoding,
                               const(ubyte)** p)
{
    auto base = base_of_encoded_value(encoding, context);
    return read_encoded_value_with_base(encoding, base, p);
}

// Given an encoding and an _Unwind_Context, return the base to which
// the encoding is relative.  This base may then be passed to
// read_encoded_value_with_base for use when the _Unwind_Context is
// not available.
_Unwind_Ptr base_of_encoded_value(ubyte encoding, _Unwind_Context* context)
{
    if (encoding == DW_EH_PE_omit)
        return cast(_Unwind_Ptr) 0;

    switch (encoding & 0x70)
    {
        case DW_EH_PE_absptr:
        case DW_EH_PE_pcrel:
        case DW_EH_PE_aligned:
            return cast(_Unwind_Ptr) 0;

        case DW_EH_PE_textrel:
            return _Unwind_GetTextRelBase(context);
        case DW_EH_PE_datarel:
            return _Unwind_GetDataRelBase(context);
        case DW_EH_PE_funcrel:
            return _Unwind_GetRegionStart(context);
		default: break;
    }
    assert(0);
}

// Given an encoding, return the number of bytes the format occupies.
// This is only defined for fixed-size encodings, and so does not
// include leb128.
uint size_of_encoded_value(ubyte encoding)
{
    if (encoding == DW_EH_PE_omit)
        return 0;

    switch (encoding & 0x07)
    {
        case DW_EH_PE_absptr:
            return (void*).sizeof;
        case DW_EH_PE_udata2:
            return 2;
        case DW_EH_PE_udata4:
            return 4;
        case DW_EH_PE_udata8:
            return 8;
		default: break;
    }
    assert(0);
}