(import (scheme base)
	(scheme write)
	(srfi 18)
	(srfi 230))

(define *atomic-counter* (make-atomic-box 0.0))

(define (task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    ;(atomic-fxbox+/fetch! *atomic-counter* 1)
    (let loop ()
      (let ((expected (atomic-box-ref *atomic-counter*)))
        (if (not (eq? expected (atomic-box-compare-and-swap! *atomic-counter* expected (+ expected 1))))
            (loop))))
    ))

(define threads (make-vector 10))

(do ((i 0 (+ i 1)))
    ((= i 10))
  (let ((thread (make-thread task)))
    (vector-set! threads i thread)
    (thread-start! thread)))

(do ((i 0 (+ i 1)))
    ((= i 10))
  (thread-join! (vector-ref threads i)))

(display (atomic-box-ref *atomic-counter*))
(newline)
