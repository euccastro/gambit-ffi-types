(define-macro (test-true expr . rest)
  `(or ,expr
       (begin (println "FAILED: " ',rest)
              (write ',expr)
              (println " should be true but isn't!")
              (error 'test-true-failure))))

(define-macro (test-false expr . rest)
  `(or (not ,expr)
       (begin (println "FAILED: " ',rest)
              (write ',expr)
              (println " should be true but isn't!")
              (error 'test-true-failure))))
