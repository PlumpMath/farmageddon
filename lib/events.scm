;;;; Events

(define %%handlers (make-table))

(define (install-event-handler name handler)
  (table-set!
   %%handlers
   name
   (cons handler (table-ref %%handlers name '()))))

(define (run-event-handlers name . args)
  (for-each (lambda (handler)
              (apply handler args))
            (table-ref %%handlers name '())))

(define-macro (define-event-handler sig . body)
  (let ((name (car sig))
        (args (cdr sig)))
    `(install-event-handler
      ',name
      (lambda ,args ,@body))))

;;;; Usage

;;; (install-event-handler 'event-name (lambda (event) ...))
;;; (define-event-handler (event-name event) ...)
;;; (run-event-handlers 'event-name)
