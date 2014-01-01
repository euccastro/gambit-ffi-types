(##namespace ("ffi-types-impl#"))
(##include "~~/lib/gambit#.scm")
(include "ffi-types#.scm")


(define (filter pred? l)
  (cond ((null? l) '())
        ((pred? (car l))
         (cons (car l) (filter pred? (cdr l))))
        (else
          (filter pred? (cdr l)))))

(define refs '())

(define (cleanup-dependencies!)
  (declare (not interrupts-enabled))
  (set! refs
    (filter
      (lambda (pair)
        (table-ref ##serial-number-to-object-table (car pair) #f))
      refs)))

(define (register-dependency! dependent object)
  (declare (not interrupts-enabled))
  (set! refs (cons (list (object->serial-number dependent) object)
                   refs)))

(##add-gc-interrupt-job! cleanup-dependencies!)
