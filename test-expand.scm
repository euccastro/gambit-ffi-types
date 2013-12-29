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

  (test-equal (tags-and-release-function 'struct 'point)
    '(begin
       (define ffi-types-impl#struct-point-tags #f)
       (define ffi-types-impl#struct-point-release-fn #f)
       (let ((prototype
               ((c-lambda () point
                  "___ASSIGN_NEW(___result_voidstar,struct point);"))))
         (set! ffi-types-impl#struct-point-tags
           (foreign-tags prototype))
         (set! ffi-types-impl#struct-point-release-fn
           (ffi-types-impl#foreign-release-function prototype)))))

  (test-equal
    (predicate 'struct 'point)
    '(define (point? x)
       (and (foreign? x)
            (memq (car (foreign-tags x)) '(|struct point| |struct point*|))
            #t)))

  (test-equal
    (allocator 'struct 'point)
    '(define (make-point)
       (let ((ret ((c-lambda () dependent-point
                     "___ASSIGN_NEW(___result,struct point);"))))
         (ffi-types-impl#foreign-tags-set!
           ret
           ffi-types-impl#struct-point-tags)
         (ffi-types-impl#foreign-release-function-set!
           ret
           ffi-types-impl#struct-point-release-fn)
         ret)))

  (test-equal
    (primitive-accessor 'struct 'point 'int 'x)
    '(define point-x
       (c-lambda (point) int
         "___result = ((struct point*)___arg1_voidstar)->x;")))

  (test-equal
    (dependent-accessor 'struct 'point 'union 'coord 'x)
   '(define (point-x parent)
      (let ((ret ((c-lambda (point) dependent-coord
                    "___result = &((struct point*)___arg1_voidstar)->x;") parent)))
        (ffi-types-impl#foreign-tags-set! ret ffi-types-impl#union-coord-tags)
        (ffi-types-impl#register-foreign-dependency! ret parent)
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
         "((struct point*)___arg1_voidstar)->x = *(union coord*)___arg2_voidstar;"))))

(test)
