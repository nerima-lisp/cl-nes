# Conditions

Errors that identify invalid input or unsupported hardware are signaled as
Common Lisp conditions. Applications can handle them without parsing error
strings.

## Condition types

| Type | Accessors | Typical cause |
| --- | --- | --- |
| invalid-rom | invalid-rom-reason | Bad iNES magic, unsupported header, or invalid ROM size. |
| unsupported-mapper | unsupported-mapper-number | A mapper number outside the supported set. |
| nes-error | None required | Common base type for cl-nes errors. |

## Handle cartridge errors

Use handler-case around loading or machine setup:

~~~lisp
(handler-case
    (cl-nes:load-cartridge "game.nes")
  (cl-nes:invalid-rom (condition)
    (format t "invalid ROM: ~A~%"
            (cl-nes:invalid-rom-reason condition)))
  (cl-nes:unsupported-mapper (condition)
    (format t "unsupported mapper: ~D~%"
            (cl-nes:unsupported-mapper-number condition))))
~~~
