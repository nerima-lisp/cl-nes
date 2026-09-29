(in-package #:cl-nes/test)

(describe "Public API: cartridge core"
  (it "constructs cartridges through the public constructor"
    (let* ((prg (make-array #x4000 :element-type '(unsigned-byte 8)
                            :initial-element #x11))
           (chr (make-array #x2000 :element-type '(unsigned-byte 8)
                            :initial-element #x22))
           (cartridge (make-cartridge :prg-rom prg :chr-rom chr
                                      :mapper 0)))
      (expect (cartridge-prg-size cartridge) :to-be #x4000)
      (expect (cartridge-chr-size cartridge) :to-be #x2000)
      (expect (cartridge-read-prg cartridge #x8000) :to-be #x11)
      (expect (cartridge-read-chr cartridge #x0000) :to-be #x22)))

  (it "rejects ROM images with truncated payloads"
    (let ((image (make-array 20 :element-type '(unsigned-byte 8)
                             :initial-element 0)))
      (setf (aref image 0) #x4E
            (aref image 1) #x45
            (aref image 2) #x53
            (aref image 3) #x1A
            (aref image 4) 1
            (aref image 5) 1)
      (expect (lambda ()
                (load-cartridge image))
              :to-throw 'error))))
