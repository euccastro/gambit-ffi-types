(namespace ("ffi-util#"))
(##include "~~/lib/gambit#.scm")

(define array-finalizer-declaration
  '(c-declare #<<c-declare-end
#ifndef FFI_DECLARE_FINALIZER
#define FFI_DECLARE_FINALIZER
___EXP_FUNC(___SCMOBJ,____ffi_finalize_array)___P((void *ptr),(ptr)
                                                  void *ptr;)
{
    ___EXT(___release_rc)(ptr);
    return ___FIX(___NO_ERR);
}

#endif
c-declare-end
))

(define (managed-type categ name)
  `(c-define-type
     ,name
     (,categ ,(symbol->string name) ,(tags categ name))))

(define (unmanaged-type categ name)
  `(c-define-type ,(unmanaged-name name)
     (,categ ,(symbol->string name) ,(tags categ name) "___release_pointer")))

(define (array-type categ name)
  `(c-define-type ,(symbol-append name "-array")
     (pointer ,name ,(pointer-tag categ name) "____ffi_release_array")))

(define (predicate name)
  `(define (,(symbol-append name "?") x)
     (and (foreign? x) (memq (quote ,name) (foreign-tags x)) #t)))

(define (allocator categ name)
  `(define ,(symbol-append "make-" name)
     (c-lambda
       ()
       ,name
       ,(string-append*
          "___result_voidstar = ___EXT(___alloc_rc)(sizeof("
          categ " " name "));"))))

(define (primitive-accessor categ name attr-type attr-name)
  `(define ,(symbol-append name "-" attr-name)
     (c-lambda
       (,name)
       ,attr-type
       ,(string-append*
          "___result = ((" categ " " name "*)___arg1_voidstar)->" attr-name ";"))))

(define (type-accessor categ name attr-type attr-name)
  `(define (,(symbol-append name "-" attr-name) parent)
     (let ((ret
             ((c-lambda (,name) ,(unmanaged-name attr-type)
                ,(string-append*
                    "___result_voidstar = &((" categ " " name
                    "*)___arg1_voidstar)->" attr-name ";")))))
       (ffi#link! parent ret)
       ret)))

(define (mutator name attr-type attr-name c-lambda-body)
  `(define ,(symbol-append name "-" attr-name "-set!")
     (c-lambda (,name ,attr-type) void
       ,c-lambda-body)))

(define (primitive-mutator categ name attr-type attr-name)
  (mutator name attr-type attr-name
    (string-append*
      "((" categ " " name "*)___arg1_voidstar)->" attr-name
      " = ___arg2;")))

(define (type-mutator categ name attr-categ attr-type attr-name)
  (mutator name attr-type attr-name
    (string-append*
      "((" categ " " name "*)___arg1_voidstar)->" attr-name
      " = *(" attr-categ " " attr-type ")___arg2_voidstar;")))

(define (take-pointer name)
  `(define (,(symbol-append name "-pointer") x)
     (let ((ret (c-lambda (,name) (pointer ,name)
                   "___result_voidstar = ___arg1_voidstar;")))
       (ffi#link! x ret)
       ret)))

(define (pointer-predicate name)
  `(define (,(symbol-append name "-pointer?") x)
     (and (foreign? x) (memq (quote ,name) (foreign-tags x)) #t)))

(define (pointer-dereference name)
  `(define (,(symbol-append "pointer->" name) x)
     (let ((ret
             ((c-lambda (pointer ,name) ,name
                 "___result_voidstar = ___arg1_voidstar;"))))
       (ffi#link! x ret)
       ret)))

(define (array-allocator categ name)
  `(define ,(symbol-append "make-" name "-array")
     (c-lambda (size_t) ,(symbol-append name "-array")
       ,(string-append* "___result_voidstar = ___EXT(___alloc_rc)(sizeof("
                        categ " " name ")) * ___arg1;"))))


; Internal utility.

(define (*->string x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        (else (error "Unsupported type"))))

(define (string-append* . args)
  (apply string-append (map *->string args)))

(define (symbol-append . args)
  (string->symbol (apply string-append* args)))

(define (unmanaged-name name)
  (symbol-append "unmanaged-" name))

(define (tags categ name)
  (list (symbol-append categ " " name)
        ; Accept pointers too; they're essentially the same thing.
        (pointer-tag categ name)))

(define (pointer-tag categ name)
  (symbol-append categ " " name "*"))

; Testing.

(define (test-equal actual expected)
  (if (not (equal? actual expected))
    (error `(expected: ,expected actual: ,actual))))

(define (test)
  (test-equal
    (managed-type 'struct 'point)
    '(c-define-type point (struct "point" (|struct point| |struct point*|))))
  (test-equal
    (unmanaged-type 'struct 'point)
    '(c-define-type
       unmanaged-point
       (struct "point" (|struct point| |struct point*|) "___release_pointer")))
  (test-equal
    (array-type 'struct 'point)
    '(c-define-type point-array (pointer point |struct point*| "____ffi_release_array")))
  (test-equal
    (predicate 'point)
    '(define (point? x)
       (and (foreign? x) (memq 'point (foreign-tags x)) #t)))
  (test-equal
    (allocator 'struct 'point)
    '(define make-point
       (c-lambda () point
         "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct point));")))
  (test-equal
    (primitive-accessor 'struct 'point 'int 'x)
    '(define point-x
       (c-lambda (point) int
         "___result = ((struct point*)___arg1_voidstar)->x;")))
  (test-equal
    (type-accessor 'struct 'point 'coord 'x)
    '(define (point-x parent)
       (let ((ret
               ((c-lambda (point) unmanaged-coord
                "___result_voidstar = &((struct point*)___arg1_voidstar)->x;"))))
         (ffi#link! parent ret)
         ret)))
  (test-equal
    (primitive-mutator 'struct 'point 'int 'x)
    '(define point-x-set!
       (c-lambda (point int) void
         "((struct point*)___arg1_voidstar)->x = ___arg2;")))
  (test-equal
    (type-mutator 'struct 'point 'union 'coord 'x)
    '(define point-x-set!
       (c-lambda (point coord) void
         "((struct point*)___arg1_voidstar)->x = *(union coord)___arg2_voidstar;")))
  (test-equal
    (take-pointer 'point)
    '(define (point-pointer x)
       (let ((ret (c-lambda (point) (pointer point)
                    "___result_voidstar = ___arg1_voidstar;")))
         (ffi#link! x ret)
         ret)))
  (test-equal
    (pointer-predicate 'point)
    '(define (point-pointer? x)
       (and (foreign? x) (memq 'point (foreign-tags x)) #t)))
  (test-equal
    (pointer-dereference 'point)
    '(define (pointer->point x)
       (let ((ret
               ((c-lambda (pointer point) point
                 "___result_voidstar = ___arg1_voidstar;"))))
         (ffi#link! x ret)
         ret)))
  (test-equal
    (array-allocator 'struct 'point)
    '(define make-point-array
       (c-lambda
         (size_t)
         point-array
         "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct point)) * ___arg1;")))
  (println "All OK."))

(test)
