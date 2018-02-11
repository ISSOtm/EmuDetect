
.SHELL: /bin/bash
.PHONY: all rebuild clean
.SUFFIXES:
.DEFAULT_GOAL: all


FillValue = 0xFF
ROMVersion = 0

GameID = ISSO
GameTitle = EMUDETECT
NewLicensee = 42
OldLicensee = 0x33
# ROM
MBCType = 0x00
# ROMSize = 0x00
SRAMSize = 0x00

ASFLAGS  = -E -p $(FillValue)
LDFLAGS  = -t # Enable ROM32k
FIXFLAGS = -Cjv -i $(GameID) -k $(NewLicensee) -l $(OldLicensee) -m $(MBCType) -n $(ROMVersion) -p $(FillValue) -r $(SRAMSize) -t $(GameTitle)

RGBASM = rgbasm
RGBLINK = rgblink
RGBFIX = rgbfix


all: emu_detect.gbc

rebuild: clean all

clean:
	rm -f *.o
	rm -f emu_detect.gbc emu_detect.map emu_detect.sym

%.sym:
	rm $(@:.sym=.gbc)
	make $(@:.sym=.gbc)

emu_detect.gbc: main.o
	$(RGBLINK) $(LDFLAGS) -n $(@:.gbc=.sym) -m $(@:.gbc=.map) -o $@ $^
	$(RGBFIX) $(FIXFLAGS) $(@)
	
	
%.o: %.asm
	$(RGBASM) $(ASFLAGS) -o $@ $<

