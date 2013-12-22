(namespace ("ffi#"))
(##include "~~/lib/gambit#.scm")

(define link
  (let ((references (make-table
                      weak-keys: #t
                      weak-values: #f
                      test: eq?)))
    (lambda (parent child)
      (table-set!
        references
        child
        (cons parent
          (make-will child (lambda (x) (table-set! references x))))))))
