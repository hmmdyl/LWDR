# LWDR - Light Weight D Runtime

### Notice:
This is not a port of druntime! This is a completely new implementation for low-resource environments. Normal D code may not work here!

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

### What is in progress?
17. Exceptions and Throwables (so far are working on GDC only)

### What doesn't work?
18. Module constructors and destructors
19. ModuleInfo
20. There is no GC implmenetation (primitive memory tracking is now available with `LWDR_TrackMem`)
21. Delegates/closures
22. Associative arrays

### Which compilers can be used?
GDC works the best. 
LDC can only be used for points 1-16. Exception handling does not work on LDC.
DMD is not compatible.

### Has this been run on real hardware?
Yes, as of currently it has been run on an STM32F407.

### How to use this?
You have to hook the functions declared in `rtoslink.d` by implementing them in your MCU development environment. For example, with FreeRTOS, `rtosbackend_heapalloc` points to a wrapper in the C/C++ land that wraps `pvPortMalloc(...)`.

### Example usage
First off, you will need an existing C/C++ project for your target microcontroller that builds with GCC and has some form of memory management (RTOS preferred). The C/C++ code can then call into your D functions (they must be marked `extern(C)`).

You will need to download GDC and compile it for the arm-none-eabi target. Once that is done, you can compile LWDR with your compatible D project. An example arm-none-eabi-gdc command is:
`arm-none-eabi-gdc "myapp.d" "dwarf_eh.d" "memory.d" "object.d" "rtoslink.d" "unwind.d" "util.d" "invariant_.d" "arrimpl.d" -nophoboslib -nostdlib -ggdb`

This will output a lib archive that you can link into your C/C++ project and execute on an MCU.

Here is an example code using FreeRTOS:

```d
//myapp.d
module myapp;
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
  delete foo; // don't forget to delete - there is no GC
  // delete will invoke rtosbackend_heapfreealloc(..)
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
