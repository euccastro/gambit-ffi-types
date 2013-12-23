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

(define (predicate categ name)
  `(define (,(symbol-append name "?") x)
     (and (foreign? x) (eq (car (foreign-tags x))
                           (quote ,(primary-tag categ name))))))

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

(define (type-accessor categ name attr-categ attr-type attr-name)
  `(define (,(symbol-append name "-" attr-name) parent)
     (let ((ret
             ((c-lambda (,name) ,(unmanaged-name attr-type)
                ,(string-append*
                    "___result_voidstar = &((" categ " " name
                    "*)___arg1_voidstar)->" attr-name ";"))
              parent)))
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

(define (pointer-cast categ name)
  `(define (,(symbol-append name "-pointer") x)
     (let ((ret ((c-lambda (,name) (pointer ,name)
                    "___result_voidstar = ___arg1_voidstar;")
                 x)))
       (ffi#link! x ret)
       ret)))

(define (pointer-predicate categ name)
  `(define (,(symbol-append name "-pointer?") x)
     (and (foreign? x)
          (eq (car (foreign-tags x))
              (quote ,(pointer-tag categ name))))))

(define (pointer-dereference categ name)
  `(define (,(symbol-append "pointer->" name) x)
     (let ((ret
             ((c-lambda (pointer ,name) ,name
                 "___result_voidstar = ___arg1_voidstar;")
              x)))
       (ffi#link! x ret)
       ret)))

(define (array-allocator categ name)
  `(define ,(symbol-append "make-" name "-array")
     (c-lambda (size_t) ,(symbol-append name "-array")
       ,(string-append* "___result_voidstar = ___EXT(___alloc_rc)(sizeof("
                        categ " " name ")) * ___arg1;"))))

(define (pointer-offset categ name)
  `(define (,(symbol-append name "-pointer-offset") ptr diff)
     (let ((ret
             ((c-lambda ((pointer ,name) ptrdiff_t) (pointer ,name)
                ,(string-append*
                   "___result_voidstar = (" categ " " name "*)___arg1_voidstar + ___arg2;"))
              ptr diff)))
       (ffi#link! ptr ret)
       ret)))

(define (struct . args)
  (apply categ-type 'struct args))

(define (union . args)
  (apply categ-type 'union args))

(define (type . args)
  (apply categ-type 'type args))

(define (categ-type categ name . fields)
  (define (map-fields primitive-fn type-fn)
    (map (lambda (field)
           (let ((primitive (= 2 (length field))))
             (apply
               (if primitive primitive-fn type-fn)
               categ name field)))
         fields))
  (append
    '(begin)
    (map (lambda (fn) (fn categ name))
         (list managed-type
               unmanaged-type
               array-type
               predicate
               allocator
               array-allocator
               pointer-cast
               pointer-predicate
               pointer-dereference
               pointer-offset))
    (map-fields primitive-accessor type-accessor)
    (map-fields primitive-mutator type-mutator)))

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
  (list (primary-tag categ name)
        ; Accept pointers too; they're essentially the same thing.
        (pointer-tag categ name)))
(define (primary-tag categ name)
  (symbol-append categ " " name))
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
