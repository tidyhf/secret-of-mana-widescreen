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

; --- shadow: no wrap past the left edge ---
org $C0E842
    BRA ws_ret_e83c
org $C0E83C
ws_ret_e83c:

; --- skipped sprite piece: hide its slot (the game leaves y set, x=255) ---
org $C0E6C1
    JSL ws_piece_skip

; --- multi-part object drawer (C2) clip range + x bit 8 ---
org $C220A9 : dw !WS_EXT
org $C220AF : dw 256+2*!WS_EXT
org $C22118 : LSR

; --- ROM expanded to 4MB for the reach tables ---
org $C0FFD7 : db $0C
incsrc reach.asm

; --- column handler: reach guard + strip rebuild ---
org $C0C8F1
    JSL ws_colhook

; --- small maps: centre + lock camera X ---
org $C0CA71
    JSL ws_initcam
org $C0D6AC
    JSR ws_follow_stub

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
ws_follow_stub:
    JSL ws_follow
    JMP $DA6E
assert pc() <= $C0C9E0
org $C0E82F
    JSL ws_draw_shadow
    NOP
    NOP

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

; --- intro log scene: widen BG3 on the log band only ---
org $C0C158
    JSL ws_hdma_en

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
!RTAB = $1DBA
!RROW = $7E1DB8
!RWM = $7E1DBC
!RHM = $7E1DBE
!RLO = $7E1DA0
!RHI = $7E1DA2
!FIXN = $7E1DA4
!FIXSIDE = $7E1DA6
!FIXBG2 = $7E1DA8
!LASTC = $7E1DAA
!BG2USED = $7E1DAC
!BG2OFF = $7E1DAE
!FIXCAM = $7E1D9C
!FIXCAM2 = $7E1D9E

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
macro ws_col(camx, camy, scrx, scry, mapw_px, maph_px, mapbase, vramA, vramB, vaddr, mtdefs, buf, clamp, bg2)
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
    TAY
if <bg2>
    JSR ws_reach_on2
else
    JSR ws_reach_on
endif
    BCC ?noreach
    TYA
    JMP ?reachmode
?noreach:
    TYA
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
?reachmode:
    CMP #$8000
    ROR
    CMP #$8000
    ROR
    CMP #$8000
    ROR
    CMP #$8000
    ROR
    STA $0A
    LDA <camy>
    AND #$07F0
    LSR
    LSR
    LSR
    LSR
    STA.l !RROW
    LDA <scry>
    LSR
    LSR
    AND #$003C
    TAX
    LDA #$0010
    STA $00
?rloop:
    PHX
    LDA $0A
    JSR ws_reach_col
?rneg:
    BPL ?rpos
    CLC
    ADC.l !RWM
    BRA ?rneg
?rpos:
    CMP.l !RWM
    BCC ?rok
    SBC.l !RWM
    BRA ?rpos
?rok:
    STA $1A
    LDA.l !RROW
    XBA
    LSR
    CLC
    ADC <mapbase>
    ADC $1A
    STA $10
    PLX
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
    LDA.l !RROW
    INC
    CMP.l !RHM
    BCC ?rnw
    LDA #$0000
?rnw:
    STA.l !RROW
    INX
    INX
    INX
    INX
    CPX #$0040
    BCC ?rnwx
    LDX #$0000
?rnwx:
    DEC $00
    BNE ?rloop
    SEP #$30
    RTL
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
    %ws_col($A8, $AA, $B0, $B2, $C0, $C2, $C8, $50, $54, $78, $C000, $D200, 0, 0)
ws_col_bg2:
    %ws_col($AC, $AE, $B4, $B6, $C4, $C6, $CA, $38, $3C, $A6, $C800, $D280, 1, 1)

; row builder, $00 = y offset
macro ws_row(camx, camy, scrx, scry, mapw_px, maph_px, mapbase, mapw_mt, vrambase, out, mtdefs, buf, clamp, bg2)
    REP #$30
    LDA <camy>
    CLC
    ADC $00
    CMP <maph_px>
    BCC ?nowrapy
    SBC <maph_px>
?nowrapy:
    AND #$07F0
    PHA
    LSR
    LSR
    LSR
    LSR
    STA.l !RROW
    PLA
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
    BCC ?wsmall
if <bg2>
    JSR ws_reach_on2
else
    JSR ws_reach_on
endif
    BCC ?wrapcol
    LDA $04
    JSR ws_reach_col
    JMP ?wrapneg
?wsmall:
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
    %ws_row($A8, $AA, $B0, $B2, $C0, $C2, $C8, $9C, $5000, $76, $C000, $D000, 0, 0)
    RTL

ws_row_bg2:
    %ws_row($AC, $AE, $B4, $B6, $C4, $C6, $CA, $A0, $3800, $A4, $C800, $D100, 1, 1)
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
    JSR ws_reach_load
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

; player-follow on small maps: glide back to centre instead of scrolling
ws_follow:
    PHP
    JSR ws_is_small
    BCS .done
    REP #$20
    LDA $C0
    SEC
    SBC #$0100
    CMP #$8000
    ROR
    BPL +
    CLC
    ADC $C0
+
    SEC
    SBC $A8
    PHA
    LDA $C0
    LSR
    PHA
    LDA 3,S
    BMI .neg
    CMP 1,S
    BCC .wrapped
    SEC
    SBC $C0
    BRA .wrapped
.neg:
    CLC
    ADC 1,S
    BPL .negok
    LDA 3,S
    CLC
    ADC $C0
    BRA .wrapped
.negok:
    LDA 3,S
.wrapped:
    STA 3,S
    PLA
    PLA
    CMP #$0000
    BEQ .zero
    BMI .left
    CMP #$0002
    BCC +
    LDA #$0002
+
    SEP #$20
    STA $84
    BRA .done
.left:
    EOR #$FFFF
    INC
    CMP #$0002
    BCC +
    LDA #$0002
+
    SEP #$20
    ORA #$80
    STA $84
    BRA .done
.zero:
    SEP #$20
    STZ $84
.done:
    PLP
    RTL

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

!LASTX = $1DC0              ; last drawn x per object slot (16 words)
!PO = $1DB0
!PX = $1DB2
!PD = $1DB4
!PB = $1DB6
; A16, A = x, Y = slot*2: x, x+W or x-W nearest the slot's last x (else ws_norm_x)
ws_pick_x:
    STA !PO
    STA !PB
    STA !PX
    JSR .dist
    STA !PD
    LDA !PO
    CLC
    ADC $C0
    STA !PX
    JSR .try
    LDA !PO
    SEC
    SBC $C0
    STA !PX
    JSR .try
    LDA !PD
    CMP #$0040
    BCS .far
    LDA !PB
    RTS
.far:
    LDA !PO
    JMP ws_norm_x
.try:
    JSR .dist
    CMP !PD
    BCS +
    STA !PD
    LDA !PX
    STA !PB
+
    RTS
.dist:
    LDA !PX
    SEC
    SBC !LASTX,Y
    BPL +
    EOR #$FFFF
    INC
+
    RTS

ws_draw_piece:
    SEP #$20
    LDA $C1
    CMP #$02
    BCS .done
    REP #$30
    PHY
    LDA $14
    XBA
    AND #$001E
    TAY
    LDA $04
    JSR ws_pick_x
    STA $04
    STA !LASTX,Y
    PLY
    SEP #$20
.done:
    LDY $7C
    RTL

ws_draw_shadow:
    LDA $C0
    CMP #$0200
    LDA $E020,X
    BCS .big
    PHY
    PHA
    TXA
    XBA
    AND #$001E
    TAY
    PLA
    JSR ws_pick_x
    PLY
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

; intro log scene (map $100): BG3 HOFS +$100 on the log band only
!LOGTAB = $1DE0
ws_hdma_en:
    SEP #$20
    LDA $2C
    PHA
    LDA $DD
    CMP #$01
    BNE .off
    LDA $DC
    BNE .off
    LDA 1,S
    AND #$08
    BEQ .off
    PHX
    PHP
    REP #$10
    LDX #$0000
    LDY #$0000
.build:
    LDA $7EEF00,X
    BEQ .end
    AND #$7F
    STA !LOGTAB,Y
    LDA $7EEF01,X
    CMP #$82
    LDA #$00
    STA !LOGTAB+1,Y
    BCC +
    INC
+
    STA !LOGTAB+2,Y
    INX
    INX
    INX
    INY
    INY
    INY
    CPY #$0018
    BCC .build
.end:
    LDA #$00
    STA !LOGTAB,Y
    LDA #$02
    STA $4360
    LDA #$11
    STA $4361
    LDA.b #!LOGTAB
    STA $4362
    LDA.b #!LOGTAB>>8
    STA $4363
    LDA #$7E
    STA $4364
    PLP
    PLX
    PLA
    ORA #$40
    RTL
.off:
    PLA
    RTL

; --- reach tables: per row first/last column the original camera could show ---
; C set if BG2 shares BG1's camera and map size
ws_reach_on2:
    LDA.l !BG2OFF
    BNE ws_reach_no
    LDA $AC
    CMP $A8
    BNE ws_reach_no
    LDA $AE
    CMP $AA
    BNE ws_reach_no
    LDA $C4
    CMP $C0
    BNE ws_reach_no
    LDA $C6
    CMP $C2
    BNE ws_reach_no
    LDA.l $7E0000+!RTAB
    BEQ ws_reach_no
    LDA #$0001
    STA.l !BG2USED
; C set if this map has a reach table
ws_reach_on:
    LDA.l $7E0000+!RTAB
    BEQ ws_reach_no
    LDA $C0
    LSR
    LSR
    LSR
    LSR
    STA.l !RWM
    LDA $C2
    LSR
    LSR
    LSR
    LSR
    STA.l !RHM
    SEC
    RTS
ws_reach_no:
    CLC
    RTS

; A = column (map tiles, may be off-map), row in !RROW; returns column to draw, NZ from A
ws_reach_col:
    PHX
    PHA
    LDA.l !RROW
    ASL
    CLC
    ADC.l $7E0000+!RTAB
    TAX
    LDA.l $E00000,X
    CMP #$FFFF
    BEQ .in
    PHA
    AND #$00FF
    SEC
    SBC #$0010
    BPL +
    LDA #$0000
+
    STA.l !RLO
    PLA
    XBA
    AND #$00FF
    SEC
    SBC #$0010
    CMP.l !RWM
    BCC +
    LDA.l !RWM
    DEC
+
    STA.l !RHI
    LDA 1,S
    BMI .left
    CMP.l !RLO
    BCC .left
    CMP.l !RHI
    BEQ .in
    BCS .right
.in:
    PLA
    PLX
    ORA #$0000
    RTS
.left:
    LDA.l !RLO
    SEC
    SBC 1,S
    AND #$0001
    CLC
    ADC.l !RLO
    BRA .done
.right:
    LDA 1,S
    SEC
    SBC.l !RHI
    AND #$0001
    EOR #$FFFF
    SEC
    ADC.l !RHI
.done:
    STA 1,S
    PLA
    PLX
    ORA #$0000
    RTS

ws_reach_load:
    PHP
    REP #$30
    LDA $DC
    AND #$01FF
    ASL
    TAX
    LDA.l $E00000,X
    STA.l $7E0000+!RTAB
    LDA #$0000
    STA.l !FIXN
    STA.l !BG2USED
    STA.l !BG2OFF
    DEC
    STA.l !LASTC
    PLP
    RTS

; camera past the reach table: drop the mask and rebuild the side strips
ws_colhook:
    LDA $2F
    BEQ +
    PHP
    REP #$30
    JSR ws_trip
    PLP
    LDA $2F
    RTL
+
    PHB
    PHP
    LDA #$7F
    PHA
    PLB
    REP #$30
    LDA.l !FIXN
    BEQ .check
.dofix:
    DEC
    STA.l !FIXN
    ASL
    CLC
    ADC.l !FIXSIDE
    TAX
    LDA.l ws_fixofs,X
    PHA
    LDA.l !FIXCAM
    SEC
    SBC $A8
    LDX $C0
    JSR ws_wrapd
    CLC
    ADC 1,S
    STA $00
    CLC
    ADC #$0050
    CMP #$01A1
    BCS .nobg1
    LDA.l !FIXBG2
    LSR
    BCC .nobg1
    JSL ws_col_bg1
    LDA #$80
    TSB $2F
    REP #$30
.nobg1:
    LDA.l !FIXCAM2
    SEC
    SBC $AC
    LDX $C4
    JSR ws_wrapd
    CLC
    ADC 1,S
    STA $00
    PLA
    LDA $00
    CLC
    ADC #$0050
    CMP #$01A1
    BCS .out
    LDA.l !FIXBG2
    AND #$0002
    BEQ .out
    JSL ws_col_bg2
    LDA #$40
    TSB $2F
    BRA .out
.check:
    JSR ws_trip
    LDA.l !FIXN
    BNE .dofix
.out:
    PLP
    PLB
    LDA #$FF
    RTL

; rebuild order, nearest the trip side first (read backwards)
ws_fixofs:
    dw $FFB0, $FFC0, $FFD0, $FFE0, $FFF0, $0000, $0150, $0140, $0130, $0120, $0110, $0100, $00F0
    dw $0150, $0140, $0130, $0120, $0110, $0100, $00F0, $FFB0, $FFC0, $FFD0, $FFE0, $FFF0, $0000

; A = camera delta, X = map width; wrap into -W/2..W/2
ws_wrapd:
    STX $02
    PHA
    LDA $02
    LSR
    STA $02
    PLA
    BMI .neg
    CMP $02
    BCC .done
    SEC
    SBC $02
    SEC
    SBC $02
    RTS
.neg:
    EOR #$FFFF
    INC
    CMP $02
    BCC .negok
    EOR #$FFFF
    INC
    CLC
    ADC $02
    ADC $02
    RTS
.negok:
    EOR #$FFFF
    INC
.done:
    RTS

ws_fixcam:
    LDA $A8
    STA.l !FIXCAM
    LDA $AC
    STA.l !FIXCAM2
    RTS

; A16 X16
ws_trip:
    LDA.l $7E0000+!RTAB
    BNE +
    RTS
+
    LDA.l !BG2USED
    BEQ .bg2ok
    LDA.l !BG2OFF
    BNE .bg2ok
    LDA $AC
    CMP $A8
    BNE .bg2trip
    LDA $AE
    CMP $AA
    BEQ .bg2ok
.bg2trip:
    JSR ws_fixcam
    LDA #$0001
    STA.l !BG2OFF
    LDA #$0002
    STA.l !FIXBG2
    LDA #$0000
    STA.l !FIXSIDE
    LDA #$000D
    STA.l !FIXN
    RTS
.bg2ok:
    LDA $AA
    AND #$0FF0
    ASL
    ASL
    ASL
    ASL
    STA $04
    LDA $A8
    LSR
    LSR
    LSR
    LSR
    STA $06
    ORA $04
    CMP.l !LASTC
    BNE +
    RTS
+
    STA.l !LASTC
    LDA $C0
    SEC
    SBC #$0080
    CMP $A8
    LDA $A8
    BCS +
    SEC
    SBC $C0
+
    CLC
    ADC #$0100
    PHA
    LSR
    LSR
    LSR
    LSR
    STA $06
    PLA
    CLC
    ADC #$00FF
    LSR
    LSR
    LSR
    LSR
    STA $08
    LDA $C0
    LSR
    LSR
    LSR
    LSR
    CLC
    ADC #$000F
    STA $0A
    LDA $C2
    LSR
    LSR
    LSR
    LSR
    STA $0C
    LDA $AA
    LSR
    LSR
    LSR
    LSR
    STA $04
    LDA #$000F
    STA $0E
.row:
    LDA $04
    ASL
    CLC
    ADC.l $7E0000+!RTAB
    TAX
    LDA.l $E00000,X
    AND #$00FF
    CMP #$00FF
    BEQ .next
    CMP #$0010
    BCS +
    LDA #$0010
+
    DEC
    CMP $06
    BCS .tripl
    LDA.l $E00001,X
    AND #$00FF
    CMP $0A
    BCC +
    LDA $0A
+
    INC
    CMP $08
    BCC .tripr
    BEQ .tripr
.next:
    LDA $04
    INC
    CMP $0C
    BCC +
    LDA #$0000
+
    STA $04
    DEC $0E
    BNE .row
    RTS
.tripl:
    LDA #$001A
    BRA .trip
.tripr:
    LDA #$0000
.trip:
    STA.l !FIXSIDE
    JSR ws_fixcam
    LDA.l !FIXN
    BEQ +
    LDA.l !FIXBG2
+
    ORA #$0001
    STA $0E
    LDA #$000D
    STA.l !FIXN
    LDA.l !BG2OFF
    BNE +
    LDA.l !BG2USED
    BEQ +
    LDA #$0002
    TSB $0E
+
    LDA $0E
    STA.l !FIXBG2
    LDA #$0000
    STA.l $7E0000+!RTAB
    RTS

ws_piece_skip:
    SEP #$20
    CPY #$0200
    BCS +
    LDA #$E0
    STA $0801,Y
+
    DEC $02
    RTL

ws_end:
assert ws_end <= $C75000, "C7 free space overflow"
