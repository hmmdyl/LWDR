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

### What doesn't work?
1. Interfaces


### What is untested?
1. Virtual functions and overrides
2. Abstract classes
