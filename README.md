# LWDR - Light Weight D Runtime

### Notice:
This is not a port of druntime! This is a completely new implementation for low-resource environments. Normal D code may not work here!

LWDR is now part of the [Symmetry Autumn of Code 2021](https://dlang.org/blog/2021/08/30/saoc-2021-projects/).

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
9. Virtual functions and overrides
10. Abstract classes
11. Static classes
12. Allocation and deallocation of dynamic arrays (opt in by version `LWDR_DynamicArray`)
13. Concatenate an item to a dynamic array (opt in by version `LWDR_DynamicArray`)
14. Concatenate two dynamic arrays together (opt in by version `LWDR_DynamicArray`)
15. Dynamic array resizing (opt in by version `LWDR_DynamicArray`)
16. Thread local storage (opt in by version `LWDR_TLS`)
17. Delegates/closures (opt-in by version `LWDR_ManualDelegate`)
18. Module constructors and destructors (opt-in by version `LWDR_ModuleCtors`)
19. Static constructors and destructors (opt-in by version `LWDR_ModuleCtors`)
20. Shared static constructors and destructor (opt-in by version `LWDR_ModuleCtors`)
21. Module info (opt-in by version `LWDR_ModuleCtors`)

### What doesn't work?
22. Exceptions and Throwables (experimental implementation was removed)
23. There is no GC implementation (primitive memory tracking is now available with `LWDR_TrackMem`, `RefCount!T` and `Unique!T` are now available)
24. Associative arrays
25. Object monitors (Milestone 1, Task 2)
26. Shared/synchronised (Milestone 1, Task 2)

### Which compilers can be used?
LDC works the best. DMD is not compatible. GDC will work but points 18-21 inclusive aren't supported.

### Has this been run on real hardware?
Yes, as of currently it has been run on an STM32F407.

### How to use this?
You have to hook the functions declared in `rtoslink.d` by implementing them in your MCU development environment. For example, with FreeRTOS, `rtosbackend_heapalloc` points to a wrapper in the C/C++ land that wraps `pvPortMalloc(...)`.

### Example usage
First off, you will need an existing C/C++ project for your target microcontroller that has a C compiler and link, and has some form of memory management (RTOS preferred). The C/C++ code can then call into your D functions (they must be marked `extern(C)`).

LWDR can be used with DUB and LDC. Simply add it to your dependencies. Build instructions are [here for DUB and LDC](https://github.com/hmmdyl/LWDR/wiki/Compiling-with-DUB-and-LDC).

This will output a lib archive that you can link into your C/C++ project and execute on an MCU.

Here is an example code using FreeRTOS:

```d
//myapp.d
module myapp;

import lwdr;

class Foo 
{
  this() 
  {
    // do something
  }
  
  void bar()
  {
    // do something
  }
}

extern(C) void myDFunction() 
{
  Foo foo = new Foo; // this will invoke rtosbackend_heapalloc(..)
  foo.bar;
  LWDR.free(foo); // don't forget to free - there is no GC
  // LWDR.free will invoke rtosbackend_heapfreealloc(..)
}
```

```c++
// main.h
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

// defined in rtoslink.d
void* rtosbackend_heapalloc(unsigned int sz);
void rtosbackend_heapfreealloc(void* ptr);

void rtosbackend_arrayBoundFailure(char* file, unsigned int line);
void rtosbackend_assert(char* file, unsigned int line);
void rtosbackend_assertmsg(char* msg, char* file, unsigned int line);

void myDFunction(); // defined in myapp.d
#ifdef __cplusplus
}
#endif

#endif __MAIN_H
```

```c++
// main.cpp
#include "cmsis_os.h"

void* rtosbackend_heapalloc(unsigned int sz) // defined in rtoslink.d
{
  return pvPortMalloc(sz); // allocate some heap memory for D 
}

void rtosbackend_heapfreealloc(void* ptr)// defined in rtoslink.d
{
  vPortFree(ptr); // deallocate some heap memory for D
}
void rtosbackend_arrayBoundFailure(char* file, unsigned int line)
{}
void rtosbackend_assert(char* file, unsigned int line)
{}
void rtosbackend_assertmsg(char* msg, char* file, unsigned int line)
{}

osThreadId_t defaultTaskHandle; // thread handle
osThreadAttr_t defaultTask_attributes; // thread attributes

void myTask(void *argument)
{
  myDFunction();
}

int main()
{
  osKernelInitialize();
  defaultTask_attributes.name = "defaultTask";
	defaultTask_attributes.priority = (osPriority_t) osPriorityNormal;
	defaultTask_attributes .stack_size = 128 * 4;
  // create a thread that executes myTask
  defaultTaskHandle = osThreadNew(myTask, NULL, &defaultTask_attributes);
  osKernelStart(); // start the scheduler
  
  while(1) {}
  
  return 1;
}
```

GDB will be able to set breakpoints in D code and perform steps normally.

### Credit
Credit to [Adam D. Ruppe](https://github.com/adamdruppe) for his [webassembly](https://github.com/adamdruppe/webassembly) project that forms the basis of this project.

Credit to [D Language Foundation](https://github.com/dlang) for its [D runtime](https://github.com/dlang/druntime).

Credit to [LDC Developers](https://github.com/ldc-developers) for its [D runtime](https://github.com/ldc-developers/druntime).

Credit to [GDC](https://gdcproject.org/) for its [D runtime](https://github.com/gcc-mirror/gcc/tree/master/libphobos).

Credit to [denizzka](https://github.com/denizzzka) for his [d_c_arm_test](https://github.com/denizzzka/d_c_arm_test) which helped with the implementation of TLS (thread local storage).
