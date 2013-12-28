(include "ffi-types-include.scm")
(include "test-macro.scm")

(c-declare #<<c-declare-end


struct point_s { int x; int y; };
union point_u { int x; int y; };
typedef struct { int x; int y; } point;

typedef struct {
    point p;
    point q;
} segment;


/* Utilities for lifecycle debugging. */

int is_still_address(unsigned long address) {
    ___rc_header *start, *current;
    start = &___VMSTATE_FROM_PSTATE((___PSTATE))->mem.rc_head_;
    for (current=start->next; current != start; current=current->next) {
        if ((unsigned long)(current + 1) == address) {
            return 1;
        }
    }
    return (unsigned long)(start + 1) == address;
}

c-declare-end
)

(define (address-dead? a)
  (not ((c-lambda (unsigned-long) bool "is_still_address") a)))

; Basic struct with primitive accessors and mutators.

(c-struct point_s
  (int x)
  (int y))

(let* ((s (make-point_s))
       (a (foreign-address s)))
    (point_s-x-set! s 1)
    (point_s-y-set! s 2)
    (test-equal (list (point_s-x s) (point_s-y s)) '(1 2))
    (test-false (address-dead? a))
    (set! s #f)
    (##gc)
    (test-true (address-dead? a)))


; Basic union with primitive accessors and mutators.

(c-union point_u
  (int x)
  (int y))

(let* ((u (make-point_u))
       (a (foreign-address u)))
  (point_u-x-set! u 3)
  (test-equal (point_u-y u) 3)
  (test-false (address-dead? a))
  (set! u #f)
  (##gc)
  (test-true (address-dead? a)))


; Basic struct exposed as opaque type, with primitive accessors and mutators.

(c-type point
  (int x)
  (int y))

(let* ((t (make-point))
       (a (foreign-address t)))
  (point-x-set! t 4)
  (point-y-set! t 5)
  (test-equal (list (point-x t) (point-y t)) '(4 5))
  (test-false (address-dead? a))
  (set! t #f)
  (##gc)
  (test-true (address-dead? a)))

; Basic contained structure.

(c-type segment
  (type point p)
  (type point q))

(let* ((s (make-segment))
       (a (foreign-address s))
       (p (segment-p s))
       (other-point (make-point))
       (oa (foreign-address other-point)))
  (point-x-set! p 0)
  (point-x-set! other-point 6)
  (segment-p-set! s other-point)
  (test-equal (point-x p) 6 "copy by value")
  (test-false (address-dead? a))
  (set! s #f)
  (##gc)
  (test-false (address-dead? a) "dependent reference keeps root alive")
  (set! p #f)
  (##gc)
  (test-true (address-dead? a)))

