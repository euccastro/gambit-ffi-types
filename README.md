gambit-ffi-types
================

This library provides Scheme-friendly management of C structs, unions, and memory allocated opaque types.

C structures are accessed and modified in place.  Only primitives (integers, strings, etc.) are copied when converting from Scheme to C and back.  So, for example, you can pass such a structure to a C function that takes one and modifies it in place, and any changes will be reflected when you next access the fields in that structure after the call returns.

The library takes care to maintain the lifecycle of your objects in a schemey way (with some caveats; see [1]): they will be kept around only as long as you have references to them (or to some field of them, or to some subfield of a field of them, etc.)

To use, include `ffi-types-include.scm` and compile `ffi-types-lib.scm` with your application.  Then see `integration-test.scm` (after the `; BEGIN TESTS` comment) for usage examples.

## Implementation

The challenge in this is to make child substructures keep the parent alive while they are reachable in Scheme.  This is done by keeping a table with the dependent objects as weak keys and the depended-upon objects as strong values.  In addition, a will is set on the dependent object so it will delete the entry in that table when the dependent has become weakly reachable.  See `ffi-types-lib.scm`.

[1] A problem with this approach is that if you keep a weak reference to a dependent object you may be able to access invalid memory through it, perhaps causing memory corruption or segmentation faults.  So if you use this library, or some bindings that use it, **avoid weak references (including wills)** to foreign objects unless you know what you're doing.

