(in-package #:cl-nes/frontend)

#+sbcl
(progn
  (sb-alien:define-alien-routine ("glGenTextures" %gl-gen-textures) sb-alien:void
    (count sb-alien:int) (textures (* sb-alien:unsigned-int)))
  (sb-alien:define-alien-routine ("glDeleteTextures" %gl-delete-textures) sb-alien:void
    (count sb-alien:int) (textures (* sb-alien:unsigned-int)))
  (sb-alien:define-alien-routine ("glBindTexture" %gl-bind-texture) sb-alien:void
    (target sb-alien:unsigned-int) (texture sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("glTexParameteri" %gl-tex-parameteri) sb-alien:void
    (target sb-alien:unsigned-int) (name sb-alien:unsigned-int) (value sb-alien:int))
  (sb-alien:define-alien-routine ("glTexImage2D" %gl-tex-image-2d) sb-alien:void
    (target sb-alien:unsigned-int) (level sb-alien:int) (internal-format sb-alien:int)
    (width sb-alien:int) (height sb-alien:int) (border sb-alien:int)
    (format sb-alien:unsigned-int) (type sb-alien:unsigned-int) (pixels (* t)))
  (sb-alien:define-alien-routine ("glTexSubImage2D" %gl-tex-sub-image-2d) sb-alien:void
    (target sb-alien:unsigned-int) (level sb-alien:int) (x sb-alien:int) (y sb-alien:int)
    (width sb-alien:int) (height sb-alien:int) (format sb-alien:unsigned-int)
    (type sb-alien:unsigned-int) (pixels (* t)))
  (sb-alien:define-alien-routine ("glPixelStorei" %gl-pixel-storei) sb-alien:void
    (name sb-alien:unsigned-int) (value sb-alien:int))
  (sb-alien:define-alien-routine ("glClear" %gl-clear) sb-alien:void
    (mask sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("glEnable" %gl-enable) sb-alien:void
    (cap sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("glBegin" %gl-begin) sb-alien:void
    (mode sb-alien:unsigned-int))
  (sb-alien:define-alien-routine ("glEnd" %gl-end) sb-alien:void)
  (sb-alien:define-alien-routine ("glTexCoord2f" %gl-tex-coord-2f) sb-alien:void
    (s sb-alien:float) (texture-y sb-alien:float))
  (sb-alien:define-alien-routine ("glVertex2f" %gl-vertex-2f) sb-alien:void
    (x sb-alien:float) (y sb-alien:float)))

(defstruct (gl-framebuffer (:constructor %make-gl-framebuffer (texture rgb)))
  texture rgb)

(defun make-gl-framebuffer ()
  "Create an RGB staging buffer and its OpenGL texture in a current context."
  #+sbcl
  (let ((texture (sb-alien:make-alien sb-alien:unsigned-int 1))
        (rgb (make-array (* cl-nes:+nes-framebuffer-size+ 3)
                         :element-type '(unsigned-byte 8))))
    (%gl-gen-textures 1 texture)
    (let ((id (sb-alien:deref texture)))
      (sb-alien:free-alien texture)
      (%gl-bind-texture #x0DE1 id)
      (%gl-tex-parameteri #x0DE1 #x2801 #x2601)
      (%gl-tex-parameteri #x0DE1 #x2800 #x2601)
      (%gl-tex-image-2d #x0DE1 0 3 cl-nes:+nes-frame-width+
                       cl-nes:+nes-frame-height+ 0 #x1907 #x1401
                       (sb-sys:int-sap 0))
      (%make-gl-framebuffer id rgb)))
  #-sbcl (error "The frontend requires SBCL for its OpenGL FFI."))

(defun destroy-gl-framebuffer (framebuffer)
  "Release FRAMEBUFFER's texture; call while its OpenGL context is current."
  #+sbcl
  (let ((texture (sb-alien:make-alien sb-alien:unsigned-int 1)))
    (setf (sb-alien:deref texture) (gl-framebuffer-texture framebuffer))
    (%gl-delete-textures 1 texture)
    (sb-alien:free-alien texture))
  framebuffer)

(defun gl-framebuffer-upload! (framebuffer palette-index-frame)
  "Convert and upload one NES framebuffer to the bound texture."
  (let ((rgb (gl-framebuffer-rgb framebuffer)))
    (loop for pixel below cl-nes:+nes-framebuffer-size+
          for rgb-index from 0 by 3
          for packed = (aref palette-index-frame pixel)
          for palette-offset = (* (logand packed #x3F) 3)
          for emphasis = (ldb (byte 3 6) packed)
          do (setf (aref rgb rgb-index)
                   (cl-nes::%nes-emphasized-channel
                    (aref cl-nes::*nes-default-palette* palette-offset)
                    emphasis nil t t)
                   (aref rgb (1+ rgb-index))
                   (cl-nes::%nes-emphasized-channel
                    (aref cl-nes::*nes-default-palette* (+ palette-offset 1))
                    emphasis t nil t)
                   (aref rgb (+ rgb-index 2))
                   (cl-nes::%nes-emphasized-channel
                    (aref cl-nes::*nes-default-palette* (+ palette-offset 2))
                    emphasis t t nil)))
    #+sbcl
    (sb-sys:with-pinned-objects (rgb)
      (%gl-bind-texture #x0DE1 (gl-framebuffer-texture framebuffer))
      (%gl-pixel-storei #x0CF5 1)
      (%gl-tex-sub-image-2d #x0DE1 0 0 0 cl-nes:+nes-frame-width+
                            cl-nes:+nes-frame-height+ #x1907 #x1401
                            (sb-sys:vector-sap rgb)))
    #+sbcl
    (progn
      (%gl-clear #x00004000)
      (%gl-enable #x0DE1)
      (%gl-begin #x0007)
      (%gl-tex-coord-2f 0.0 0.0) (%gl-vertex-2f -1.0 1.0)
      (%gl-tex-coord-2f 1.0 0.0) (%gl-vertex-2f 1.0 1.0)
      (%gl-tex-coord-2f 1.0 1.0) (%gl-vertex-2f 1.0 -1.0)
      (%gl-tex-coord-2f 0.0 1.0) (%gl-vertex-2f -1.0 -1.0)
      (%gl-end))
    framebuffer))
