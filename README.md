gambit-ffi-types
================

This library provides Scheme-friendly management of C structs, unions, and memory allocated opaque types.  For conciseness, we'll refer to all of these as 'structs' in this text.

C structs are accessed and modified in place.  Only primitives (integers, strings, etc.) are copied when converting from Scheme to C and back.  So, for example, you can pass such a struct to a C function that modifies its argument in place, and any changes will be reflected when you next access the fields in that struct after the call returns.

The library takes care to maintain the lifecycle of your objects in a schemey way: they will be kept around only as long as you have references to them (or to some field of them, or to some subfield of a field of them, etc.)

## Usage

### An example

To use, include `ffi-types-include.scm` and load or compile `ffi-types-lib.scm` with your application.  Then, if you have a declaration like the following in a C file or a `c-define`:

    struct point_node {
        struct point {
            int x;
            int y;
        } point;
        struct point_node *next;
    };

You model it in Scheme like this

    (c-struct point
      (int x)
      (int y))

    (c-struct point_node
      (struct point point)
      (pointer struct point_node next))

And use it like this

    ; Create instances.
    (define a (make-point_node))
    (define p (point_node-point a))

    ; Check their type.
    (println (point_node? a))  ; -> #t
    (println (point? a))  ; -> #f

    ; Set primitive fields.
    (point-x-set! p 1)

    ; Get the values of primitive fields.
    (println (point-x p)) ; -> 1

    ; Set non-primitive fields (copy semantics).
    (define q (make-point))
    (point-x-set! q 2)
    (point_node-point-set! a q)
    (point-x p)  ; 2

    ; Set pointer fields.
    (define b (make-point_node))
    (point_node-next-set! b a)
    (point-x-set! (point_node-point (point_node-next b)) 3)
    (point-x p) ; -> 3

    ; Since p points to memory in a, the library will make sure not to
    ; deallocate that memory while you have a reference to p.
    (set! a #f)
    (##gc)
    (point-x p) ; -> 2, not a segfault or garbage.

    ; By default the library doesn't do that for pointer links, but you
    ; can tell it that b depends on a, and the library will make sure
    ; a is not reclaimed while a dependency on b is set.
    (include "ffi-types#.scm")
    (register-dependency! b a)
    (set! p #f)
    (##gc)
    (point-x (point_node-point (point_node-next b))) ; -> 2

    ; But objects will be automatically reclaimed when there are no more
    ; direct or indirect references to them.
    (set! b #f)

    ; The space for both a and b can no longer be accessed from scheme code,
    ; so it will be reclaimed on garbage collection.

### Syntax

In general, you wrap C struct, union, or opaque types like this

   `(c-struct|c-union|c-type` _name_ _field_ ...`)`

Where _name_ is the name of the C type, exactly as declared in the C source file or `c-declare` form, and each _field_ describes one of the fields in the struct/union/type.  The order in which you specify the fields doesn't matter, and you don't need to mention all the fields in the C struct/union/type; only those you want to access from scheme code.

Each _field_ has the form:
   `([[pointer] struct|union|type]` _type-name_ _field-name_`)`

Where
- `pointer` should be indicated if the field is a pointer (that is, if space for the struct is not allocated in the containing struct itself.)
- `struct`, `union`, or `type` should be specified if the field is not a primitive type.  Note that at this moment pointers to primitive types are not supported (but should be easy to add if you need them.)
- _type-name_ is the name of the struct, union or type if the field is composite, or the name of the type (as described in the Gambit manual; for example, `char-string` if the field is a string) if the field is primitive.
- _field-name_ is the name of the field, exactly as declared in the C source file or `c-define` form.

See (`integration-test.scm`)[https://github.com/euccastro/gambit-ffi-types/blob/master/integration-test.scm] (after the `; BEGIN TESTS` comment) for usage examples.

## Implementation

The challenge in this is to make child substructures keep the parent alive while they are reachable in Scheme.  This is done by keeping an assoc list mapping the serial numbers (as in `object->serial-number`) of the dependent objects as 'keys' and the depended-upon objects as 'values'.  The table is scanned on every garbage collection, and the entries for which the serial number is no longer in `##serial-number-to-object-table` are discarded.  See `ffi-types-lib.scm`.
