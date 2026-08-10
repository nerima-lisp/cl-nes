# Conditions

Errors that identify invalid input or unsupported hardware are signaled as
Common Lisp conditions. Applications can handle them without parsing error
strings.

## Condition types

| Type | Accessors | Typical cause |
| --- | --- | --- |
| invalid-rom | invalid-rom-reason | Bad iNES magic, unsupported header, or invalid ROM size. |
| unsupported-mapper | unsupported-mapper-number | A mapper number outside the supported set. |
| illegal-opcode | illegal-opcode-value, illegal-opcode-address | An instruction the CPU does not implement. |
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

## Handle an illegal opcode

The opcode condition preserves both the byte value and the CPU address:

~~~lisp
(handler-case
    (cl-nes:nes-step/k nes #'continue-running)
  (cl-nes:illegal-opcode (condition)
    (format t "opcode ~2,'0X at $~4,'0X~%"
            (cl-nes:illegal-opcode-value condition)
            (cl-nes:illegal-opcode-address condition))))
~~~

The condition is preferable to silently treating unknown bytes as no-ops.
