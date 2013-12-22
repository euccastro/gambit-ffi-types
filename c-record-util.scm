(namespace ("ffi-util#"))
(##include "~~/lib/gambit#.scm")


(define (type categ name)
  `(c-define-type ,name (,categ ,(symbol->string name) ,name)))

(define (unmanaged-type categ name)
  `(c-define-type ,(unmanaged-name name)
     (,categ ,(symbol->string name) ,name "___RELEASE_POINTER")))

(define (predicate name)
  `(define (,(symbol-append name "?") x)
     (and (foreign? x) (memq (quote ,name) (foreign-tags x)) #t)))

(define (constructor categ name)
  `(define ,(symbol-append "make-" name)
     (c-lambda
       ()
       ,name
       ,(string-append*
          "___result_voidstar = ___EXT(___alloc_rc)(sizeof("
          categ " " name "));"))))

(define (primitive-accessor categ name attr-name attr-type)
  `(define ,(symbol-append name "-" attr-name)
     (c-lambda
       (,name)
       ,attr-type
       ,(string-append*
          "___result = ((" categ " " name "*)___arg1_voidstar)->"
          attr-name ";"))))

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
    (type 'struct 'point)
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
    (constructor 'struct 'point)
    '(define make-point
       (c-lambda () point
         "___result_voidstar = ___EXT(___alloc_rc)(sizeof(struct point));")))
  (test-equal
    (primitive-accessor 'struct 'point 'x 'int)
    '(define point-x
       (c-lambda (point) int
         "___result = ((struct point*)___arg1_voidstar)->x;")))
  (println "All OK."))

(test)
