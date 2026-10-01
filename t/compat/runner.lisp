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

(defun %run-once (path id write-image)
  (let* ((nes (make-nes :cartridge (load-cartridge path)))
         (audio (make-nes-audio-buffer :size 4096))
         (audio-samples 0)
         (first-hash nil)
         (last-frame nil)
         (pc-seen (make-hash-table :test #'eql))
         (first-frame nil))
    (nes-run-frames/k
     nes *frames*
     (lambda (framebuffer)
       (unless first-frame (setf first-frame (copy-seq framebuffer)))
       (setf last-frame (copy-seq framebuffer))
       (setf first-hash (or first-hash (%hash-octets framebuffer)))
       (setf (gethash (cpu-pc (nes-cpu nes)) pc-seen) t))
     :audio-buffer audio
     :audio-continuation
     (lambda (buffer)
       (loop for sample across (nes-audio-buffer-samples buffer)
             repeat (nes-audio-buffer-count buffer)
             do (when (not (zerop sample)) (incf audio-samples)))))
    (when write-image
      (%write-png
       (merge-pathnames (format nil "~A.png" id) (pathname (%artifact-root)))
       last-frame))
    (list :first-hash first-hash
          :last-hash (%hash-octets last-frame)
          :unique-pixels (%distinct-count last-frame)
          :audio-samples audio-samples
          :pc-count (hash-table-count pc-seen)
          :cycles (cpu-cycles (nes-cpu nes)))))

(defun %classify (first second)
  (cond
    ((/= (getf first :last-hash) (getf second :last-hash)) :nondeterministic)
    ((<= (getf first :pc-count) 1) :stopped)
    ((= (getf first :first-hash) (getf first :last-hash)) :static)
    ((<= (getf first :unique-pixels) 1) :static)
    ((zerop (getf first :audio-samples)) :silent)
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
      (format stream "id~Cstatus~Cmapper~Cframes~Cfirst_hash~Crerun_hash~Cunique_pixels~Caudio_samples~Cpc_count~Ccycles~Cerror~%"
              #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
      (dolist (result results)
        (format stream "~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~C~A~%"
                (getf result :id) #\Tab
                (string-downcase (symbol-name (getf result :status))) #\Tab
                (getf result :mapper) #\Tab (getf result :frames) #\Tab
                (getf result :first-hash) #\Tab (getf result :rerun-hash) #\Tab
                (getf result :unique-pixels) #\Tab (getf result :audio-samples) #\Tab
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
      (dolist (line (uiop:read-file-lines path))
        (unless (or (zerop (length line)) (char= (char line 0) #\#))
          (let* ((fields (uiop:split-string line :separator '(#\Tab)))
                 (id (first fields))
                 (status (second fields))
                 (mapper (third fields))
                 (result (find id results :key (lambda (item) (getf item :id))
                               :test #'string=)))
            (unless (and result
                         (string= status (string-downcase
                                          (symbol-name (getf result :status))))
                         (= (parse-integer mapper) (getf result :mapper)))
              (error "Compatibility ratchet failed for ~A." id)))))))
  t)

(defun %selected-corpus ()
  (let ((ids (uiop:getenv "CL_NES_COMPAT_IDS")))
    (if ids
        (remove-if-not
         (lambda (entry)
           (member (getf entry :id)
                   (uiop:split-string ids :separator '(#\,))
                   :test #'string=))
         *compat-corpus*)
        *compat-corpus*)))

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
        (format t "compat ~A status=~(~A~) mapper=~A~%"
                (getf result :id) (getf result :status) (getf result :mapper)))
      (format t "compat corpus=~D frames=~D report=~A~%"
              (length results) *frames* report)
      (if (some (lambda (result)
                 (member (getf result :status) '(:crash :nondeterministic)))
               results)
          1
          0))))
