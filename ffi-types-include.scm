(c-declare #<<c-declare-end
#ifndef FFI_INCLUDED
#define FFI_INCLUDED

// C hacks here

#endif
c-declare-end
)

(define-macro (ffi-types#at-expand-time . expr) (eval `(begin ,@expr)))

(ffi-types#at-expand-time
  (include "expand.scm"))

(define-macro (ffi-types#c-native categ name . fields)
              (apply (eval categ) name fields))

(define-macro (c-struct . etc)
  `(ffi-types#c-native struct ,@etc))

(define-macro (c-union . etc)
  `(ffi-types#c-native union ,@etc))

(define-macro (c-type . etc)
  `(ffi-types#c-native type ,@etc))
