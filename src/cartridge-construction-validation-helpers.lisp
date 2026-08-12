(in-package #:cl-nes)

(defun %size-one-of-p (size &rest allowed-sizes)
  (member size allowed-sizes))

(defun %banked-size-p (size minimum unit)
  (and (>= size minimum)
       (zerop (mod size unit))))

(defun %exact-size-p (size expected)
  (= size expected))

(defun %storage-validation-spec-minimum-size (spec)
  (destructuring-bind (_ validator _reason &rest arguments) spec
    (declare (ignore _ _reason))
    (ecase validator
      (%size-one-of-p (apply #'min arguments))
      (%banked-size-p
       (destructuring-bind (minimum unit) arguments
         (* unit (ceiling minimum unit))))
      (%exact-size-p (first arguments)))))

(defun %minimum-valid-storage-size (mapper specs)
  (%storage-validation-spec-minimum-size
   (%find-storage-validation-spec mapper specs)))

(defun %minimum-valid-prg-storage-size (mapper)
  (%minimum-valid-storage-size mapper +prg-storage-validation-specs+))

(defun %minimum-valid-chr-storage-size (mapper)
  (%minimum-valid-storage-size mapper +chr-storage-validation-specs+))

(defun %find-storage-validation-spec (mapper specs)
  (or (assoc mapper specs)
      (error "No storage validation spec for mapper ~D" mapper)))

(defun %validate-storage-size! (mapper size specs)
  (destructuring-bind (_ validator reason &rest arguments)
      (%find-storage-validation-spec mapper specs)
    (declare (ignore _))
    (%invalid-rom-unless
     (apply validator size arguments)
     reason)))
