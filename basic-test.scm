(include "ffi-types-include.scm")

(c-declare #<<c-declare-end

struct point_s { int x; int y; };
union point_u { int x; int y; };
typedef struct { int x; int y; } point_t;

typedef struct {
    struct point_s p;
    struct point_s q;
    } segment;

c-declare-end
)

; Basic struct with primitive accessors and mutators.

(c-struct point_s (int x) (int y))
(define s (make-point_s))
(point_s-x-set! s 1)
(point_s-y-set! s 2)
(test-equal (list (point_s-x s) (point_s-y s)) '(1 2))


; Basic union with primitive accessors and mutators.

(c-union point_u (int x) (int y))
(define u (make-point_u))
(point_u-x-set! u 3)
(test-equal (point_u-y u) 3)


; Basic struct exposed as opaque type, with primitive accessors and mutators.

(c-type point_t (int x) (int y))
(define t (make-point_t))
(point_t-x-set! t 4)
(point_t-y-set! t 5)
(test-equal (list (point_t-x t) (point_t-y t)) '(4 5))

