;;;; weapons
;;; This code implements the logic and rendering functionality of
;;; weapons.

(declare (block)
         (standard-bindings)
         (extended-bindings))

;; init

(define lightning-textures '())
(define blood-texture #f)

(define (weapons-init)
  (set! lightning-textures
        (list (image-opengl-load "line.png")
              (image-opengl-load "line2.png")
              (image-opengl-load "line3.png")))
  (set! blood-texture (image-opengl-load "blood.pvr")))

;; nuke

(define (fire-nuke)
  (overlay-list-add
   (make-tween
    (make-2d-object
     2d-perspective
     color: (make-vec4d 1. 1. 1. 1.))
    color: (make-vec4d 1. 1. 1. 0.))
   important: #t)

  (for-each
   (lambda (obj)
     (if (mesh-object? obj)
         (scene-list-remove obj)))
   scene-list)

  (play-and-release-audio (make-audio-source explosion4-audio)))

;; creating

(define %%lightnings '())

(define-type lightning
  id: A4DC9FC6-AB12-46EC-ACBC-AE8837167B30
  constructor: really-make-lightning
  point
  angle
  texture
  scatter-vectors
  lifetime
  created-time)

(define %%last-texture-index 0)

(define (make-lightning point)
  (set! %%last-texture-index
        (remainder (+ %%last-texture-index 1)
                   (length lightning-textures)))
  
  (really-make-lightning
   point
   (* (spread-number (random-real)) 10.)
   (list-ref lightning-textures %%last-texture-index)
   (let ((count (+ 3 (random-integer 5))))
     (unfold (lambda (i) (>= i count))
             (lambda (i) (vec3d-unit
                          (make-vec3d (spread-number (random-real))
                                      (spread-number (random-real))
                                      (spread-number (random-real)))))
             (lambda (i) (+ i 1))
             0))
   .5
   (real-time)))

(define (add-lightning lightning)
  (if (>= (length %%lightnings) 2)
      (set! %%lightnings (list lightning
                               (car %%lightnings)))
      (set! %%lightnings (cons lightning %%lightnings)))

  ;; Play the explosion sound
  (play-and-release-audio (make-audio-source lightning-audio)))

(define (add-hit-point point)
  (add-lightning (make-lightning point)))

;; rendering

(define (render-lightning lightning)
  (let* ((now (real-time))
         (passed (- now (lightning-created-time lightning))))
    (if (>= passed (lightning-lifetime lightning))
        #f
        (%%render-lightning (lightning-point lightning)
                            (lightning-angle lightning)
                            (lightning-texture lightning)
                            passed
                            (/ passed (lightning-lifetime lightning))))))

(define (%%render-lightning point angle texture time-passed time-interp)
  (let* ((width (UIView-width (current-view)))
         (height (UIView-height (current-view)))
         (pers (current-perspective))
         (x (exact->inexact (* (/ (car point) width)
                               (perspective-xmax pers))))
         (y (exact->inexact (* (/ (cdr point) height)
                               (perspective-ymin pers)))))

    ;; Fix blending of textures due to alpha-premultiplication that
    ;; Cocoa does (see `render-2d-object` in scene.scm for full
    ;; comments)
    (let ((fade (- 1. time-interp)))
      (glColor4f fade fade fade fade))

    ;; Render the lightning
    (glLoadIdentity)
    (glTranslatef x y 0.)
    (glRotatef (+ 180.
                  angle)
               0. 0. 1.)
    (glTranslatef -.2 0. 0.)
    (glScalef .4 1.5 1.)
    (image-render texture)

    #t))

(define (render-lightnings)
  (2d-object-prerender #t)
  (glEnable GL_BLEND)
  (glBlendFunc GL_ONE GL_ONE_MINUS_SRC_ALPHA)
  (glColor4f 1. 1. 1. 1.)

  (set! %%lightnings
        (reverse
         (fold (lambda (lightning acc)
                 (let ((result (render-lightning lightning)))
                   (if result
                       (cons lightning acc)
                       acc)))
               '()
               %%lightnings)))
  (glDisable GL_BLEND)
  (2d-object-postrender #t))

;; dust

(define dust-list '())

(define (dust-list-add obj)
  (set! dust-list (cons obj dust-list)))

(define (add-dust x y z)
  (define (depth-scale #!optional n)
    (+ (expt .97 z) (or n 0.)))

  (let* ((width (UIView-width (current-view)))
         (height (UIView-height (current-view)))
         (pos (make-vec3d (/ (exact->inexact x) width)
                          (* (/ (exact->inexact y) height) 1.5)
                          0.)))

    (let loop ((i 0))
      (if (< i 5)
          (begin
            (dust-list-add
             (make-tween
              (make-2d-object
               2d-ratio-perspective
               position: (vec3d-copy pos)
               scale: (make-vec3d (depth-scale .1) (depth-scale .1) 1.)
               rotation: (make-vec4d 0. 0. 1. (* (random-real) 360.))
               texture: blood-texture
               color: (make-vec4d 1. 0. 0. 1.)
               center: #t)
              alpha: 0.
              length: .5
              position: (vec3d-add
                         pos
                         (make-vec3d (* (spread-number (random-real)) .1)
                                     (* (spread-number (random-real)) .1)
                                     (* (spread-number (random-real)) .1)))
              type: 'ease-out-cubic
              on-finished: (lambda ()
                             #f)))
            (loop (+ i 1)))))))

(define (render-dust)
  (load-perspective 2d-ratio-perspective)
  (2d-object-prerender #t)
  (for-each (lambda (obj)
              (render-generic-object obj))
            dust-list)
  (2d-object-postrender #t))

(define (update-dust)
  (set! dust-list (scene-list-update #f #f dust-list)))

;; interface

(define (update-weapons)
  (update-dust))

(define (render-weapons)
  (render-lightnings)
  (render-dust))
