(load "c-record-util")

(namespace ("ffi-util#"))
(##include "~~/lib/gambit#.scm")

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
    (predicate 'struct 'point)
    '(define (point? x)
       (and (foreign? x)
            (eq (car (foreign-tags x)) '|struct point|))))

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
    (type-accessor 'struct 'point 'union 'coord 'x)
    '(define (point-x parent)
       (let ((ret
               ((c-lambda (point) unmanaged-coord
                "___result_voidstar = &((struct point*)___arg1_voidstar)->x;")
                parent)))
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
    (pointer-cast 'struct 'point)
    '(define (point-pointer x)
       (let ((ret ((c-lambda (point) (pointer point)
                    "___result_voidstar = ___arg1_voidstar;")
                   x)))
         (ffi#link! x ret)
         ret)))

  (test-equal
    (pointer-predicate 'struct 'point)
    '(define (point-pointer? x)
       (and (foreign? x) (eq (car (foreign-tags x)) '|struct point*|))))

  (test-equal
    (pointer-dereference 'struct 'point)
    '(define (pointer->point x)
       (let ((ret
               ((c-lambda (pointer point) point
                 "___result_voidstar = ___arg1_voidstar;")
                x)))
         (ffi#link! x ret)
         ret)))

  (test-equal
    (array-allocator 'struct 'point)
    '(define make-point-array
       (c-lambda
         (size_t)
         point-array
         "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct point)) * ___arg1;")))

  (test-equal
    (pointer-offset 'struct 'point)
    '(define (point-pointer-offset ptr diff)
       (let ((ret
               ((c-lambda ((pointer point) ptrdiff_t) (pointer point)
                  "___result_voidstar = (struct point*)___arg1_voidstar + ___arg2;") ptr diff)))
         (ffi#link! ptr ret)
         ret)))

  (test-equal
    (apply struct '(salad (int n_tomatoes) (union dressing dressing)))
    '(begin
       (c-define-type salad (struct "salad" (|struct salad| |struct salad*|)))
       (c-define-type
         unmanaged-salad
         (struct "salad" (|struct salad| |struct salad*|)
                 "___release_pointer"))
       (c-define-type
         salad-array
         (pointer salad |struct salad*| "____ffi_release_array"))
       (define (salad? x)
         (and (foreign? x)
              (eq (car (foreign-tags x)) '|struct salad|)))
       (define make-salad
         (c-lambda () salad
           "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct salad));"))
       (define make-salad-array
         (c-lambda
           (size_t)
           salad-array
           "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct salad)) * ___arg1;"))
       (define (salad-pointer x)
         (let ((ret ((c-lambda (salad) (pointer salad)
                               "___result_voidstar = ___arg1_voidstar;")
                     x)))
           (ffi#link! x ret)
           ret))
       (define (salad-pointer? x)
         (and (foreign? x) (eq (car (foreign-tags x))
                               '|struct salad*|)))
       (define (pointer->salad x)
         (let ((ret
                 ((c-lambda (pointer salad) salad
                            "___result_voidstar = ___arg1_voidstar;")
                  x)))
           (ffi#link! x ret)
           ret))
       (define (salad-pointer-offset ptr diff)
         (let ((ret
                 ((c-lambda ((pointer salad) ptrdiff_t) (pointer salad)
                            "___result_voidstar = (struct salad*)___arg1_voidstar + ___arg2;") ptr diff)))
           (ffi#link! ptr ret)
           ret))
       (define salad-n_tomatoes
         (c-lambda (salad) int
           "___result = ((struct salad*)___arg1_voidstar)->n_tomatoes;"))
       (define (salad-dressing parent)
         (let ((ret
                 ((c-lambda (salad) unmanaged-dressing
                            "___result_voidstar = &((struct salad*)___arg1_voidstar)->dressing;")
                  parent)))
           (ffi#link! parent ret)
           ret))
       (define salad-n_tomatoes-set!
         (c-lambda (salad int) void
           "((struct salad*)___arg1_voidstar)->n_tomatoes = ___arg2;"))
       (define salad-dressing-set!
         (c-lambda (salad dressing) void
           "((struct salad*)___arg1_voidstar)->dressing = *(union dressing)___arg2_voidstar;"))))

  (println "All OK."))

(test)
