(define-macro (ffi-types-impl#c-native categ name . fields)
  (eval '(begin (##include "expand.scm")))
  (apply (eval categ) name fields))

(define-macro (c-struct . etc)
  `(ffi-types-impl#c-native struct ,@etc))

(define-macro (c-union . etc)
  `(ffi-types-impl#c-native union ,@etc))

(define-macro (c-type . etc)
  `(ffi-types-impl#c-native type ,@etc))
