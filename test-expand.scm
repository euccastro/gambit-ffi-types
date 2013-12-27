(load "expand")
(load "test-lib")

(define (test)

  (test-equal
    (root-type 'struct 'point)
    '(c-define-type point (struct "point" (|struct point| |struct point*|))))

  (test-equal
    (dependent-type 'struct 'point)
    '(c-define-type
       dependent-point
       "struct point*"
       "DEPPOINTER_TO_SCMOBJ"
       "SCMOBJ_TO_DEPPOINTER"
       #f))

  (test-equal
    (predicate 'struct 'point)
    '(define (point? x)
       (and (foreign? x)
            (memq (car (foreign-tags x)) '(|struct point| |struct point*|))
            #t)))

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
    (dependent-accessor 'struct 'point 'union 'coord 'x)
    '(define (point-x parent)
       (let ((ret
               ((c-lambda (point) dependent-coord
                "___result_voidstar = &((struct point*)___arg1_voidstar)->x;")
                parent)))
         (ffi-types-lib#register-foreign-dependency! ret parent)
         ret)))

  (test-equal
    (primitive-mutator 'struct 'point 'int 'x)
    '(define point-x-set!
       (c-lambda (point int) void
         "((struct point*)___arg1_voidstar)->x = ___arg2;")))

  (test-equal
    (dependent-mutator 'struct 'point 'union 'coord 'x)
    '(define point-x-set!
       (c-lambda (point coord) void
         "((struct point*)___arg1_voidstar)->x = *(union coord)___arg2_voidstar;")))

  (test-equal
    (apply struct '(salad (int n_tomatoes) (union dressing dressing)))
    '(begin
       (c-define-type salad (struct "salad" (|struct salad| |struct salad*|)))
       (c-define-type
         dependent-salad
         "struct salad*"
         "DEPPOINTER_TO_SCMOBJ"
         "SCMOBJ_TO_DEPPOINTER"
         #f)
       (define (salad? x)
         (and (foreign? x)
              (memq (car (foreign-tags x)) '(|struct salad| |struct salad*|))
              #t))
       (define make-salad
         (c-lambda () salad
           "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct salad));"))
       (define salad-n_tomatoes
         (c-lambda (salad) int
           "___result = ((struct salad*)___arg1_voidstar)->n_tomatoes;"))
       (define (salad-dressing parent)
         (let ((ret
                 ((c-lambda (salad) dependent-dressing
                            "___result_voidstar = &((struct salad*)___arg1_voidstar)->dressing;")
                  parent)))
           (ffi-types-lib#register-foreign-dependency! ret parent)
           ret))
       (define salad-n_tomatoes-set!
         (c-lambda (salad int) void
           "((struct salad*)___arg1_voidstar)->n_tomatoes = ___arg2;"))
       (define salad-dressing-set!
         (c-lambda (salad dressing) void
           "((struct salad*)___arg1_voidstar)->dressing = *(union dressing)___arg2_voidstar;")))))

(test)
