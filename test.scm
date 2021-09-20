;; Copyright (C) Justin Ethier (2021).  All Rights Reserved.

;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

(import (scheme base)
	(scheme write)
	(srfi 18)
	(srfi 230)
	(cyclone test))

;; Atomic flags - Basic example of using flags to create a spin lock
(define *flag* (make-atomic-flag))
(define *counter* 0)

(define (spin-lock flag)
  (let loop ()
    (if (atomic-flag-test-and-set! flag)
        (loop))))

(define (spin-unlock flag)
  (atomic-flag-clear! flag))

(define (atomic-flag-task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    (spin-lock *flag*)
    (set! *counter* (+ *counter* 1))
    (spin-unlock *flag*) ))

;; Atomic boxes
(define *atomic-box* (make-atomic-box 0.0))

(define (atomic-box-task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    (let loop ()
      (let ((expected (atomic-box-ref *atomic-box*)))
        (if (not (eq? expected (atomic-box-compare-and-swap! *atomic-box* expected (+ expected 1))))
            (loop))))))

;; Atomic fxboxes
(define *atomic-fxbox* (make-atomic-fxbox 0))

(define (atomic-fxbox-task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    (let loop ()
      (let ((expected (atomic-fxbox-ref *atomic-fxbox*)))
        (if (not (eq? expected (atomic-fxbox-compare-and-swap! *atomic-fxbox* expected (+ expected 1))))
            (loop))))
    ))

(define *atomic-counter* (make-atomic-fxbox 0))

(define (atomic-counter-task)
  (do ((i 0 (+ i 1)))
      ((= i 100000))
    (atomic-fxbox+/fetch! *atomic-counter* 1)
    ))

;; Core task runner
(define (run thunk result-thunk)
  (define threads (make-vector 10))

  (do ((i 0 (+ i 1)))
      ((= i 10))
    (let ((thread (make-thread thunk)))
      (vector-set! threads i thread)
      (thread-start! thread)))

  (do ((i 0 (+ i 1)))
      ((= i 10))
    (thread-join! (vector-ref threads i)))

  (result-thunk))

;; Test cases
(test-group "atomic flag"
  (test 1000000 (run atomic-flag-task
                       (lambda ()
                         *counter*))))

(test-group "atomic box"
  (test 1000000.0 (run atomic-box-task 
                       (lambda ()
                         (atomic-box-ref *atomic-box*)))))

(test-group "atomic fxbox"
  (test 1000000 (run atomic-fxbox-task 
                       (lambda ()
                         (atomic-fxbox-ref *atomic-fxbox*))))
  (test 1000000 (run atomic-counter-task
                       (lambda ()
                         (atomic-fxbox-ref *atomic-counter*))))
  )

(test-exit)
