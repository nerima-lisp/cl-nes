# Changelog

## v0.3.0

### Breaking changes

- Save-state loading now rejects incompatible format versions. Save states
  produced with an incompatible version are not portable to this release
  (`b538c4a`).

### Compatibility and cartridge support

- Corrected mapper bank access and MMC6 read protection (`05b8c90`).
- Preserved NES 2.0 CHR-ROM sizes during ROM parsing (`0def7aa`).
- Added mapper 34 NINA-001 banking and completed mapper 79 and 87 bank
  handling (`ac8e317`, `a9a5ab3`, `176dd3c`).
- Corrected mapper 69 IRQ control and counter-underflow handling
  (`3c59cd8`, `575d38f`).
- Preserved MMC6-compatible legacy result access for ROM compatibility
  (`33356a1`, `262e179`, `59eff62`).

### Audio and timing

- Corrected APU length-counter reload timing and retained triangle DAC and DMC
  output state across the relevant halted or disabled states
  (`0bfb19b`, `6a00c48`, `20583e3`, `7af9c35`).
- Avoided duplicate audio overrun accounting (`e6b2c03`).

### Frontend and persistence

- Improved frontend cleanup for failed audio or startup paths and released
  OpenGL framebuffer resources (`27d799e`, `321e065`, `8fbd3ff`, `ffb7fc7`).
- Made atomic persistence saves synchronized and made invalid battery files
  recoverable (`ddb8fe8`, `74c988a`).
- Save-state decoding now validates section structure and collection bounds
  before applying decoded state (`4eb16e7`, `97cd53b`, `f39cfd0`).

### Verification and tooling

- Expanded CPU opcode semantics, APU, cartridge, mapper, savestate, frontend,
  and DMA contract coverage (`461d89e`, `6cdc68d`, `b7ef63f`, `593fe22`,
  `3802835`, `2829d1c`).
- Added benchmark and coverage maintenance, including a benchmark entry point
  and corrected frontend and coverage runners (`adf176d`, `a55282b`,
  `2d821a2`, `3b74ce4`).
