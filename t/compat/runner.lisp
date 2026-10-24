(in-package #:cl-nes/compat)

(defparameter *frames*
  (or (and (uiop:getenv "CL_NES_COMPAT_FRAMES")
           (parse-integer (uiop:getenv "CL_NES_COMPAT_FRAMES")))
      1800))

(defun %hash-octets (sequence)
  (let ((hash 2166136261))
    (loop for value across sequence
          do (setf hash (logand #xffffffff
                                (* (logxor hash value) 16777619))))
    hash))

(defun %distinct-count (sequence)
  (let ((seen (make-hash-table :test #'eql)))
    (loop for value across sequence do (setf (gethash value seen) t))
    (hash-table-count seen)))

(defun %crc32 (octets)
  (let ((crc #xffffffff))
    (loop for octet across octets
          do (setf crc (logxor crc octet))
             (dotimes (bit 8)
               (setf crc (if (logbitp 0 crc)
                             (logxor (ash crc -1) #xedb88320)
                             (ash crc -1)))))
    (logxor crc #xffffffff)))

(defun %write-u32-be (value stream)
  (dotimes (shift 4)
    (write-byte (ldb (byte 8 (* 8 (- 3 shift))) value) stream)))

(defun %png-chunk (type data stream)
  (%write-u32-be (length data) stream)
  (write-sequence type stream)
  (write-sequence data stream)
  (%write-u32-be (%crc32 (concatenate '(vector (unsigned-byte 8)) type data))
                 stream))

(defun %write-png (pathname framebuffer)
  (let* ((rgb (nes-framebuffer-rgb-octets framebuffer))
         (raw (make-array (* 240 (1+ (* 256 3)))
                          :element-type '(unsigned-byte 8)))
         (cursor 0))
    (dotimes (y 240)
      (setf (aref raw cursor) 0)
      (incf cursor)
      (replace raw rgb :start1 cursor :start2 (* y 256 3)
               :end2 (* (1+ y) 256 3))
      (incf cursor (* 256 3)))
    (with-open-file (stream pathname :direction :output :if-exists :supersede
                            :if-does-not-exist :create
                            :element-type '(unsigned-byte 8))
      (write-sequence #(137 80 78 71 13 10 26 10) stream)
      (%png-chunk #(73 72 68 82)
                  #(0 0 1 0 0 0 0 240 8 2 0 0 0) stream)
      (let ((z (make-array (+ 6 (length raw) (* 5 (ceiling (length raw) 65535)))
                           :element-type '(unsigned-byte 8)))
            (at 0) (offset 0))
        (setf (aref z 0) 120 (aref z 1) 1)
        (setf at 2)
        (loop while (< offset (length raw))
              for size = (min 65535 (- (length raw) offset))
              for final = (= (+ offset size) (length raw))
              do (setf (aref z at) (if final 1 0))
                 (incf at)
                 (setf (aref z at) (ldb (byte 8 0) size)
                       (aref z (+ at 1)) (ldb (byte 8 8) size)
                       (aref z (+ at 2)) (ldb (byte 8 0) (logxor size #xffff))
                       (aref z (+ at 3)) (ldb (byte 8 8) (logxor size #xffff)))
                 (incf at 4)
                 (replace z raw :start1 at :start2 offset :end2 (+ offset size))
                 (incf at size)
                 (incf offset size))
        (let ((a 1) (b 0))
          (loop for byte across raw do (setf a (mod (+ a byte) 65521)
                                               b (mod (+ b a) 65521)))
          (let ((adler (logior (ash b 16) a)))
            (dotimes (shift 4)
              (setf (aref z (+ at shift))
                    (ldb (byte 8 (* 8 (- 3 shift))) adler)))
            (incf at 4)))
        (%png-chunk #(73 68 65 84) (subseq z 0 at) stream))
      (%png-chunk #(73 69 78 68) #() stream))
    pathname))
(defun %apu-output-ready-p (apu)
  ;; NESdev gates use active counters/levels; triangle/DMC can hold DAC values; $4015 enable alone is insufficient.
  (labels ((envelope-ready-p (envelope)
             (or (plusp (cl-nes::%apu-envelope-output envelope))
                 (and (cl-nes::apu-envelope-start-p envelope)
                      (or (not (cl-nes::apu-envelope-constant-volume-p envelope))
                          (plusp (cl-nes::apu-envelope-volume envelope))))))
           (pulse-ready-p (pulse first-p)
             (and (cl-nes::apu-pulse-enabled-p pulse)
                  (plusp (cl-nes::apu-pulse-length-counter pulse))
                  (>= (cl-nes::apu-pulse-timer-period pulse) 8)
                  (<= (cl-nes::%apu-pulse-sweep-target pulse first-p) #x7FF)
                  (envelope-ready-p (cl-nes::apu-pulse-envelope pulse)))))
    (let* ((triangle (cl-nes::apu-triangle apu))
           (noise (cl-nes::apu-noise apu))
           (dmc (cl-nes::apu-dmc apu)))
      (or (pulse-ready-p (cl-nes::apu-pulse-1 apu) t)
          (pulse-ready-p (cl-nes::apu-pulse-2 apu) nil)
          (and (cl-nes::apu-triangle-enabled-p triangle)
               (plusp (cl-nes::apu-triangle-length-counter triangle))
               (or (plusp (cl-nes::apu-triangle-linear-counter triangle))
                   (and (cl-nes::apu-triangle-linear-reload-p triangle)
                        (plusp (cl-nes::apu-triangle-linear-reload-value triangle)))))
          (plusp (cl-nes::apu-triangle-dac-output triangle))
          (and (cl-nes::apu-noise-enabled-p noise)
               (plusp (cl-nes::apu-noise-length-counter noise))
               (envelope-ready-p (cl-nes::apu-noise-envelope noise)))
          (plusp (cl-nes::apu-dmc-output dmc))
          (not (cl-nes::apu-dmc-sample-buffer-empty-p dmc))
          (and (cl-nes::apu-dmc-enabled-p dmc)
               (plusp (cl-nes::apu-dmc-bytes-remaining dmc)))
          (and (plusp (cl-nes::apu-dmc-bits-remaining dmc))
               (not (cl-nes::apu-dmc-silence-p dmc)))))))
(defun %compat-root (&optional root-name)
  (let ((root (or (and root-name
                       (uiop:getenv (format nil "CL_NES_COMPAT_ROOT_~A"
                                            (string-upcase root-name))))
                  (uiop:getenv "CL_NES_COMPAT_ROOT")
                  (error "CL_NES_COMPAT_ROOT is not set."))))
    (format nil "~A/" root)))

(defun %artifact-root ()
  (let ((root (or (uiop:getenv "CL_NES_COMPAT_ARTIFACTS")
                  "compat-artifacts")))
    (ensure-directories-exist (merge-pathnames "dummy"
                                               (pathname (format nil "~A/" root))))
    (format nil "~A/" root)))

;; The ROM enables rendering before polling Start, which advances its idle loop.
(defparameter *compat-input-sequences*
  `(("memory" . ((1 . ,cl-nes:+button-start+)
                 (181 . 0)))))

(defun %compat-input-continuation (id controller)
  (let ((sequence (cdr (assoc id *compat-input-sequences* :test #'string=)))
        (frame 0)
        (buttons 0))
    (when sequence
      (lambda (nes)
        (declare (ignore nes))
        (incf frame)
        (dolist (input sequence)
          (when (<= (car input) frame)
            (setf buttons (cdr input))))
        (cl-nes:controller-set-buttons! controller buttons)))))

(defun %run-once (path id write-image)
  (let* ((controller-1 (cl-nes:make-controller))
         (nes (make-nes :cartridge (load-cartridge path)
                        :controller-1 controller-1))
         (audio (make-nes-audio-buffer :size 4096))
         (audio-samples 0)
         (audio-min nil)
         (audio-max nil)
         (audio-ready-p nil)
         (probe-cycles 256)
         (audio-stream
           (cl-nes::%nes-make-audio-stream
            cl-nes:+nes-default-audio-sample-rate+ audio
            (lambda (buffer)
              (loop for sample across (nes-audio-buffer-samples buffer)
                    repeat (nes-audio-buffer-count buffer)
                    do (when (not (zerop sample)) (incf audio-samples))
                       (setf audio-min
                             (if audio-min (min audio-min sample) sample)
                             audio-max
                             (if audio-max (max audio-max sample) sample))))))
         (first-hash nil)
         (last-frame nil)
         (pc-seen (make-hash-table :test #'eql))
         (first-frame nil)
         (input-continuation
           (%compat-input-continuation id controller-1)))
    (let ((cl-nes::*nes-audio-cycle-nes* nes)
          (cl-nes::*nes-audio-cycle-stream* audio-stream))
      (dotimes (frame *frames*)
        (nes-run-frame/k
         nes
         (lambda (framebuffer)
           (unless first-frame (setf first-frame (copy-seq framebuffer)))
           (setf last-frame (copy-seq framebuffer))
           (setf first-hash (or first-hash (%hash-octets framebuffer)))
           (setf (gethash (cpu-pc (nes-cpu nes)) pc-seen) t))
         :cycle-hook
         (lambda ()
           (cl-nes::%nes-audio-cycle-hook)
           (decf probe-cycles)
           (when (zerop probe-cycles)
             (setf probe-cycles 256)
             (when (%apu-output-ready-p (cl-nes:nes-apu nes))
               (setf audio-ready-p t))))
         :input-continuation input-continuation)))
    (when write-image
      (%write-png
       (merge-pathnames (format nil "~A.png" id) (pathname (%artifact-root)))
       last-frame))
    (list :first-hash first-hash
          :last-hash (%hash-octets last-frame)
          :unique-pixels (%distinct-count last-frame)
          :audio-samples audio-samples
          :audio-spread (if audio-min (- audio-max audio-min) 0.0f0)
          :audio-ready-p audio-ready-p
          :pc-count (hash-table-count pc-seen)
          :cycles (cpu-cycles (nes-cpu nes)))))

(defun %classify (first second)
  (cond
    ((/= (getf first :last-hash) (getf second :last-hash)) :nondeterministic)
    ((<= (getf first :pc-count) 1) :stopped)
    ((= (getf first :first-hash) (getf first :last-hash)) :static)
    ((<= (getf first :unique-pixels) 1) :static)
    ((and (getf first :audio-ready-p)
          (zerop (getf first :audio-spread))) :silent)
    (t :pass)))

(defun %run-entry (entry)
  (let* ((id (getf entry :id))
         (path (merge-pathnames (getf entry :file)
                                (pathname (%compat-root
                                         (getf entry :root))))))
    (handler-case
        (let* ((first (%run-once path id t))
               (second (%run-once path id nil))
               (status (%classify first second)))
          (list :id id :status status :mapper (getf entry :mapper)
                :frames *frames* :first-hash (getf first :first-hash)
                :rerun-hash (getf second :last-hash)
                :unique-pixels (getf first :unique-pixels)
                :audio-samples (getf first :audio-samples)
                :audio-ready-p (getf first :audio-ready-p)
                :audio-spread (getf first :audio-spread)
                :pc-count (getf first :pc-count)
                :cycles (getf first :cycles)))
      (cl-nes:unsupported-mapper (condition)
        (list :id id :status :unsupported-mapper :mapper
              (cl-nes:unsupported-mapper-number condition)
              :error (princ-to-string condition)))
      (error (condition)
        (list :id id :status :crash :mapper (getf entry :mapper)
              :error (princ-to-string condition))))))

(defun %write-report (results)
  (let ((path (merge-pathnames "compat-results.tsv"
                              (pathname (%artifact-root)))))
    (with-open-file (stream path :direction :output :if-exists :supersede
                            :if-does-not-exist :create)
      (format stream "id~Cstatus~Cmapper~Cframes~Cfirst_hash~Crerun_hash~Cunique_pixels~Caudio_samples~Caudio_ready~Caudio_spread~Cpc_count~Ccycles~Cerror~%"
              #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
      (dolist (result results)
        (format stream "~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~%"
                (getf result :id) #\Tab
                (string-downcase (symbol-name (getf result :status))) #\Tab
                (getf result :mapper) #\Tab (getf result :frames) #\Tab
                (getf result :first-hash) #\Tab (getf result :rerun-hash) #\Tab
                (getf result :unique-pixels) #\Tab (getf result :audio-samples) #\Tab
                (if (getf result :audio-ready-p) "yes" "no") #\Tab
                (getf result :audio-spread) #\Tab
                (getf result :pc-count) #\Tab (getf result :cycles) #\Tab
                (or (getf result :error) ""))))
    path))

(defun %baseline-path ()
  (or (uiop:getenv "CL_NES_COMPAT_BASELINE")
      (namestring (merge-pathnames "baseline.tsv"
                                   (pathname "t/compat/")))))

(defun %check-baseline (results)
  (let ((path (%baseline-path)))
    (when (probe-file path)
      (let ((baseline (make-hash-table :test #'equal)))
        (dolist (line (uiop:read-file-lines path))
          (unless (or (zerop (length line)) (char= (char line 0) #\#))
            (let* ((fields (uiop:split-string line :separator '(#\Tab)))
                   (id (first fields)))
              (setf (gethash id baseline) (list (second fields)
                                                (parse-integer (third fields)))))))
        (dolist (result results)
          (let ((expected (gethash (getf result :id) baseline)))
            (unless (and expected
                         (string= (first expected)
                                  (string-downcase
                                   (symbol-name (getf result :status))))
                         (= (second expected) (getf result :mapper)))
              (error "Compatibility ratchet failed for ~A." (getf result :id)))))))
  t))

(defun %selected-corpus ()
  (let ((ids (uiop:getenv "CL_NES_COMPAT_IDS"))
        (root-filter (uiop:getenv "CL_NES_COMPAT_ROOT_FILTER"))
        (bucket (and (uiop:getenv "CL_NES_COMPAT_BUCKET")
                     (parse-integer (uiop:getenv "CL_NES_COMPAT_BUCKET"))))
        (bucket-count (or (and (uiop:getenv "CL_NES_COMPAT_BUCKET_COUNT")
                               (parse-integer
                                (uiop:getenv "CL_NES_COMPAT_BUCKET_COUNT")))
                          1)))
    (loop for entry in *compat-corpus*
          for index from 0
          when (and (or (null ids)
                        (member (getf entry :id)
                                (uiop:split-string ids :separator '(#\,))
                                :test #'string=))
                    (or (null root-filter)
                        (string= root-filter
                                 (or (getf entry :root) "retrobrews")))
                    (or (null bucket)
                        (= (mod index bucket-count) bucket)))
            collect entry)))

(defun compat-main ()
  (let ((corpus (%selected-corpus)))
    (unless (>= (length *compat-corpus*) 50)
      (error "Compatibility corpus must contain at least 50 ROMs."))
    (unless (every (lambda (entry)
                     (and (getf entry :license-source)
                          (getf entry :license-quote)))
                   *compat-corpus*)
      (error "Every compatibility ROM must have concrete license provenance."))
    (let* ((results (mapcar #'%run-entry corpus))
           (report (%write-report results)))
      (%check-baseline results)
      (dolist (result results)
        (format t "compat ~A status=~(~A~) mapper=~A audio-ready=~A audio-spread=~A~%"
                (getf result :id) (getf result :status) (getf result :mapper)
                (if (getf result :audio-ready-p) "yes" "no")
                (getf result :audio-spread)))
      (format t "compat corpus=~D frames=~D report=~A~%"
              (length results) *frames* report)
      (if (some (lambda (result)
                  (member (getf result :status) '(:crash :nondeterministic)))
                results)
          1
          0))))
