    include "regs.inc"

    org $38E1

    ; Header and BASIC stub
    defb    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
    defb    "AQPLUS"
    defb    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
    defb    $0E,$39,$0A,$00,$DA,"14608",':',$80,$00,$00,$00
    jp      main

cpm_start:
    incbin  "zout/cpm22.cim"
cpm_end:

main:
    ; Disable interrupts
    di

    ; Enable turbo mode
    ld      a,$4
    out     (IO_SYSCTRL),a

    ; Clear text RAM
    ld      a,$61
    out     (IO_VCTRL),a
    ld      hl,$3000
    ld      bc,$800
    ld      a,' '
    call    _memset

    ; Clear color RAM
    ld      a,$E1
    out     (IO_VCTRL),a
    ld      hl,$3000
    ld      bc,$800
    ld      a,$8F
    call    _memset

    ld      a,$61
    out     (IO_VCTRL),a

    ; Map RAM in bank 3
    ld      a,63              ; Matches BASIC page mapping
    out     (IO_BANK3),a

    ; Clear bank 3
    ld      hl,$C000
    ld      bc,$4000
    ld      a,0
    call    _memset

    ; Copy CP/M to bank 3
    ld      de,$DC00
    ld      hl,cpm_start
    ld      bc,cpm_end - cpm_start
    ldir

    ; Map RAM in bank 0
    ld      a,60              ; Matches BASIC page mapping
    out     (IO_BANK0),a

    ; Jump to CP/M BIOS
    jp      $F200

_memset:
    inc     c
    inc     b
    jr      .start
.repeat:
    ld      (hl),a
    inc     hl
.start:
    dec     c
    jr      nz,.repeat
    dec     b
    jr      nz,.repeat
    ret
