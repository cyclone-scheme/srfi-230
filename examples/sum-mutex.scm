(import (scheme base)
	(scheme write)
	(srfi 18)
	(srfi 230))

(define *lock* (make-mutex))
(define *counter* 0)

(define (task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    (mutex-lock! *lock*)
    (set! *counter* (+ *counter* 1))
    (mutex-unlock! *lock*)))

(define threads (make-vector 10))

(do ((i 0 (+ i 1)))
    ((= i 10))
  (let ((thread (make-thread task)))
    (vector-set! threads i thread)
    (thread-start! thread)))

(do ((i 0 (+ i 1)))
    ((= i 10))
  (thread-join! (vector-ref threads i)))

(display *counter*)
(newline)
