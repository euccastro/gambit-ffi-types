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

typedef struct {
    segment s;
    segment r;
} segment_pair;

typedef struct node {
   point *p;
   point *q;
} pointer_segment;

/* Utility for lifecycle debugging. */

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

; Helper functions for the tests.

(define (address-dead? a)
  (not ((c-lambda (unsigned-long) bool "is_still_address") a)))

(define (many-gcs)
  (let loop ((i 100))
    (##gc)
    (if (> i 0) (loop (- i 1)))))

(define (remove l e)
  (cond
    ((null? l) '())
    ((eqv? (car l) e)
     (cdr l))
    (else
      (cons (car l) (remove (cdr l) e)))))

(define (mappend fn l)
  (if (null? l)
    '()
    (append (fn (car l)) (mappend fn (cdr l)))))

(define (permutations l)
  (cond ((null? l) '())
        ((null? (cdr l)) (list l))
        (else
          (mappend
            (lambda (e)
              (map (lambda (perm) (cons e perm))
                   (permutations (remove l e))))
            l))))


; BEGIN TESTS

; Basic struct with primitive accessors and mutators.

(c-struct point_s
  (int x)
  (int y))

(let* ((s (make-point_s))
       (a (foreign-address s)))
    (test-equal (foreign-tags s)
                '(|struct point_s| |struct point_s*|)
                "struct tags")
    (test-equal (ffi-types-impl#scheme-object-size-in-words s)
                ffi-types-impl#dependent-foreign-size)
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
  (test-equal (foreign-tags u)
              '(|union point_u| |union point_u*|)
              "union tags")
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
  (test-equal (foreign-tags t) '(|point| |point*|) "type tags")
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
  (test-equal (foreign-tags p) '(|point| |point*|) "dependent accessor tags")
  (point-x-set! p 0)
  (point-x-set! other-point 6)
  (test-equal (point-x p) 0)
  (segment-p-set! s other-point)
  (test-equal (point-x p) 6 "copy by value")
  (point-x-set! other-point 7)
  (test-equal (point-x p) 6 "copy by value")
  (test-false (address-dead? a))
  (set! s #f)
  (##gc)
  (test-false (address-dead? a) "dependent reference keeps root alive")
  (set! p #f)
  (##gc)
  (test-true (address-dead? a)))


; Root with two direct dependents and one transitive one.  The only new thing
; to test here is lifecycle management.

(c-type segment_pair
  (type segment s)
  (type segment r))


; No matter in what order we release the direct or transitive references,
; only the last deletion gets the root reclaimed.

(let ((v (make-vector 4))
      (a #f))
  (for-each
    (lambda (permutation)
      (vector-set! v 0 (make-segment_pair))
      (set! a (foreign-address (vector-ref v 0)))
      (vector-set! v 1 (segment_pair-r (vector-ref v 0)))
      (vector-set! v 2 (segment_pair-s (vector-ref v 0)))
      (vector-set! v 3 (segment-q (vector-ref v 2)))
      (for-each
        (lambda (i)
          (##gc)
          (test-false (address-dead? a))
          (vector-set! v i #f))
        permutation)
      (##gc)
      (test-true (address-dead? a)))
    (permutations '(0 1 2 3))))


; User-defined dependencies; order of deletions doesn't really exercise them.

(let* ((d (make-point))
       (r (make-point))
       (rs (object->serial-number r))
       (ds (object->serial-number d))
       (ra (foreign-address r))
       (da (foreign-address d)))
  (ffi-types#register-foreign-dependency! d r)
  (test-true (table-ref ##serial-number-to-object-table ds #f)
             "dependent foreign alive at beginning")
  (test-true (table-ref ##serial-number-to-object-table rs #f)
             "root foreign alive at beginning")
  (test-false (address-dead? da)
              "dependent alive at beginning")
  (test-false (address-dead? ra)
              "root alive at beginning")
  (set! d #f)
  (##gc)
  (test-false (table-ref ##serial-number-to-object-table ds #f)
              "dependent foreign dead after killing d")
  (test-true (table-ref ##serial-number-to-object-table rs #f)
             "root foreign alive after killing d")
  (test-true (address-dead? da)
             "dependent dead after killing d")
  (test-false (address-dead? ra)
              "root alive after killing d")
  (set! r #f)
  (##gc)
  (test-false (table-ref ##serial-number-to-object-table ds #f)
              "dependent foreign dead after killing both")
  (test-false (table-ref ##serial-number-to-object-table rs #f)
              "root foreign dead after killing both")
  (test-true (address-dead? da)
             "dependent dead after killing both")
  (test-true (address-dead? ra)
             "root dead after killing both"))


; User-defined dependencies; order of deletions exercises them.

(let* ((d (make-point))
       (r (make-point))
       (rs (object->serial-number r))
       (ds (object->serial-number d))
       (ra (foreign-address r))
       (da (foreign-address d)))
  (ffi-types#register-foreign-dependency! d r)
  (test-true (table-ref ##serial-number-to-object-table ds #f)
             "dependent foreign alive at beginning")
  (test-true (table-ref ##serial-number-to-object-table rs #f)
             "root foreign alive at beginning")
  (test-false (address-dead? da)
              "dependent alive at beginning")
  (test-false (address-dead? ra)
              "root alive at beginning")
  (set! r #f)
  (##gc)
  (test-true (table-ref ##serial-number-to-object-table ds #f)
             "dependent foreign alive after killing r")
  (test-true (table-ref ##serial-number-to-object-table rs #f)
             "root foreign alive after killing r")
  (test-false (address-dead? da)
              "dependent alive after killing r")
  (test-false (address-dead? ra)
              "root alive after killing r")
  (set! d #f)
  (##gc)
  (test-false (table-ref ##serial-number-to-object-table ds #f)
              "dependent foreign dead after killing both")
  (test-false (table-ref ##serial-number-to-object-table rs #f)
              "root foreign dead after killing both")
  (test-true (address-dead? da)
             "dependent dead after killing both")
  (test-true (address-dead? ra)
             "root dead after killing both"))

; Pointer accessors and mutators.

(c-type pointer_segment
  (pointer type point p)
  (pointer type point q))

(let ((s (make-pointer_segment))
      (p (make-point))
      (q (make-point)))
  (pointer_segment-p-set! s p)
  (pointer_segment-q-set! s q)
  (point-x-set! p 8)
  (point-y-set! p 9)
  (point-x-set! q 10)
  (point-y-set! q 11)
  (test-equal (point-x (pointer_segment-p s)) 8)
  (test-equal (point-y (pointer_segment-p s)) 9)
  (test-equal (point-x (pointer_segment-q s)) 10)
  (test-equal (point-y (pointer_segment-q s)) 11))

