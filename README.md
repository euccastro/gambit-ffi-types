gambit-ffi-types
================

WORK IN PROGRESS

This will become a module that provides Scheme-friendly management of C structs, unions, and memory allocated opaque types.

The challenge in this is to make child substructures keep the parent alive while they are reachable in Scheme.  I plan to do this by storing references to "parent" structures in a table, and setting a will on the "child" that
deletes that entry.  See `ffi-types-lib.scm`.
