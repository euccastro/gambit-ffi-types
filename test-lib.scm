(define (test-equal actual expected)
  (if (not (equal? actual expected))
    (begin
      (println "expected:")
      (write expected)
      (newline)
      (println "actual:")
      (write actual)
      (newline)
      (error 'test-equal-failure))))

