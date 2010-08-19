;;;; events
;;; Implements the harnesses for pumping through events in the game

(declare (block)
         (standard-bindings)
         (extended-bindings))

(define *current-difficulty* #f)
(define *max-difficulty* 10)
(define *events* (make-vector 10 '()))

(define-macro (install-event difficulty func)
  (if (or (< difficulty 0)
          (> difficulty 9))
      (error "define-event: invalid difficulty level ("
             difficulty
             ")"))
  (let ((difficulty (inexact->exact difficulty)))
    `(begin
       (vector-set! *events*
                    ,difficulty
                    (cons (lambda ()
                            (,func))
                          (vector-ref *events* ,difficulty))))))

(define (clear-events)
  (set! *events* (make-vector 10 '())))

(define (get-events difficulty)
  (vector-ref *events* difficulty))

(define (%events-in-range start end)
  (let loop ((acc '())
             (i start))
    (if (< i end)
        (loop (append (get-events i) acc)
              (+ i 1))
        acc)))

(define (random-event-in-range start end)
  (and-let* ((events (%events-in-range (max 0 start)
                                       (min 9 end)))
             (len (length events))
             ((> len 0))
             (i (random-integer len)))
    (list-ref events i)))

(define wait thread-sleep!)

;; managing difficulties

(define *difficulties* (make-vector 10 #f))

(define (%install-difficulties lst)
  (if (not (null? lst))
      (begin
        (if (< (length lst) 5)
            (error "install-difficulties: ill-formed arguments"))
        (let ((diff (first lst))
              (shift (second lst))
              (span (third lst))
              (min-delay (fourth lst))
              (delay-window (fifth lst)))
          (vector-set! *difficulties* diff (list shift span min-delay delay-window))
          (%install-difficulties (drop lst 5))))))

(define (install-difficulties . args)
  (%install-difficulties args))

(define (set-difficulty! difficulty)
  (set! *current-difficulty* difficulty))

(define (current-difficulty)
  *current-difficulty*)

(define (current-difficulty-shift)
  (get-difficulty-shift (current-difficulty)))

(define (current-difficulty-span)
  (get-difficulty-span (current-difficulty)))

(define (current-difficulty-min-delay)
  (get-difficulty-min-delay (current-difficulty)))

(define (current-difficulty-delay-window)
  (get-difficulty-delay-window (current-difficulty)))

(define (%get-difficulty difficulty)
  (let ((x (vector-ref *difficulties* difficulty)))
    (if x x
        (error "%get-difficulty: not installed for difficulty"
               difficulty))))

(define (get-difficulty-shift difficulty)
  (first (%get-difficulty difficulty)))

(define (get-difficulty-span difficulty)
  (second (%get-difficulty difficulty)))

(define (get-difficulty-min-delay difficulty)
  (third (%get-difficulty difficulty)))

(define (get-difficulty-delay-window difficulty)
  (fourth (%get-difficulty difficulty)))

(define (apply-difficulty-shift?)
  (and (>= (kill-count) (current-difficulty-shift))
       (< (current-difficulty) *max-difficulty*)))

(define (check-difficulty)
  (if (apply-difficulty-shift?)
      (begin
        (set-difficulty! (+ (current-difficulty) 1))
        (reset-kill-count)
        #t)
      #f))

;; thread communication

(define *receiver-thread* #f)

(define (%send-message msg)
  (thread-send *receiver-thread* msg))

(define-macro (define-message name)
  `(define (,name . args)
     (%send-message (cons ',name args))))

(define-message add-object)
(define-message next-event)

;; managing events

(define *thread-executioner* #f)
(define *thread-event-group* (make-thread-group 'events))

(define (wait-for-a-time)
  (let ((d-min (current-difficulty-min-delay))
        (d-window (current-difficulty-delay-window)))
    (thread-sleep! (+ d-min (* (random-real) d-window)))))

(define (start-event-executioner)
  (set! *thread-executioner*
        (make-thread
         (lambda ()
           (let loop ()
             (start-event)
             (wait-for-a-time)
             (loop)))))
  (thread-start! *thread-executioner*))

(define (restart-event-executioner)
  (stop-event-executioner)
  (start-event-executioner))

(define (stop-event-executioner)
  (if *thread-executioner*
      (begin
        (thread-terminate! *thread-executioner*)
        (set! *thread-executioner* #f)))
  (thread-group-terminate! *thread-event-group*)
  (let loop ()
    (if (thread-receive 0 #f)
        (loop))))

(define (start-event)
  (thread-start!
   (make-thread
    (lambda ()
      (and-let* ((event (random-event-in-range
                         (- (current-difficulty)
                            (current-difficulty-span))
                         (+ (current-difficulty) 1))))
        (event)))
    'event *thread-event-group*)))

(define (run-events)
  (if (not *receiver-thread*)
      (set! *receiver-thread* (current-thread)))
  (if (not *thread-executioner*)
      (start-event-executioner))

  (and-let* ((msg (thread-receive 0 #f)))
    (case (car msg)
      ((add-object) (scene-list-add (cadr msg)))
      (else (error "run-events: invalid message" (car msg))))))
