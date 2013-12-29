(##namespace ("ffi-types-impl#"))
(##include "~~/lib/gambit#.scm")
(##include "ffi-types#.scm")


(define (register-foreign-dependency! dependent obj)
  (cond
    ((not (foreign? dependent))
     (error `("Not a foreign object: " ,dependent)))
    ((not (= (scheme-object-size-in-words dependent)
              dependent-foreign-size))
     (error `("Foreign is not dependent: " ,dependent)))
    (else
      (ffi-types-impl#register-foreign-dependency! dependent obj))))

(define foreign-dependencies
  (c-lambda (scheme-object) scheme-object
    "___result = ___FIELD(___arg1,___FOREIGN_DEP);"))

(define (ffi-types-impl#register-foreign-dependency! dependent obj)
  ((c-lambda (scheme-object scheme-object) void
     "___FIELD(___arg1,___FOREIGN_DEP) = ___arg2;")
   dependent
   (cons obj (foreign-dependencies dependent))))

(define scheme-object-size-in-words
  (c-lambda (scheme-object) size_t #<<c-lambda-end

___result = ___HD_WORDS(___BODY(___arg1)[-1]);

c-lambda-end
))

(define dependent-foreign-size
  ((c-lambda () size_t "___result = ___FOREIGN_DEP + 1;")))

(define foreign-release-function
  (c-lambda (scheme-object) (pointer void)
    "___result_voidstar = ___CAST(void*,___FIELD(___arg1,___FOREIGN_RELEASE_FN));"))

(define foreign-tags-set!
  (c-lambda (scheme-object scheme-object) void
    "___FIELD(___arg1,___FOREIGN_TAGS) = ___arg2;"))

(define foreign-release-function-set!
  (c-lambda (scheme-object (pointer void)) void
    "___FIELD(___arg1,___FOREIGN_RELEASE_FN) = ___CAST(___SCMOBJ,___arg2_voidstar);"))
