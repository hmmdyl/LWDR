# LWDR - Light Weight D Runtime

### What is this?
This is the light weight D runtime - it is a barebones runtime targeting ARM Cortex CPUs. It works by abstracting hooks that the user can connect to their selected backend (be it an RTOS such as FreeRTOS, ChibiOS, etc or a minimalist system). 

### What works?
1. Class allocations and deallocations (via `new` and `delete`)
2. Struct heap allocations and deallocations (via `new` and `delete`)
3. Invariants
4. Asserts
5. Contract programming
6. Basic RTTI (via `TypeInfo` stubs)
7. Interfaces
8. Static Arrays

### What is in progress?
1. Exceptions and Throwables (so far are currently working)

### What doesn't work?
1. Arrays
2. Module constructors and destructors
3. ModuleInfo

### Has this been run on real hardware?
Yes, as of currently it has been run on an STM32F407.

### What is untested?
1. Virtual functions and overrides
2. Abstract classes
3. Static classes

### How to use this?
You have to hook the functions declared in `rtoslink.d` by implementing them in your MCU development environment. For example, with FreeRTOS, `rtosbackend_heapalloc` points to a wrapper in the C/C++ land that wraps `pvPortMalloc(...)`.

### Credit
Credit to [Adam D. Ruppe](https://github.com/adamdruppe) for his [webassembly](https://github.com/adamdruppe/webassembly) project that forms the basis of this project.
