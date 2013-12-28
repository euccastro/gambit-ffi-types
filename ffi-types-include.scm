(c-declare #<<c-declare-end
#ifndef FFI_INCLUDED
#define FFI_INCLUDED

// C hacks here

#endif
c-declare-end
)


(define-macro (ffi-types#c-native categ name . fields)
  (eval '(begin (##include "expand.scm")))
  (apply (eval categ) name fields))

(define-macro (c-struct . etc)
  `(ffi-types#c-native struct ,@etc))

(define-macro (c-union . etc)
  `(ffi-types#c-native union ,@etc))

(define-macro (c-type . etc)
  `(ffi-types#c-native type ,@etc))
