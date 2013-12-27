(c-declare #<<c-declare-end
#ifndef FFI_INCLUDED
#define FFI_INCLUDED

// C hacks here

#endif
c-declare-end
)

(define-macro (at-expand-time . expr) (eval `(begin ,@expr)))

(at-expand-time
  (include "expand.scm"))

(define-macro (c-native categ name . fields)
              (apply (eval categ) name fields))

(define-macro (c-struct . etc)
  `(c-native struct ,@etc))

(define-macro (c-union . etc)
  `(c-native union ,@etc))

