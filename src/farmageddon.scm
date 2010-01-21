
(declare (block)
         (standard-bindings)
         (extended-bindings))

;; libraries

(include "ffi/ffi#.scm")
(include "lib/srfi/srfi-1.scm")
(include "lib/srfi/srfi-2.scm")
(include "lib/srfi/sort.scm")
(include "lib/vectors.scm")
(include "lib/events#.scm")
(include "lib/events.scm")
(include "lib/obj-loader.scm")
(include "lib/scene.scm")
(include "lib/physics.scm")
(include "lib/standard-meshes.scm")
(include "lib/standard-scene-objects.scm")
(include "lib/texture.scm")
(include "lib/perspective.scm")

;; install all the screens of the game

(include "screens.scm")

;;; app

(define (update-audio obj)
  (define (saturate n)
    (min 1. (max 0. n)))

  (let ((source (scene-object-voice-source obj))
        (pos (scene-object-position obj)))
    #t
    #;
    (alSourcef source
               AL_GAIN
               (- 1. (saturate
                      (/ (- (vec3d-z pos) %%screen-depth) 40.))))))

(define SCREEN-DEPTH 10.)

(define (global-update el)
  (update-physics el)
  (update-audio el)
  (let ((pos (scene-object-position el)))
    (if (< (vec3d-z pos) SCREEN-DEPTH)
        (begin
          (life-decrease! el)
          (vec3d-z-set! pos SCREEN-DEPTH)
          (apply crack
                 (unproject (vec3d-x pos) (vec3d-y pos) (vec3d-z pos)))
          (play-thud-for-entity el)
          (scene-object-velocity-set! el (make-vec3d 0. 0. 0.))
          (scene-object-acceleration-set! el (make-vec3d 0. -10. 0.))
          #t))))

(define (%%get-random-time)
  (+ (real-time) (* (random-real)
                    (or (current-animal-frequency) 2.5))))

(define %%next-time #f)

(define (possibly-make-entity)
  (if %%next-time
      (if (> (real-time) %%next-time)
          (let ((entity (make-entity)))
            (scene-list-add entity)
            (set! %%next-time (%%get-random-time))))
      (set! %%next-time (%%get-random-time))))

(define %%entity-max-depth 40.)

(define ENTITY_SCALE 4.)

(define (random-mesh)
  (let ((meshes (or (current-available-meshes)
                    (list cow-mesh
                          sheep-mesh
                          chicken-mesh
                          duck-mesh))))
    (list-ref meshes (random-integer (length meshes)))))

(define (make-entity)
  (let* ((pos (make-vec3d
               (* (spread-number (random-real)) 7.) -28. %%entity-max-depth))
         (to-eye (vec3d-unit (vec3d-sub (make-vec3d 0. 0. 0.)
                                        pos)))
         (x (* (spread-number (random-real)) 3.16))
         (thrust (+ 15. (* x (abs x))))
         (vel (make-vec3d (* (vec3d-x to-eye) thrust)
                          (+ 25.5 (spread-number (random-real)))
                          (* (vec3d-z to-eye) thrust))))
    (let ((obj (make-mesh-object
                3d-projection-matrix
                (random-mesh)
                #f
                pos
                (make-vec4d (random-real)
                            (random-real)
                            0.
                            230.)
                (make-vec3d ENTITY_SCALE ENTITY_SCALE ENTITY_SCALE)
                vel
                #f
                (let ((speed (* (random-real) 4.)))
                  (lambda (this)
                    (scene-object-rotation-set!
                     this
                     (vec4d-add (scene-object-rotation this)
                                (make-vec4d 0. 0. 0. speed)))
                    (let* ((pos (scene-object-position this))
                           (screen-y (cadr (unproject (vec3d-x pos)
                                                      (vec3d-y pos)
                                                      (vec3d-z pos))))
                           (screen-height (UIView-height (current-view))))
                      (if (> screen-y (+ screen-height 100))
                          (begin
                            (on-entity-remove this)
                            (release-color-index (scene-object-data this))
                            #f)
                          this)))))))
      (play-voice-for-entity obj)
      (scene-object-data-set! obj (get-next-color-index obj))
      obj)))

(define (play-voice-for-entity obj)
  (let* ((mesh (scene-object-mesh obj))
         (buffer
          (cond
           ((eq? cow-mesh mesh) moo-audio)
           ((eq? sheep-mesh mesh) bah-audio)
           ((eq? chicken-mesh mesh) chicken-audio)
           (else #f))))
    (if buffer
        (let ((source (make-audio-source buffer)))
          (play-audio source)
          (scene-object-voice-source-set! obj source)))))

(define (play-thud-for-entity obj)
  (let ((source (make-audio-source thud-audio)))
    (play-audio source)
    (scene-object-thud-source-set! obj source)))

(define (on-entity-remove obj)
  (let ((voice-source (scene-object-voice-source obj))
        (thud-source (scene-object-thud-source obj)))
    (if thud-source
        (begin
          (stop-audio thud-source)
          (free-audio-source thud-source)))

    (if voice-source
        (begin
          (stop-audio voice-source)
          (free-audio-source voice-source))))
  (scene-object-voice-source-set! obj #f)
  (scene-object-thud-source-set! obj #f))

(define (on-entity-kill obj)
  (score-increase))

;; engine

(define (init)
  (random-source-randomize! default-random-source)
  (set-screen! title-screen)

  ;; hack hack hack
  ((screen-init title-screen))
  ((screen-init level-screen)))

(define (render)
  (current-screen-run)
  (current-screen-render)
  (##gc))
