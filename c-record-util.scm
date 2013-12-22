(namespace ("ffi-util#"))
(##include "~~/lib/gambit#.scm")


(define (managed-type categ name)
  `(c-define-type ,name (,categ ,(symbol->string name) ,name)))

(define (unmanaged-type categ name)
  `(c-define-type ,(unmanaged-name name)
     (,categ ,(symbol->string name) ,name "___RELEASE_POINTER")))

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

; Testing.

(define (test-equal actual expected)
  (if (not (equal? actual expected))
    (error `(expected: ,expected actual: ,actual))))

(define (test)
  (test-equal
    (managed-type 'struct 'point)
    '(c-define-type point (struct "point" point)))
  (test-equal
    (unmanaged-type 'struct 'point)
    '(c-define-type
       unmanaged-point
       (struct "point" point "___RELEASE_POINTER")))
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
  (println "All OK."))

(test)
