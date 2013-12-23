(##include "expand#.scm")

(define-macro (at-expand-time . expr) (eval `(begin ,@expr)))

(define-macro (c-native categ name . fields)
              (at-expand-time
                (##include "expand.scm"))
              (apply (eval categ) name fields))

(define-macro (c-struct . etc)
  `(c-native struct ,@etc))

(define-macro (c-union . etc)
  `(c-native union ,@etc))

(c-declare #<<c-declare-end

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
)
