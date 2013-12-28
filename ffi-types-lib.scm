(define (ffi-types#register-foreign-dependency! dependent obj)
  (cond
    ((not (foreign? dependent))
     (error `("Not a foreign object: " ,dependent)))
    ((not (= (##scheme-object-size-in-words dependent)
              ##dependent-foreign-size))
     (error `("Foreign is not dependent: " ,dependent)))
    (else
      (##register-foreign-dependency! dependent obj))))

(define ##foreign-dependencies
  (c-lambda (scheme-object) scheme-object
    "___result = ___FIELD(___arg1,___FOREIGN_DEP);"))

(define (##register-foreign-dependency! dependent obj)
  ((c-lambda (scheme-object scheme-object) void
     "___FIELD(___arg1,___FOREIGN_DEP) = ___arg2;")
   dependent
   (cons obj (##foreign-dependencies dependent))))

(define ##scheme-object-size-in-words
  (c-lambda (scheme-object) size_t #<<c-lambda-end

___WORD *body = ___BODY(___arg1);
___result = ___HD_WORDS(body[-1]);

c-lambda-end
))

(define ##dependent-foreign-size
  ((c-lambda () size_t "___result = ___FOREIGN_DEP + 1;")))
