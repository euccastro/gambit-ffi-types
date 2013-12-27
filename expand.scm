;XXX: namespaces.

(define (root-type categ name)
  `(c-define-type
     ,name
     (,categ ,(symbol->string name) ,(tags categ name))))

(define (dependent-type categ name)
  `(c-define-type ,(dependent-name name)
     ,(c-pointer-tag categ name)
     "DEPPOINTER_TO_SCMOBJ"
     "SCMOBJ_TO_DEPPOINTER"
     #f))

(define (predicate categ name)
  `(define (,(symbol-append name "?") x)
     (and (foreign? x)
          (memq
            (car (foreign-tags x))
            ',(tags categ name))
          #t)))

(define (allocator categ name)
  `(define ,(symbol-append "make-" name)
     (c-lambda
       ()
       ,name
       ,(string-append
          "___result_voidstar = ___EXT(___alloc_rc)(sizeof("
          (c-tag categ name) "));"))))

(define (primitive-accessor categ name attr-type attr-name)
  `(define ,(symbol-append name "-" attr-name)
     (c-lambda
       (,name)
       ,attr-type
       ,(string-append*
          "___result = ((" (c-pointer-tag categ name) ")___arg1_voidstar)->"
          attr-name ";"))))

(define (dependent-accessor categ name attr-categ attr-type attr-name)
  `(define (,(symbol-append name "-" attr-name) parent)
     (let ((ret
             ((c-lambda (,name) ,(dependent-name attr-type)
                ,(string-append*
                    "___result_voidstar = &((" (c-pointer-tag categ name)
                    ")___arg1_voidstar)->" attr-name ";"))
              parent)))
       ; XXX: namespaces, and enable ##register-foreign-dependency! in
       ;      production for performance.
       (register-foreign-dependency! ret parent)
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

(define (dependent-mutator categ name attr-categ attr-type attr-name)
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
         (list root-type
               dependent-type
               predicate
               allocator))
    (map-fields primitive-accessor dependent-accessor)
    (map-fields primitive-mutator dependent-mutator)))

; Internal utility.

(define (*->string x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        (else (error "Unsupported type"))))

(define (string-append* . args)
  (apply string-append (map *->string args)))

(define (symbol-append . args)
  (string->symbol (apply string-append* args)))

(define (dependent-name name)
  (symbol-append "dependent-" name))

(define (tags categ name)
  (list (c-tag-symbol categ name)
        ; Accept pointers too; they're essentially the same thing.
        (c-pointer-tag-symbol categ name)))

(define (c-tag categ name)
  (if (eq? categ 'type)
    (symbol->string name)
    (string-append* categ " " name)))

(define (c-pointer-tag categ name)
  (string-append (c-tag categ name) "*"))

(define (c-tag-symbol categ name)
  (string->symbol (c-tag categ name)))

(define (c-pointer-tag-symbol categ name)
  (string->symbol (c-pointer-tag categ name)))
