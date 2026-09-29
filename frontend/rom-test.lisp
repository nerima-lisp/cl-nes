(in-package #:cl-nes/frontend)

(defun run-rom-test (rom max-frames)
  (let ((result (run-blargg-protocol rom max-frames)))
    (format t "passed=~A frames=~A status=~A signature=~A text=~A~%"
            (getf result :passed) (getf result :frames)
            (getf result :status) (getf result :signature)
            (getf result :text))
    (if (getf result :passed) 0 1)))
