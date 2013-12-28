(define-macro (test-true expr)
  `(or ,expr
       (begin (write ',expr)
              (println " should be true but isn't!")
              (error 'test-true-failure))))

(define-macro (test-false expr)
  `(or (not ,expr)
       (begin (write ',expr)
              (println " should be true but isn't!")
              (error 'test-true-failure))))
