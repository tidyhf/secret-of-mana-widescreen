asar 1.90
; Secret of Mana (U) widescreen hack for bsnes-hd
; asar 1.90, clean headerless ROM
hirom

!WS_EXT = 80        ; px valid on each side
!FREE_C7 = $C74290  ; free space C7:4285-4FFF

; --- BG column streaming ---
org $C0C910 : LDA.w #$10000-!WS_EXT
org $C0C915 : LDA.w #256+!WS_EXT
org $C0C931 : LDA.w #$10000-!WS_EXT
org $C0C936 : LDA.w #256+!WS_EXT

org $C0C945
    JSL ws_col_bg1
    RTS
org $C0D158
    JSL ws_col_bg2
    RTS

; --- BG rows, full 512px ---
org $C0C859
    JSL ws_row_bg1
    RTS
org $C0D0C2
    JSL ws_row_bg2
    RTS

; row DMA (NMI)
org $C0C702
    JSL ws_row_dma
    RTS

; --- sprite clip range ---
org $C0E67F : CMP.w #256+!WS_EXT
org $C0E686 : CMP.w #$10000-!WS_EXT
org $C0E837 : CMP.w #256+!WS_EXT
org $C0E83D : CMP.w #$10000-!WS_EXT
org $C0E844 : CMP.w #256+!WS_EXT

; --- small maps: centre + lock camera X ---
org $C0CA71
    JSL ws_initcam
org $C0DBDA
    JML ws_bg1x_apply
org $C0DC56
    JML ws_bg2x_apply

; --- sprite X wrap fix (draw only) ---
org $C0E640
    JSL ws_draw_piece
org $C0E6CB
    BRL ws_piece_loop
org $C0C960
ws_piece_loop:
    SEP #$20
    LDY $7C
    JMP $E644
assert pc() <= $C0C9E0
org $C0E82F
    JSL ws_draw_shadow
    NOP
    NOP

; --- offscreen object checks ---
org $C0FC5A : dw $0140+!WS_EXT
org $C0FC62 : dw $FFC0-!WS_EXT
org $C2A379 : dw $0120+!WS_EXT
org $C2A37E : dw $FFE0-!WS_EXT

; --- NMI: HOFS bit 9 (keeps bsnes-hd auto-ws on in field) ---
org $C0C17B
    JSL ws_nmi_bg1h
    NOP
org $C0C197
    JSL ws_nmi_bg2h
    NOP
org $C0C1AA
    JSL ws_nmi_bg2h
    NOP

; --- Flammie sky streaming ---
org $C0849B
    JSL ws_sky_vcol
    NOP
org $C084D8
    JSL ws_sky1_pcol
    NOP
org $C0851A
    JSL ws_sky_vcol
    NOP
org $C08557
    JSL ws_sky2_pcol
    NOP

; takeoff: extra sky fill
org $C099EC
    JMP ws_skyfill_end
org $C0C860
ws_skyfill_end:
    SEP #$20
    DEC $11
    BEQ .extra
    JMP $99CF
.extra:
    LDA #20
    STA $11
.l1:
    REP #$20
    SEP #$10
    LDY #$04
    LDX #$00
    JSR $8455
    REP #$20
    SEP #$10
    JSR $8890
    SEP #$20
    DEC $11
    BNE .l1
    LDA #20
    STA $11
.l2:
    REP #$20
    SEP #$10
    LDY #$04
    LDX #$20
    JSR $8455
    REP #$20
    SEP #$10
    JSR $8890
    SEP #$20
    DEC $11
    BNE .l2
    RTS
assert pc() <= $C0C8EF

; --- BG bosses: visibility window ---
org $C21069 : dw $0120
org $C2106F : dw $01D0


org !FREE_C7
!BLANK = $035F      ; empty BG char
!SMALLMAP = 256+2*!WS_EXT

macro ws_logical_t(camx, mapw_px)
    LDA <camx>
    CLC
    ADC #$0080
?mod:
    CMP <mapw_px>
    BCC ?done
    SBC <mapw_px>
    BRA ?mod
?done:
endmacro

; column builder, $00 = x offset
macro ws_col(camx, camy, scrx, scry, mapw_px, maph_px, mapbase, vramA, vramB, vaddr, mtdefs, buf, clamp)
    REP #$30
    LDA <scrx>
    CLC
    ADC $00
    SEP #$20
    LSR
    LSR
    LSR
    AND #$1E
    STA <vaddr>
    XBA
    LSR
    LDA.b #<vramA>
    BCC ?vA
    LDA.b #<vramB>
?vA:
    STA <vaddr>+1
    REP #$20
    %ws_logical_t(<camx>, <mapw_px>)
    SEC
    SBC #$0080
    CLC
    ADC $00
    BMI ?outneg
    CMP <mapw_px>
    BCC ?inmap
    TAY
    LDA $C0
    CMP.w #!SMALLMAP
    BCS ?bigr
if <clamp>
    LDA <mapw_px>
    DEC
    BRA ?inmap
else
    TYA
    JMP ?edgemode
endif
?bigr:
    TYA
    SEC
    SBC <mapw_px>
    BRA ?inmap
?outneg:
    TAY
    LDA $C0
    CMP.w #!SMALLMAP
    BCS ?bigl
if <clamp>
    LDA #$0000
    BRA ?inmap
else
    TYA
    JMP ?edgemode
endif
?bigl:
    TYA
    CLC
    ADC <mapw_px>
?inmap:
    LSR
    LSR
    LSR
    LSR
    STA $1A
    LDA <camy>
    AND #$07F0
    STA $04
    ASL
    ASL
    ASL
    ADC <mapbase>
    ORA $1A
    STA $10
    LDA <maph_px>
    SEC
    SBC $04
    LSR
    LSR
    LSR
    LSR
    STA $04
    LDA <mapbase>
    ORA $1A
    STA $1A
    LDA <scry>
    LSR
    LSR
    AND #$003C
    TAX
    LDA #$0010
    STA $00
?loop:
    LDA ($10)
    AND #$00FF
    ASL
    ASL
    ASL
    TAY
    LDA $10
    CLC
    ADC #$0080
    STA $10
    DEC $04
    BNE ?nowrap
    LDA $1A
    STA $10
?nowrap:
    LDA.w <mtdefs>+0,Y
    STA.w <buf>+$00,X
    LDA.w <mtdefs>+2,Y
    STA.w <buf>+$40,X
    LDA.w <mtdefs>+4,Y
    STA.w <buf>+$02,X
    LDA.w <mtdefs>+6,Y
    STA.w <buf>+$42,X
    INX
    INX
    INX
    INX
    CPX #$0040
    BCC ?nowrapx
    LDX #$0000
?nowrapx:
    DEC $00
    BNE ?loop
    SEP #$30
    RTL
if <clamp> == 0
?edgemode:
    LDY #$0000
    CMP #$8000
    BCC ?er
    CLC
    ADC <mapw_px>
    BRA ?ewrapped
?er:
    SEC
    SBC <mapw_px>
    LDY <mapw_px>
    DEY
?ewrapped:
    LSR
    LSR
    LSR
    LSR
    STA $1A
    TYA
    LSR
    LSR
    LSR
    LSR
    STA $0A
    LDA <camy>
    AND #$07F0
    STA $04
    ASL
    ASL
    ASL
    ADC <mapbase>
    PHA
    ORA $1A
    STA $10
    PLA
    ORA $0A
    STA $08
    LDA <maph_px>
    SEC
    SBC $04
    LSR
    LSR
    LSR
    LSR
    STA $04
    LDA <mapbase>
    ORA $1A
    STA $1A
    LDA <mapbase>
    ORA $0A
    STA $0A
    LDA <scry>
    LSR
    LSR
    AND #$003C
    TAX
    LDA #$0010
    STA $00
?eloop:
    LDA ($08)
    PHX
    JSR ws_void1
    PLX
    BCS ?eblank
    LDA ($10)
    AND #$00FF
    ASL
    ASL
    ASL
    TAY
    LDA.w <mtdefs>+0,Y
    STA.w <buf>+$00,X
    LDA.w <mtdefs>+2,Y
    STA.w <buf>+$40,X
    LDA.w <mtdefs>+4,Y
    STA.w <buf>+$02,X
    LDA.w <mtdefs>+6,Y
    STA.w <buf>+$42,X
    BRA ?enext
?eblank:
    LDA.w #!BLANK
    STA.w <buf>+$00,X
    STA.w <buf>+$40,X
    STA.w <buf>+$02,X
    STA.w <buf>+$42,X
?enext:
    LDA $10
    CLC
    ADC #$0080
    STA $10
    LDA $08
    CLC
    ADC #$0080
    STA $08
    DEC $04
    BNE ?enowrap
    LDA $1A
    STA $10
    LDA $0A
    STA $08
?enowrap:
    INX
    INX
    INX
    INX
    CPX #$0040
    BCC ?enowrapx
    LDX #$0000
?enowrapx:
    DEC $00
    BNE ?eloop
    SEP #$30
    RTL
endif
?blank:
    LDX #$003E
    LDA.w #!BLANK
?bl:
    STA.w <buf>+$00,X
    STA.w <buf>+$40,X
    DEX
    DEX
    BPL ?bl
    SEP #$30
    RTL
endmacro

; C = metatile is empty
ws_void1:
    AND #$00FF
    ASL
    ASL
    ASL
    TAX
    LDA $C000,X
    AND #$03FF
    CMP.w #!BLANK
    BNE .no
    LDA $C002,X
    AND #$03FF
    CMP.w #!BLANK
    BNE .no
    LDA $C004,X
    AND #$03FF
    CMP.w #!BLANK
    BNE .no
    LDA $C006,X
    AND #$03FF
    CMP.w #!BLANK
    BNE .no
    SEC
    RTS
.no:
    CLC
    RTS

ws_col_bg1:
    %ws_col($A8, $AA, $B0, $B2, $C0, $C2, $C8, $50, $54, $78, $C000, $D200, 0)
ws_col_bg2:
    %ws_col($AC, $AE, $B4, $B6, $C4, $C6, $CA, $38, $3C, $A6, $C800, $D280, 1)

; row builder, $00 = y offset
macro ws_row(camx, camy, scrx, scry, mapw_px, maph_px, mapbase, mapw_mt, vrambase, out, mtdefs, buf, clamp)
    REP #$30
    LDA <camy>
    CLC
    ADC $00
    CMP <maph_px>
    BCC ?nowrapy
    SBC <maph_px>
?nowrapy:
    AND #$07F0
    ASL
    ASL
    ASL
    ADC <mapbase>
    STA $10
    LDA $00
    CLC
    ADC <scry>
    AND #$00F0
    ASL
    ASL
    ORA.w #<vrambase>
    STA <out>
    LDA <mapw_mt>
    AND #$00FF
    STA $06
    %ws_logical_t(<camx>, <mapw_px>)
    PHA
    AND #$000F
    CMP #$0001
    LDA #$0018
    ADC #$0000
    STA $08
    PLA
    LSR
    LSR
    LSR
    LSR
    SEC
    SBC #$0010
    STA $04
    LDA <scrx>
    LSR
    LSR
    LSR
    LSR
    SEC
    SBC #$0008
    AND #$001F
    ASL
    ASL
    STA $1A
    LDA #$0000
    STA $00
?loop:
    LDA $00
    CMP #$0008
    BCC ?ws
    CMP $08
    BCS ?ws
?wrapcol:
    LDA $04
?wrapneg:
    BPL ?wrappos
    CLC
    ADC $06
    BRA ?wrapneg
?wrappos:
    CMP $06
    BCC ?colok
    SBC $06
    BRA ?wrappos
?ws:
    LDA $C0
    CMP.w #!SMALLMAP
    BCS ?wrapcol
if <clamp>
    LDA $04
    BPL ?cnotneg
    LDA #$0000
    BRA ?colok
?cnotneg:
    CMP $06
    BCC ?colok
    LDA $06
    DEC
    BRA ?colok
else
    LDA $04
    BMI ?edgeL
    CMP $06
    BCC ?colok
    LDA $06
    DEC
    BRA ?edgechk
?edgeL:
    LDA #$0000
?edgechk:
    TAY
    LDA ($10),Y
    JSR ws_void1
    BCS ?blank
    JMP ?wrapcol
endif
?colok:
    TAY
    LDA ($10),Y
    AND #$00FF
    ASL
    ASL
    ASL
    TAY
    LDX $1A
    LDA.w <mtdefs>+0,Y
    STA.w <buf>+$00,X
    LDA.w <mtdefs>+2,Y
    STA.w <buf>+$02,X
    LDA.w <mtdefs>+4,Y
    STA.w <buf>+$80,X
    LDA.w <mtdefs>+6,Y
    STA.w <buf>+$82,X
    BRA ?next
?blank:
    LDX $1A
    LDA.w #!BLANK
    STA.w <buf>+$00,X
    STA.w <buf>+$02,X
    STA.w <buf>+$80,X
    STA.w <buf>+$82,X
?next:
    LDA $1A
    CLC
    ADC #$0004
    AND #$007C
    STA $1A
    INC $04
    INC $00
    LDA $00
    CMP #$0020
    BCS ?rowdone
    JMP ?loop
?rowdone:
    SEP #$10
endmacro

ws_row_bg1:
    %ws_row($A8, $AA, $B0, $B2, $C0, $C2, $C8, $9C, $5000, $76, $C000, $D000, 0)
    RTL

ws_row_bg2:
    %ws_row($AC, $AE, $B4, $B6, $C4, $C6, $CA, $A0, $3800, $A4, $C800, $D100, 1)
    RTL

macro ws_dma64(src, vramexpr_dp, add)
    LDX.w #<src>
    STX $4372
    REP #$20
    LDA <vramexpr_dp>
    CLC
    ADC.w #<add>
    STA $2116
    SEP #$20
    LDA #$40
    STA $4375
    LDA #$80
    STA $420B
endmacro

ws_row_dma:
    LDA $2E
    BPL .bg2
    %ws_dma64($D000, $76, $0000)
    %ws_dma64($D040, $76, $0400)
    %ws_dma64($D080, $76, $0020)
    %ws_dma64($D0C0, $76, $0420)
.bg2:
    BIT $2E
    BVC .done
    %ws_dma64($D100, $A4, $0000)
    %ws_dma64($D140, $A4, $0400)
    %ws_dma64($D180, $A4, $0020)
    %ws_dma64($D1C0, $A4, $0420)
.done:
    STZ $2E
    RTL

ws_is_small:
    PHP
    REP #$20
    LDA $C0
    CMP.w #!SMALLMAP
    BCS .big
    PLP
    CLC
    RTS
.big:
    PLP
    SEC
    RTS

ws_initcam:
    REP #$20
    SEP #$10
    JSR ws_is_small
    BCS .done
    LDA $C0
    SEC
    SBC #$0100
    CMP #$8000
    ROR
    BPL .pos
    CLC
    ADC $C0
.pos:
    STA $A8
    AND #$FFF0
    STA $88
    LDX $B9
    BEQ .done
    LDA $A8
.mod2:
    CMP $C4
    BCC .ok2
    SBC $C4
    BRA .mod2
.ok2:
    STA $AC
    AND #$FFF0
    STA $8C
.done:
    REP #$20
    SEP #$10
    RTL

ws_bg1x_apply:
    SEP #$30
    JSR ws_is_small
    BCS .go
    JML $00DBFA
.go:
    LDA $84
    JML $00DBDE

ws_bg2x_apply:
    SEP #$30
    JSR ws_is_small
    BCS .go
    JML $00DC5C
.go:
    LDA $B9
    JML $00DC5A

ws_norm_x:
    PHA
    LDA $C0
    LSR
    EOR #$FFFF
    SEC
    ADC #$0080
    CMP 1,S
    BEQ .ret
    BPL .low
    CLC
    ADC $C0
    CMP 1,S
    BEQ .high
    BPL .ret
.high:
    PLA
    SEC
    SBC $C0
    RTS
.low:
    PLA
    CLC
    ADC $C0
    RTS
.ret:
    PLA
    RTS

ws_draw_piece:
    SEP #$20
    LDA $C1
    CMP #$02
    BCS .done
    REP #$20
    LDA $04
    JSR ws_norm_x
    STA $04
    SEP #$20
.done:
    LDY $7C
    RTL

ws_draw_shadow:
    LDA $C0
    CMP #$0200
    LDA $E020,X
    BCS .big
    JSR ws_norm_x
.big:
    CLC
    ADC $02
    RTL

!PARKFLAG = $1DF8   ; unused WRAM
; also hides a parked BG boss ($FEF0)
ws_nmi_bg1h:
    LDA $B1
    ORA #$02
    STA $210D
    LDA #$00
    PHA
    LDA $B1
    CMP #$FE
    BNE .p2
    LDA $B0
    CMP #$F0
    BNE .p2
    LDA #$01
    ORA 1,S
    STA 1,S
.p2:
    LDA $B5
    CMP #$FE
    BNE .p3
    LDA $B4
    CMP #$F0
    BNE .p3
    LDA #$02
    ORA 1,S
    STA 1,S
.p3:
    LDA 1,S
    BNE .masked
    LDA !PARKFLAG
    BEQ .done
    LDA #$00
    STA !PARKFLAG
    LDA $21
    STA $212C
    LDA $22
    STA $212D
    BRA .done
.masked:
    STA !PARKFLAG
    EOR #$FF
    AND $21
    STA $212C
    LDA 1,S
    EOR #$FF
    AND $22
    STA $212D
.done:
    PLA
    RTL
ws_nmi_bg2h:
    LDA $B5
    ORA #$02
    STA $210F
    RTL

!SKYEXT = !WS_EXT/8
ws_sky_vcol:
    PHA
    LDA $00
    BEQ .left
    PLA
    CLC
    ADC.b #32+!SKYEXT
    AND #$3F
    RTL
.left:
    PLA
    SEC
    SBC.b #!SKYEXT
    AND #$3F
    RTL

macro ws_skyp(ncols)
    PHA
    LDA $00
    BEQ ?left
    PLA
    CLC
    ADC.b #!SKYEXT
    CMP.b #<ncols>
    BCC ?done
    SBC.b #<ncols>
    BRA ?done
?left:
    PLA
    SEC
    SBC.b #!SKYEXT
    BCS ?done
    ADC.b #<ncols>
?done:
    REP #$20
    AND #$00FF
    RTL
endmacro
ws_sky1_pcol:
    %ws_skyp($E0)
ws_sky2_pcol:
    %ws_skyp($A0)

ws_end:
assert ws_end <= $C75000, "C7 free space overflow"
