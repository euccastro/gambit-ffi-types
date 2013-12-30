(define ffi-types#register-dependency!
  (let ((ref-table (make-table weak-keys: #t)))
    (lambda (dependent object)
      (table-set! ref-table dependent object)
      (make-will dependent (lambda (x) (table-set! ref-table x))))))
