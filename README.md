gambit-ffi-types
================

This library provides Scheme-friendly management of C structs, unions, and memory allocated opaque types.

The challenge in this is to make child substructures keep the parent alive while they are reachable in Scheme.  This is done by keeping a table with the dependent objects as weak keys and the depended-upon objects as strong values.  In addition, a will is set on the dependent object so it will delete the entry in that table when the dependent has become weakly reachable.  See `ffi-types-lib.scm`.

A problem with this approach is that if you keep a weak reference to a dependent object you may be able to access invalid memory through it, perhaps causing memory corruption or segmentation faults.  So if you use this library, or some bindings that use it, **avoid weak references (including wills)** to foreign objects unless you know what you're doing.

