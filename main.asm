
; Copyright 2018 ISSOtm



INCLUDE "hardware.inc"
	rev_Check_hardware_inc 2.6


dbfill: MACRO
	REPT \1
		db \2
	ENDR
ENDM


dstr: MACRO
	IF _NARG > 0
		REPT _NARG
			db \1
			shift
		ENDR
		db 0
	ELSE
		FAIL "Please use dstr with at least one argument"
	ENDC
ENDM


RESULT_FF75_INCORRECT = 0
RESULT_TIMING         = 1 ; Timing was off, read other instruction
RESULT_WRONG_VALUE    = 2 ; Wrong value copied from open-bus to VRAM
RESULT_SUCCESS        = 3



SECTION "rst 00",ROM0[$0000]
copyLite = $00

CopyLite::
	ld a, [hli]
	ld [de], a
	inc de
	dec c
	jr nz, CopyLite
	ret
	
SECTION "rst 08",ROM0[$0007]
memset = $08
	
Fill_Reload:
	ld a, d
Fill::
	ld [hli], a
	ld d, a
	dec bc
	ld a, b
	or c
	jr nz, Fill_Reload
	ret
	
SECTION "rst 10",ROM0[$0010]
strcpy = $10

CopyStr::
	ld a, [hli]
	and a
	ret z
	ld [de], a
	inc de
	jr CopyStr
	
SECTION "rst 18",ROM0[$0018]
	ret
	
SECTION "rst 20",ROM0[$0020]
	ret
	
SECTION "rst 28",ROM0[$0028]
	ret
	
SECTION "rst 30",ROM0[$0030]
	ret
	
SECTION "rst 38",ROM0[$0038]
	ret
	
	
SECTION "VBlank handler",ROM0[$0040]
	reti
	
SECTION "STAT handler",  ROM0[$0048]
	reti
	
SECTION "Timer handler", ROM0[$0050]
	reti
	
SECTION "Serial handler",ROM0[$0058]
	reti
	
SECTION "Joypad handler",ROM0[$0060]
	reti
	
	
SECTION "Utility funcs",ROM0

CopyToDE::
	ld a, [de]
	inc de
	ld [hli], a
	dec bc
	ld a, b
	or c
	jr nz, CopyToDE
	ret
	
	
VRAMMemset::
	ld b, a
.waitVRAM
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, .waitVRAM
	ld a, b
	ld [hli], a
	dec c
	jr nz, VRAMMemset
	ret
	
	
VRAMStrcpy::
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, VRAMStrcpy
	
	ld a, [hli]
	and a
	ret z
	ld [de], a
	inc de
	jr VRAMStrcpy
	
	
VRAMMemcpyLite::
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, VRAMMemcpyLite
	
	ld a, [hli]
	and a
	ld [de], a
	inc de
	dec c
	jr nz, VRAMMemcpyLite
	ret
	
	
LoadPalette::
	ld bc, 8 << 8 | LOW(rBCPS)
	
	bit 7, a
	jr z, .BGPalette
	inc c
	inc c
.BGPalette
	
	and $07 ; Get palette #
	add a, a ; 1 palette = 8 bytes
	add a, a
	add a, a
	or $80 ; Enable auto-increment
	ld [c], a
	inc c
	
.loadPalette
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, .loadPalette
	
	ld a, [hli]
	ld [c], a
	dec b
	jr nz, .loadPalette
	ret
	
	
PrintBCToDE::
	ld a, b
	call PrintAToDE
	
	ld a, c
PrintAToDE::
	push af
	swap a
	call .printNibble
	pop af
	
.printNibble
	and $0F
	add a, "0"
	cp ":"
	jr c, .digit
	add a, "A" - "0" - 10
.digit
	push af
	
.waitVRAM
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, .waitVRAM
	
	pop af
	ld [de], a
	inc de
	ret
	
	
	
SECTION "Entry point",ROM0[$0100]
	di
	jr Start
	nop
	
	; Allocate space for the header
	dbfill $150-$104, 0
	
Start:: ; 0150
	
	
	
SECTION "ROM start",ROM0[$0150]
	; Save init regs
	ld [hBootSP], sp
	ld sp, hBootRegsEnd
	push hl
	push de
	push bc
	push af
	
	ld sp, $D000
	
	
	; Wait till VBlank to shut LCD down
.waitVBlank
	ld a, [rSTAT]
	and 3
	dec a
	jr nz, .waitVBlank
	
	; Shut LCD down for VRAM init
	xor a
	ld [rLCDC], a
	
	ldh a, [hBootRegs+1]
	cp $11
	jr nz, .dontInitVRA1
	
	; Clear VRA1 first, otherwise DMG init goes wrong
	ld a, 1
	ld [rVBK], a
	
	ld hl, _VRAM
	ld bc, $1800
	xor a
	rst memset
	
	ld bc, SCRN_X_B
	inc a ; ld a, 1
	rst memset
	
	ld bc, $800 - SCRN_X_B
	xor a
	rst memset
	
	ld [rVBK], a
	
	
.dontInitVRA1
	; Clear VRA0
	ld hl, _VRAM
	ld bc, $1200
	xor a
	rst memset
	
	; Load font
	ld de, BasicFont
	ld bc, BasicFontEnd-BasicFont
	call CopyToDE
	
	ld bc, $800
	xor a
	rst memset
	
	; Print string for user to see
	ld hl, EmuDetectStr
	ld de, $9800
	rst strcpy
	
	
	; Init palettes
	ld a, $E4
	ld [rBGP], a
	ld [rOBP0], a
	ld [rOBP1], a
	
	ld a, $80
	ld [rBCPS], a
	ld [rOCPS], a
	
	ld bc, 8 << 8 | LOW(rBCPD)
.setCGBPalettes
	ld e, 8 ; Write 8 bytes
	ld hl, DefaultPalette
.setOnePalette
	ld a, [hli]
	ld [c], a
	ld [rOCPD], a
	dec e
	jr nz, .setOnePalette
	dec b
	jr nz, .setCGBPalettes
	
	ld hl, EmphasisPalette
	ld a, 1
	call LoadPalette
	
	
	ld hl, _OAMRAM
	ld bc, $A0
.clearOAM
	ld [hl], b
	inc l
	dec c
	jr nz, .clearOAM
	
	
	; Re-enable LCD so user sees something
	ld a, LCDCF_ON | LCDCF_BGON
	ld [rLCDC], a
	
	
InitMainMem::
	ld c, LOW(HRAMClearStart)
	xor a
.clearHRAM
	ld [c], a
	inc c ; Will also write 0 to rIE, but eh, who cares, right?
	jr nz, .clearHRAM
	
	
	ld hl, _RAM
	ld bc, $FFE ; Don't clear ret addr
	xor a
	rst memset
	
	ld d, 7
.initOneWRAMX
	ld a, d
	ld [rSVBK], a
	
	ld hl, $D000
	ld bc, $1000
	rst memset
	
	dec d
	jr nz, .initOneWRAMX
	
	
	; Copy init regs on stack (allocate buffer to do so)
	ld hl, sp - 5 * 2
	ld sp, hl
	ld c, LOW(hBootSP)
.copyBootRegs
	ld a, [c]
	ld [hli], a
	inc c
	ld a, c
	cp LOW(hBootRegsEnd)
	jr nz, .copyBootRegs
	
	ld a, 1
	ld [rVBK], a
	ld hl, $99E0
	ld c, 10
	call VRAMMemset
	xor a
	ld [rVBK], a
	
	ld hl, BootRegsStrs
	ld de, $99E0
	call VRAMStrcpy
PrintBootRegs::
	inc e ; inc de
	inc de
	call VRAMStrcpy ; Copy register name
	inc e ; inc de ; Print "space"
.waitVRAM1
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, .waitVRAM1
	ld a, "="
	ld [de], a
	inc e ; inc de
	inc e ; inc de ; Print "space"
	
	pop bc ; Get reg to be printed
	call PrintBCToDE
	
	ld a, e
	and $1F
	cp SCRN_X_B
	jr nz, PrintBootRegs
	
	ld a, e
	add a, $20 - SCRN_X_B - 2
	ld e, a
	cp $3E
	jr nz, PrintBootRegs
	
	
	
	; Lock up if on DMG
	ldh a, [hBootRegs+1]
	cp $11
	jr z, PerformDetection
	
	ld hl, CGBOnlyStr
	ld de, $9820
	call VRAMStrcpy
	jp LockUp
	
	
PerformDetection::
	xor a ; ld a, RESULT_FF75
	ldh [hTestResult], a
	; Begin by checking $FF75's behavior
	ld hl, TestingFF75Str
	ld de, $9821
	call VRAMStrcpy
	ld de, $9848
	call VRAMStrcpy
	
	ld c, $75
	; Write 0, should return $FF
	xor a
	ld [c], a
	ld a, [c]
	ld b, a
	ld de, $9830
	call PrintAToDE
	ld a, b
	sub $8F
	jp nz, TestEnd
	
	; Write $FF, should return $FF
	dec a ; ld a, $FF
	ld [c], a
	ld a, [c]
	ld b, a
	ld de, $9850
	call PrintAToDE
	ld a, b
	inc a ; cp $FF
	jp nz, TestEnd
	
	
	ld a, RESULT_TIMING
	ldh [hTestResult], a
	ld hl, HangingStr
	ld de, $98A0
	call VRAMStrcpy
	
	ld a, STATF_MODE10 ; Enable Mode 0
	ld [rSTAT], a
	ld a, IEF_LCDC
	ld [rIE], a ; Enable STAT int
	ld b, 0
	
.tryHDMA
	ld c, LOW(rHDMA1)
	ld a, $E0
	ld [c], a
	inc c
	ld [c], a ; From $E0E0 (uh oh, Nintendo says not to do that)
	inc c
	ld a, $88
	ld [c], a
	inc c
	ld a, b
	ld [c], a ; To $88X0 (really anything is fine)
	inc c ; Leave C pointing to HDMA length
	
	xor a ; We need IF = 0 when HALT is hit
	ld [rIF], a
	; There's a 1-cycle flaw here, but I dunno how to do better...
	halt
	; Alright, we're perfectly synced with the PPU, and in Mode 2. What could go wrong, Mr. Emulator ?
	ld a, $80
	ld [c], a
	
	; Delay until HDMA occurs
	ld a, 12
.delay
	dec a
	jr nz, .delay
	nop
	nop
	nop
	
	ld hl, $FF75 ; Only bits 4-6 are writable
	; Let's say b = $10
	ld [hl], b ; Now, $FF75 = $10 | $8F = $9F
	inc [hl] ; Puts $A0 on the data bus, and $A0 | $8F = $AF in $FF75
	; Assume HDMA triggers here
	
	ld a, b
	xor $10
	ld b, a
	jr nz, .tryHDMA
	
	inc a ; ld a, 1
	ld [rVBK], a
	ld hl, $98E0
	ld c, 12
	call VRAMMemset
	xor a
	ld [rVBK], a
	
	ld hl, HDMAResultsStrs
	ld de, $98E0
	call VRAMStrcpy
	ld de, $9900
	call VRAMStrcpy
	ld e, $20
	call VRAMStrcpy
	
	; Check what was copied
	ld hl, $8800
	ld de, EmuDetectionPattern
	ld c, 16 * 2
.compare
	ld a, [rSTAT]
	and STATF_BUSY
	jr nz, .compare
	
	ld a, [de]
	inc de
	cp [hl]
	jr nz, .failure
	inc hl
	dec c
	jr nz, .compare
	
	ld a, RESULT_SUCCESS
	db $11
.failure
	ld a, RESULT_WRONG_VALUE
	
	ldh [hTestResult], a
	ld hl, EmuDetectionPattern
	ld de, $8820
	ld c, 16 * 2
	call VRAMMemcpyLite
	
	
TestEnd::
	ld a, 1
	ld [rVBK], a
	ld hl, $9980
	ld c, 12
	call VRAMMemset
	xor a
	ld [rVBK], a
	
	ld hl, TestResultStrs
	ld de, $9980
	call VRAMStrcpy
	
	; Get ptr to test result's string
	ldh a, [hTestResult]
	add a, a
	add a, l
	ld l, a
	adc a, h
	sub l
	ld h, a
	
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld de, $99A1
	call VRAMStrcpy
	
	
	
LockUp::
	xor a
	ld [rIE], a
	halt
	; Never reached
	
	
	
SECTION "Output strings",ROM0

EmuDetectStr::
	dstr "EMU DETECT"
CGBOnlyStr::
	dstr "THIS ROM IS CGB-ONLY"
	
BootRegsStrs::
	dstr "BOOT REGS"
	dstr "SP"
	dstr "AF"
	dstr "BC"
	dstr "DE"
	dstr "HL"
	
	
TestingFF75Str::
	dstr "$FF75: $00 -> $"
	dstr "$FF -> $"
	
	
HangingStr::
	dstr "IF THIS HANGS\, FAIL"
	dstr "NO HANG\, YAY"
	
	
HDMAResultsStrs::
	dstr "HDMA RESULT:"
	dstr "RESULT:   ",$80,$81
	dstr "EXPECTED: ",$82,$83
	
	
TestResultStrs::
	dstr "TEST RESULT:"
	
	dw .ff75
	dw .length
	dw .value
	dw .success
	
.ff75
	dstr "BAD FF75 VALUE"
	
.length
	dstr "HDMA LEN TOO SHORT"
	
.value
	dstr "BAD VALUE COPIED"
	
.success
	dstr "TEST SUCCEEDED"
	
	
	
SECTION "Palettes",ROM0

DefaultPalette::
	dw $7FFF, $56B5, $294A, $0000
	
EmphasisPalette::
	dw $56B5, $294A, $0000, $0000
	
	
SECTION "Tile pattern",ROM0

EmuDetectionPattern::
	dbfill 16, $90
	dbfill 16, $A0
	
	
	
SECTION "HRAM",HRAM

hBootSP::
	dw ; sp
hBootRegs::
	dw ; af
	dw ; bc
	dw ; de
	dw ; hl
hBootRegsEnd::
	
HRAMClearStart::
	
hTestResult::
	db
	
	
	
SECTION "Font",ROM0

; Font taken from another project (https://github.com/ISSOtm/Aevilia-GB)
; Made by Kai/kaikun97

BasicFont:: ; These correspond to ASCII characters
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000 ; Space
	
	; Symbols 1
	dw $8000, $8000, $8000, $8000, $8000, $0000, $8000, $0000
	dw $0000, $6C00, $6C00, $4800, $0000, $0000, $0000, $0000
	dw $4800, $FC00, $4800, $4800, $4800, $FC00, $4800, $0000
	dw $1000, $7C00, $9000, $7800, $1400, $F800, $1000, $0000
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000 ; %, empty slot for now
	dw $6000, $9000, $5000, $6000, $9400, $9800, $6C00, $0000
	dw $0000, $3800, $3800, $0800, $1000, $0000, $0000, $0000
	dw $1800, $2000, $2000, $2000, $2000, $2000, $1800, $0000
	dw $1800, $0400, $0400, $0400, $0400, $0400, $1800, $0000
	dw $0000, $1000, $5400, $3800, $5400, $1000, $0000, $0000
	dw $0000, $1000, $1000, $7C00, $1000, $1000, $0000, $0000
	dw $0000, $0000, $0000, $0000, $3000, $3000, $6000, $0000
	dw $0000, $0000, $0000, $7C00, $0000, $0000, $0000, $0000
	dw $0000, $0000, $0000, $0000, $0000, $6000, $6000, $0000
	dw $0000, $0400, $0800, $1000, $2000, $4000, $8000, $0000
	dw $3000, $5800, $CC00, $CC00, $CC00, $6800, $3000, $0000
	dw $3000, $7000, $F000, $3000, $3000, $3000, $FC00, $0000
	dw $7800, $CC00, $1800, $3000, $6000, $C000, $FC00, $0000
	dw $7800, $8C00, $0C00, $3800, $0C00, $8C00, $7800, $0000
	dw $3800, $5800, $9800, $FC00, $1800, $1800, $1800, $0000
	dw $FC00, $C000, $C000, $7800, $0C00, $CC00, $7800, $0000
	dw $7800, $CC00, $C000, $F800, $CC00, $CC00, $7800, $0000
	dw $FC00, $0C00, $0C00, $1800, $1800, $3000, $3000, $0000
	dw $7800, $CC00, $CC00, $7800, $CC00, $CC00, $7800, $0000
	dw $7800, $CC00, $CC00, $7C00, $0C00, $CC00, $7800, $0000
	dw $0000, $C000, $C000, $0000, $C000, $C000, $0000, $0000
	dw $0000, $C000, $C000, $0000, $C000, $4000, $8000, $0000
	dw $0400, $1800, $6000, $8000, $6000, $1800, $0400, $0000
	dw $0000, $0000, $FC00, $0000, $FC00, $0000, $0000, $0000
	dw $8000, $6000, $1800, $0400, $1800, $6000, $8000, $0000
	dw $7800, $CC00, $1800, $3000, $2000, $0000, $2000, $0000
	dw $0000, $2000, $7000, $F800, $F800, $F800, $0000, $0000 ; "Up" arrow, not ASCII but otherwise unused :P
	
	; Uppercase
	dw $3000, $4800, $8400, $8400, $FC00, $8400, $8400, $0000
	dw $F800, $8400, $8400, $F800, $8400, $8400, $F800, $0000
	dw $3C00, $4000, $8000, $8000, $8000, $4000, $3C00, $0000
	dw $F000, $8800, $8400, $8400, $8400, $8800, $F000, $0000
	dw $FC00, $8000, $8000, $FC00, $8000, $8000, $FC00, $0000
	dw $FC00, $8000, $8000, $FC00, $8000, $8000, $8000, $0000
	dw $7C00, $8000, $8000, $BC00, $8400, $8400, $7800, $0000
	dw $8400, $8400, $8400, $FC00, $8400, $8400, $8400, $0000
	dw $7C00, $1000, $1000, $1000, $1000, $1000, $7C00, $0000
	dw $0400, $0400, $0400, $0400, $0400, $0400, $F800, $0000
	dw $8400, $8800, $9000, $A000, $E000, $9000, $8C00, $0000
	dw $8000, $8000, $8000, $8000, $8000, $8000, $FC00, $0000
	dw $8400, $CC00, $B400, $8400, $8400, $8400, $8400, $0000
	dw $8400, $C400, $A400, $9400, $8C00, $8400, $8400, $0000
	dw $7800, $8400, $8400, $8400, $8400, $8400, $7800, $0000
	dw $F800, $8400, $8400, $F800, $8000, $8000, $8000, $0000
	dw $7800, $8400, $8400, $8400, $A400, $9800, $6C00, $0000
	dw $F800, $8400, $8400, $F800, $9000, $8800, $8400, $0000
	dw $7C00, $8000, $8000, $7800, $0400, $8400, $7800, $0000
	dw $7C00, $1000, $1000, $1000, $1000, $1000, $1000, $0000
	dw $8400, $8400, $8400, $8400, $8400, $8400, $7800, $0000
	dw $8400, $8400, $8400, $8400, $8400, $4800, $3000, $0000
	dw $8400, $8400, $8400, $8400, $B400, $CC00, $8400, $0000
	dw $8400, $8400, $4800, $3000, $4800, $8400, $8400, $0000
	dw $4400, $4400, $4400, $2800, $1000, $1000, $1000, $0000
	dw $FC00, $0400, $0800, $1000, $2000, $4000, $FC00, $0000
	
	; Symbols 2
	dw $3800, $2000, $2000, $2000, $2000, $2000, $3800, $0000
	dw $0000, $8000, $4000, $2000, $1000, $0800, $0400, $0000
	dw $1C00, $0400, $0400, $0400, $0400, $0400, $1C00, $0000
	dw $1000, $2800, $0000, $0000, $0000, $0000, $0000, $0000
	dw $0000, $0000, $0000, $0000, $0000, $0000, $0000, $FF00
	dw $C000, $6000, $0000, $0000, $0000, $0000, $0000, $0000
	
	; Lowercase
	dw $0000, $0000, $7800, $0400, $7C00, $8400, $7800, $0000
	dw $8000, $8000, $8000, $F800, $8400, $8400, $7800, $0000
	dw $0000, $0000, $7C00, $8000, $8000, $8000, $7C00, $0000
	dw $0400, $0400, $0400, $7C00, $8400, $8400, $7800, $0000
	dw $0000, $0000, $7800, $8400, $F800, $8000, $7C00, $0000
	dw $0000, $3C00, $4000, $FC00, $4000, $4000, $4000, $0000
	dw $0000, $0000, $7800, $8400, $7C00, $0400, $F800, $0000
	dw $8000, $8000, $F800, $8400, $8400, $8400, $8400, $0000
	dw $0000, $1000, $0000, $1000, $1000, $1000, $1000, $0000
	dw $0000, $1000, $0000, $1000, $1000, $1000, $E000, $0000
	dw $8000, $8000, $8400, $9800, $E000, $9800, $8400, $0000
	dw $1000, $1000, $1000, $1000, $1000, $1000, $1000, $0000
	dw $0000, $0000, $6800, $9400, $9400, $9400, $9400, $0000
	dw $0000, $0000, $7800, $8400, $8400, $8400, $8400, $0000
	dw $0000, $0000, $7800, $8400, $8400, $8400, $7800, $0000
	dw $0000, $0000, $7800, $8400, $8400, $F800, $8000, $0000
	dw $0000, $0000, $7800, $8400, $8400, $7C00, $0400, $0000
	dw $0000, $0000, $BC00, $C000, $8000, $8000, $8000, $0000
	dw $0000, $0000, $7C00, $8000, $7800, $0400, $F800, $0000
	dw $0000, $4000, $F800, $4000, $4000, $4000, $3C00, $0000
	dw $0000, $0000, $8400, $8400, $8400, $8400, $7800, $0000
	dw $0000, $0000, $8400, $8400, $4800, $4800, $3000, $0000
	dw $0000, $0000, $8400, $8400, $8400, $A400, $5800, $0000
	dw $0000, $0000, $8C00, $5000, $2000, $5000, $8C00, $0000
	dw $0000, $0000, $8400, $8400, $7C00, $0400, $F800, $0000
	dw $0000, $0000, $FC00, $0800, $3000, $4000, $FC00, $0000
	
	; Symbols 3
	dw $1800, $2000, $2000, $4000, $2000, $2000, $1800, $0000
	dw $1000, $1000, $1000, $1000, $1000, $1000, $1000, $0000
	dw $3000, $0800, $0800, $0400, $0800, $0800, $3000, $0000
	dw $0000, $0000, $4800, $A800, $9000, $0000, $0000, $0000
	
	dw $C000, $E000, $F000, $F800, $F000, $E000, $C000, $0000 ; Left arrow
BasicFontEnd::
	
	
