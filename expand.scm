; XXX hygiene, e.g. what if a field is called `ret`?

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

(define (tags-and-release-function categ name)
  `(begin
     (define ,(tags-name categ name) #f)
     (define ,(release-function-name categ name) #f)
     (let ((prototype
             ((c-lambda () ,name
                ,(string-append "___ASSIGN_NEW(___result_voidstar,"
                                (c-tag categ name) ");")))))
       (set! ,(tags-name categ name)
         (foreign-tags prototype))
       (set! ,(release-function-name categ name)
         (ffi-types-impl#foreign-release-function prototype)))))

(define (predicate categ name)
  `(define (,(symbol-append name "?") x)
     (and (foreign? x)
          (memq
            (car (foreign-tags x))
            ',(tags categ name))
          #t)))

(define (allocator categ name)
  `(define (,(symbol-append "make-" name))
     (let ((ret ((c-lambda () ,(dependent-name name)
                   ,(string-append
                      "___ASSIGN_NEW(___result," (c-tag categ name) ");")))))
       (ffi-types-impl#foreign-tags-set!
         ret
         ,(tags-name categ name))
       (ffi-types-impl#foreign-release-function-set!
         ret
         ,(release-function-name categ name))
       ret)))

(define (primitive-accessor categ name attr-type attr-name)
  `(define ,(accessor-name name attr-name)
     (c-lambda
       (,name)
       ,attr-type
       ,(string-append*
          "___result = ((" (c-pointer-tag categ name) ")___arg1_voidstar)->"
          attr-name ";"))))

(define (type-accessor categ name attr-categ attr-type attr-name pointer?)
  `(define (,(accessor-name name attr-name) parent)
     (let ((ret
             ((c-lambda (,name) ,(dependent-name attr-type)
                ,(string-append*
                    "___result = "
                    (if pointer? "" "&")
                    "((" (c-pointer-tag categ name)
                    ")___arg1_voidstar)->" attr-name ";"))
              parent)))
       (ffi-types-impl#foreign-tags-set! ret ,(tags-name attr-categ attr-type))
       ,@(if pointer?
           '()
           '((ffi-types-impl#register-foreign-dependency! ret parent)))
       ret)))

(define (dependent-accessor categ name attr-categ attr-type attr-name)
  (type-accessor categ name attr-categ attr-type attr-name #f))

(define (pointer-accessor categ name _ attr-categ attr-type attr-name)
  (type-accessor categ name attr-categ attr-type attr-name #t))

(define (mutator name attr-type attr-name c-lambda-body)
  `(define ,(symbol-append name "-" attr-name "-set!")
     (c-lambda (,name ,attr-type) void
       ,c-lambda-body)))

(define (primitive-mutator categ name attr-type attr-name)
  (mutator name attr-type attr-name
    (string-append*
      "((" (c-pointer-tag categ name) ")___arg1_voidstar)->" attr-name
      " = ___arg2;")))

(define (type-mutator categ name attr-categ attr-type attr-name pointer?)
  (mutator name attr-type attr-name
    (string-append*
      "((" (c-pointer-tag categ name) ")___arg1_voidstar)->" attr-name " = "
      (if pointer? "" "*")
      "(" (c-pointer-tag attr-categ attr-type) ")___arg2_voidstar;")))

(define (dependent-mutator categ name attr-categ attr-type attr-name)
  (type-mutator categ name attr-categ attr-type attr-name #f))

(define (pointer-mutator categ name _ attr-categ attr-type attr-name)
  (type-mutator categ name attr-categ attr-type attr-name #t))

(define (struct . args)
  (apply categ-type 'struct args))

(define (union . args)
  (apply categ-type 'union args))

(define (type . args)
  (apply categ-type 'type args))

(define (categ-type categ name . fields)
  (define (map-fields primitive-fn type-fn pointer-fn)
    (map (lambda (field-args)
           (apply
             (case (length field-args)
               ((2) primitive-fn)
               ((3) type-fn)
               ((4) (if (eq? (car field-args) 'pointer)
                      pointer-fn
                      (error (list "Unknown type: " field-args))))
               (else (error (list "Invalid number of arguments: " field-args))))
             categ name field-args))
         fields))
  (append
    '(begin)
    (map (lambda (fn) (fn categ name))
         (list root-type
               dependent-type
               tags-and-release-function
               predicate
               allocator))
    (map-fields primitive-accessor dependent-accessor pointer-accessor)
    (map-fields primitive-mutator dependent-mutator pointer-mutator)))


; Internal utility.

(define (*->string x)
  (cond ((string? x) x)
        ((symbol? x) (symbol->string x))
        (else (error (list "Unsupported type" x)))))

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

(define (string-upcase s)
  (list->string (map char-upcase (string->list s))))

(define (symbol-upcase s)
  (string->symbol (string-upcase (symbol->string s))))

(define (*-upcase s)
  (cond ((string? s) (string-upcase s))
        ((symbol? s) (symbol-upcase s))
        (else (error (list "Unsupported type: " s)))))

(define (release-function-name categ name)
  (symbol-append "ffi-types-impl#" categ "-" name "-release-fn"))

(define (tags-name categ name)
  (symbol-append "ffi-types-impl#" categ "-" name "-tags"))

(define (accessor-name name attr-name)
  (symbol-append name "-" attr-name))
