;; This file contains an implementation of SRFI 230: Atomic Operations
;; using stdatomic.h, designed specifically for Cyclone Scheme.
;;
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

(define-library (srfi 230)
  (include-c-header "<stdatomic.h>")
  (include-c-header "utils.c")
  (export 
  memory-order
  memory-order?
  make-atomic-flag
  atomic-flag?
  atomic-flag-test-and-set!
  atomic-flag-clear!
  make-atomic-box
  atomic-box?
  atomic-box-ref
  atomic-box-set!
  atomic-box-swap!
  atomic-box-compare-and-swap!
  make-atomic-fxbox
  atomic-fxbox?
  atomic-fxbox-ref
  atomic-fxbox-set!
  atomic-fxbox-swap!
  atomic-fxbox-compare-and-swap!
  atomic-fxbox+/fetch!
  atomic-fxbox-/fetch!
  atomic-fxbox-and/fetch!
  atomic-fxbox-ior/fetch!
  atomic-fxbox-xor/fetch!
  atomic-fence
)
  (import (scheme base)
          (srfi 18))
  (begin

    ;; Internals

    (define-syntax memory-order
      (syntax-rules ()
        ((memory-order symbol) 'symbol)))

    (define (memory-order? obj)
      (and (memq
            obj
            '(relaxed acquire release acquire-release sequentially-consistent))
           #t))

    ;; Atomic flags

    (define-c %atomic-flag-init
      "(void *data, int argc, closure _, object k)"
      " atomic_flag f = ATOMIC_FLAG_INIT;
        atomic_flag *flag = malloc(sizeof(atomic_flag));
        make_c_opaque(opq, flag); 
        opaque_collect_ptr(&opq) = 1; // Allow GC to free() memory
        *flag = f;
        return_closcall1(data, k, &opq); ")

    (define-c %atomic-flag-tas
      "(void *data, int argc, closure _, object k, object opq)"
      " atomic_flag *flag = opaque_ptr(opq);
        _Bool b = atomic_flag_test_and_set(flag);
        return_closcall1(data, k, b ? boolean_t : boolean_f);")

    (define-c %atomic-flag-clear
      "(void *data, int argc, closure _, object k, object opq)"
      " atomic_flag *flag = opaque_ptr(opq);
        atomic_flag_clear(flag);
        return_closcall1(data, k, boolean_f);")

    (define-record-type atomic-flag
      (%make-atomic-flag content)
      atomic-flag?
      (content atomic-flag-content atomic-flag-set-content!))

    (define (make-atomic-flag)
      (define b (%make-atomic-flag (%atomic-flag-init)))
      (Cyc-minor-gc)
      b)

    (define (atomic-flag-check flag)
      (unless (atomic-flag? flag)
        (error "Expected atomic flag but received" flag)))

    (define (atomic-flag-test-and-set! flag . o)
      (atomic-flag-check flag)
      (%atomic-flag-tas (atomic-flag-content flag)))

    (define (atomic-flag-clear! flag . o)
      (atomic-flag-check flag)
      (%atomic-flag-clear (atomic-flag-content flag)))

    ;; Atomic boxes

    (define-c %atomic-box-init
      "(void *data, int argc, closure _, object k, object pair, object value)"
      " pair_type *p = (pair_type*)pair;
        atomic_init((uintptr_t *)&(p->pair_car), (uintptr_t)value);
        //v->elements[2] = (object)ptr;
        return_closcall1(data, k, pair); ")

    (define-c %atomic-box-load
      "(void *data, int argc, closure _, object k, object pair)"
      " pair_type *p = (pair_type*)pair;
        uintptr_t c = atomic_load((uintptr_t *)(&(p->pair_car)));
        return_closcall1(data, k, (object)c); ")

    (define-c %atomic-box-store
      "(void *data, int argc, closure _, object k, object pair, object value)"
      " pair_type *p = (pair_type*)pair;

        // Write barrier
        // TODO: support objects (closure, pair, vector) that require a GC
        //       see Cyc_set_car_cps() in runtime.c
        int do_gc = 0;
        value = transport_stack_value(data, pair, value, &do_gc);
        gc_mut_update((gc_thread_data *) data, car(pair), value);
        add_mutation(data, pair, -1, value); // Ensure val is transported

        atomic_store((uintptr_t *)(&(p->pair_car)), (uintptr_t)value);
        return_closcall1(data, k, value); ")

    (define-c %atomic-box-exchange
      "(void *data, int argc, closure _, object k, object pair, object value)"
      " pair_type *p = (pair_type*)pair;

        // Write barrier
        // TODO: support objects (closure, pair, vector) that require a GC
        //       see Cyc_set_car_cps() in runtime.c
        int do_gc = 0;
        value = transport_stack_value(data, pair, value, &do_gc);
        gc_mut_update((gc_thread_data *) data, car(pair), value);
        add_mutation(data, pair, -1, value); // Ensure val is transported

        uintptr_t c = atomic_exchange((uintptr_t *)(&(p->pair_car)), (uintptr_t)value);
        return_closcall1(data, k, (object)c); ")

    (define-c %atomic-box-compare-exchange
      "(void *data, int argc, closure _, object k, object pair, object expected, object desired)"
      " pair_type *p = (pair_type*)pair;
        uintptr_t old = (uintptr_t)expected;

        // Write barrier
        // TODO: support objects (closure, pair, vector) that require a GC
        //       see Cyc_set_car_cps() in runtime.c
        int do_gc = 0;
        desired = transport_stack_value(data, pair, desired, &do_gc);
        gc_mut_update((gc_thread_data *) data, car(pair), desired);
        add_mutation(data, pair, -1, desired); // Ensure val is transported

        atomic_compare_exchange_strong((uintptr_t *)(&(p->pair_car)), &old, (uintptr_t)desired);
        return_closcall1(data, k, (object)old); 
        ")

    (define-record-type atomic-box
      (%make-atomic-box content)
      atomic-box?
      (content atomic-box-content atomic-box-set-content!))

    (define (make-atomic-box c)
      (define b (%make-atomic-box (list #f)))
      (%atomic-box-init (atomic-box-content b) c) 
      (Cyc-minor-gc) ;; Force b onto heap
      b)

    (define (atomic-box-check box)
      (unless (atomic-box? box)
        (error "Expected atomic box but received" box)))

    (define (atomic-box-ref box . o)
      (atomic-box-check box)
      (%atomic-box-load (atomic-box-content box)))

    (define (atomic-box-set! box obj . o)
      (atomic-box-check box)
      (%atomic-box-store (atomic-box-content box) obj))

    (define (atomic-box-swap! box obj . o)
      (atomic-box-check box)
      (%atomic-box-exchange (atomic-box-content box) obj))

    (define (atomic-box-compare-and-swap! box expected desired . o)
      (atomic-box-check box)
      (%atomic-box-compare-exchange (atomic-box-content box) expected desired))

    ;; Atomic fixnum boxes

    ;; native ints are stored in a C opaque, otherwise GC could
    ;; think they are pointers
    (define-c %atomic-fxbox-init
      "(void *data, int argc, closure _, object k, object opq, object value)"
      " Cyc_check_fixnum(data, value);
        atomic_uintptr_t p;
        atomic_init(&p, (uintptr_t)obj_obj2int(value));
        opaque_ptr(opq) = (object)p;
        return_closcall1(data, k, opq); ")

    (define-c %empty-opaque
      "(void *data, int argc, closure _, object k)"
      " make_c_opaque(opq, NULL);
        return_closcall1(data, k, &opq); ")

    (define-c %atomic-fxbox-load
      "(void *data, int argc, closure _, object k, object opq)"
      " uintptr_t c = atomic_load((uintptr_t *)(&(opaque_ptr(opq))));
        return_closcall1(data, k, obj_int2obj(c)); ")

    (define-c %atomic-fxbox-store
      "(void *data, int argc, closure _, object k, object opq, object value)"
      " atomic_store((uintptr_t *)(&(opaque_ptr(opq))), (uintptr_t)obj_obj2int(value));
        return_closcall1(data, k, value); ")

    (define-c %atomic-fxbox-compare-exchange
      "(void *data, int argc, closure _, object k, object opq, object expected, object desired)"
      " uintptr_t old = (uintptr_t)obj_obj2int(expected);
        atomic_compare_exchange_strong((uintptr_t *)(&(opaque_ptr(opq))), &old, (uintptr_t)obj_obj2int(desired));
        return_closcall1(data, k, obj_int2obj(old)); 
        ")

    (define-syntax fx-num-op
      (er-macro-transformer
        (lambda (expr rename compare)
          (let* ((scm-fnc (cadr expr))
                 (fnc (caddr expr))
                 (op-str (cadddr expr))
                 (args "(void* data, int argc, closure _, object k, object opq, object m)")
                 (body
                   (string-append
                     " uintptr_t c = " op-str "((uintptr_t *)(&(opaque_ptr(opq))), (uintptr_t)obj_obj2int(m));\n"
                     " return_closcall1(data, k, obj_int2obj((object)c)); ")))
            `(begin 
               (define-c ,fnc ,args ,body)
               (define (,scm-fnc box n . o)
                 (atomic-fxbox-check box)
                 (,fnc (atomic-fxbox-content box) n))
)))))

    (fx-num-op atomic-fxbox+/fetch!    %atomic-fxbox-fetch-add  "atomic_fetch_add")
    (fx-num-op atomic-fxbox-/fetch!    %atomic-fxbox-/fetch!    "atomic_fetch_sub")
    (fx-num-op atomic-fxbox-and/fetch! %atomic-fxbox-and/fetch! "atomic_fetch_and")
    (fx-num-op atomic-fxbox-ior/fetch! %atomic-fxbox-ior/fetch! "atomic_fetch_or")
    (fx-num-op atomic-fxbox-xor/fetch! %atomic-fxbox-xor/fetch! "atomic_fetch_xor")
    (fx-num-op atomic-fxbox-swap!      %atomic-fxbox-exchange   "atomic_exchange")

    (define-record-type atomic-fxbox
      (%make-atomic-fxbox content)
      atomic-fxbox?
      (content atomic-fxbox-content atomic-fxbox-set-content!))

    (define (make-atomic-fxbox c)
      (define b (%make-atomic-fxbox (%empty-opaque)))
      (Cyc-minor-gc) ;; Force b onto heap
      (%atomic-fxbox-init (atomic-fxbox-content b) c) 
      b)

    (define (atomic-fxbox-check box)
      (unless (atomic-fxbox? box)
        (error "Expected atomic fxbox but received" box)))

    (define (atomic-fxbox-ref box . o)
      (atomic-fxbox-check box)
      (%atomic-fxbox-load (atomic-fxbox-content box)))

    (define (atomic-fxbox-set! box obj . o)
      (atomic-fxbox-check box)
      (%atomic-fxbox-store (atomic-fxbox-content box) obj))

    (define (atomic-fxbox-swap! box obj . o)
      (atomic-fxbox-check box)
      (%atomic-fxbox-exchange (atomic-fxbox-content box) obj))

    (define (atomic-fxbox-compare-and-swap! box expected desired . o)
      (atomic-fxbox-check box)
      (%atomic-fxbox-compare-exchange (atomic-fxbox-content box) expected desired))


    ;; Memory synchronization

    (define (atomic-fence . o)
      (%atomic-fence (if (pair? o) (car o) #f)))

    (define-c %atomic-fence
      "(void *data, int argc, closure _, object k, object order)"
      " atomic_thread_fence( scm2c_memory_order(order) );
        return_closcall1(data, k, boolean_t); ")
  ))
