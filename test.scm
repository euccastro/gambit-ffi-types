(include "ffi-types-include.scm")

(c-declare "struct point {int x; int y;};")

(c-struct point (int x) (int y))

(define p (make-point))

(point-x-set! p 7)
(point-y-set! p 8)

(println "Got point (" (point-x p) ", " (point-y p) ").")
