(define (test-equal actual expected #!optional comment)
  (if (not (equal? actual expected))
    (begin
      (newline)
      (if comment
        (println "FAILED: " comment))
      (println "expected:")
      (write expected)
      (newline)
      (println "actual:")
      (write actual)
      (newline)
      (error 'test-equal-failure))))

