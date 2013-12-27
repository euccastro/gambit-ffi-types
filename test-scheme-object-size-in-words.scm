(c-declare "typedef struct { int x; int y; } point;")

(c-define-type point* (pointer "point"))

(c-define-type dependent-point*
  "point*" "DEPPOINTER_TO_SCMOBJ" "SCMOBJ_TO_DEPPOINTER" #f)

(define p ((c-lambda () point* "___result_voidstar = ___EXT(___alloc_rc)(sizeof(point));")))
(define dp ((c-lambda (point*) dependent-point* "___result = ___arg1_voidstar;") p))

(test-equal (##scheme-object-size-in-words dp) ##dependent-foreign-size)
(test-equal (##scheme-object-size-in-words p) (- ##dependent-foreign-size 1))
