.pc = $801 "Basic"
:BasicUpstart(__bbegin)
.pc = $80d "Program"
  // The colors of the C64
  .const BLACK = 0
  .const WHITE = 1
  .const RED = 2
  .const CYAN = 3
  .const PURPLE = 4
  .const GREEN = 5
  .const BLUE = 6
  .const LIGHT_BLUE = $e
  .const KEY_W = 9
  .const KEY_A = $a
  .const KEY_D = $12
  .const KEY_I = $21
  .const KEY_J = $22
  .const KEY_L = $2a
  .const OFFSET_STRUCT_PRINTF_BUFFER_NUMBER_DIGITS = 1
  .const OFFSET_STRUCT_MOS6526_CIA_PORT_A_DDR = 2
  .const OFFSET_STRUCT_MOS6526_CIA_PORT_B_DDR = 3
  .const OFFSET_STRUCT_MOS6526_CIA_PORT_B = 1
  .const OFFSET_STRUCT_MOS6569_VICII_MEMORY = $18
  .const OFFSET_STRUCT_MOS6569_VICII_CONTROL2 = $16
  .const OFFSET_STRUCT_MOS6569_VICII_BG_COLOR1 = $22
  .const OFFSET_STRUCT_MOS6569_VICII_BG_COLOR2 = $23
  // delete flags for state machine
  .const baseTickDelay = $10
  .const SIZEOF_STRUCT_PRINTF_BUFFER_NUMBER = $c
  // The VIC-II MOS 6567/6569
  .label VICII = $d000
  // Color Ram
  .label COLORRAM = $d800
  // Default address of screen character matrix
  .label DEFAULT_SCREEN = $400
  // The CIA#1: keyboard matrix, joystick #1/#2
  .label CIA1 = $dc00
  // The vector used when the KERNAL serves IRQ interrupts
  .label KERNEL_IRQ = $314
  .label conio_cursor_x = $a
  .label conio_cursor_y = $b
  .label conio_line_text = $c
  .label conio_line_color = $e
  .label conio_textcolor = $10
  .label ticks = $11
  // The random state variable
  .label rand_state = $15
  // The random state variable
  .label rand_state_1 = $17
  // screen row LUT
  .label maxTicks = 3
  .label lastKeyPressed = 9
  // The random state variable
  .label rand_state_2 = 4
__bbegin:
  // The number of bytes on the screen
  // The current cursor x-position
  lda #0
  sta.z conio_cursor_x
  // The current cursor y-position
  sta.z conio_cursor_y
  // The current text cursor line start
  lda #<DEFAULT_SCREEN
  sta.z conio_line_text
  lda #>DEFAULT_SCREEN
  sta.z conio_line_text+1
  // The current color cursor line start
  lda #<COLORRAM
  sta.z conio_line_color
  lda #>COLORRAM
  sta.z conio_line_color+1
  // The current text color
  lda #LIGHT_BLUE
  sta.z conio_textcolor
  // fix for vscode syntax checking: define unknown types
  lda #0
  sta.z ticks
  jsr main
  rts
main: {
    lda #BLUE
    jsr textcolor
    jsr loadCharset
    sei
    lda #<irqService
    sta KERNEL_IRQ
    lda #>irqService
    sta KERNEL_IRQ+1
    cli
    jsr clrscr
    jsr setupLUTs
    jsr bgcolor
    lda #BLACK
    jsr bordercolor
    lda #GREEN
    jsr textcolor
    jsr setVIC3Mode
    jsr keyboard_init
    jsr test
    rts
}
test: {
    .label i = 4
    .label __5 = $12
    lda #0
    sta currentPlayerState
    sta currentPlayerState+1
    jsr drawWell
    lda #<0
    sta.z i
    sta.z i+1
  // empty canvas
  __b1:
    lda.z i+1
    cmp #>$c*6*2
    bcc __b2
    bne !+
    lda.z i
    cmp #<$c*6*2
    bcc __b2
  !:
    lda #<1
    sta.z rand_state_2
    lda #>1
    sta.z rand_state_2+1
    sta.z maxTicks
    sta.z lastKeyPressed
  __b4:
    lda #0
    sta.z doPlayerTick.player
    jsr doPlayerTick
    lda #1
    sta.z doPlayerTick.player
    jsr doPlayerTick
    jmp __b4
  __b2:
    lda.z i
    clc
    adc #<canvas
    sta.z __5
    lda.z i+1
    adc #>canvas
    sta.z __5+1
    lda #0
    tay
    sta (__5),y
    inc.z i
    bne !+
    inc.z i+1
  !:
    jmp __b1
}
// main game logic implemented as state machine
// (see kp_state defines for possible states)
// doPlayerTick(byte zp(2) player)
doPlayerTick: {
    .label addNewPlayerTile1___0 = $21
    .label addNewPlayerTile1___3 = $2b
    .label addNewPlayerTile1___5 = $27
    .label addNewPlayerTile1___9 = $27
    .label addNewPlayerTile1___13 = $27
    .label addNewPlayerTile1___16 = $21
    .label addNewPlayerTile1___17 = $23
    .label addNewPlayerTile1_tile2 = $14
    .label offset = $2b
    .label player = 2
    .label __32 = $21
    .label __33 = $2b
    jsr scanKeyboard
    lda.z ticks
    ldy.z player
    sec
    sbc playerStartTick,y
    ldy.z maxTicks
    sta.z $ff
    cpy.z $ff
    bcs __b1
    sta.z maxTicks
    lda #0
    jsr gotoxy
    lda #<s
    sta.z cputs.s
    lda #>s
    sta.z cputs.s+1
    jsr cputs
    ldx.z maxTicks
    jsr printf_uchar
    lda #<s1
    sta.z cputs.s
    lda #>s1
    sta.z cputs.s+1
    jsr cputs
  __b1:
    lda #8
    and.z ticks
    cmp #0
    beq __b2
    lda.z player
    sta.z handleCommandForPlayer.player
    jsr handleCommandForPlayer
    cmp #0
    bne __b7
    jmp __b2
  __b7:
    lda.z player
    sta.z refreshScreen.player
    jsr refreshScreen
  __b2:
    lda.z ticks
    ldy.z player
    sec
    sbc playerStartTick,y
    cmp #baseTickDelay
    bcs __b3
    rts
  __b3:
    lda #1
    cmp.z player
    bne __b5
    lda #<$c*6
    sta.z offset
    lda #>$c*6
    sta.z offset+1
    jmp __b4
  __b5:
    lda #<0
    sta.z offset
    sta.z offset+1
  __b4:
    lda.z ticks
    ldy.z player
    sta playerStartTick,y
  //;currentTick;
    lda #$23
    jsr gotoxy
    lda #'0'
    ldy.z player
    clc
    adc currentPlayerState,y
    jsr cputc
    ldy.z player
    lda currentPlayerState,y
    cmp #0
    bne !addNewPlayerTile1+
    jmp addNewPlayerTile1
  !addNewPlayerTile1:
    lda currentPlayerState,y
    cmp #1
    bne !__b13+
    jmp __b13
  !__b13:
    lda currentPlayerState,y
    cmp #2
    beq __b14
    lda currentPlayerState,y
    cmp #3
    beq __b15
    lda currentPlayerState,y
    cmp #4
    beq __b16
  __b17:
    lda.z player
    sta.z refreshScreen.player
    jsr refreshScreen
    lda #0
    ldy.z player
    sta currentCommand,y
    rts
  __b16:
    lda.z player
    sta.z fallDownStep.player
    jsr fallDownStep
    lda.z fallDownStep.moved
    cmp #0
    bne __b17
    lda #2
    ldy.z player
    sta currentPlayerState,y
    jmp __b17
  __b15:
    lda.z player
    sta.z markForDeletion.player
    lda #1
    sta.z markForDeletion.part
    jsr markForDeletion
    lda.z markForDeletion.hasDeleted
    ldy.z player
    ora hasDeleted,y
    sta hasDeleted,y
    lda #0
    cmp hasDeleted,y
    bne __b18
    sta currentPlayerState,y
    jmp __b17
  __b18:
    lda #4
    ldy.z player
    sta currentPlayerState,y
    jmp __b17
  __b14:
    lda.z player
    sta.z markForDeletion.player
    lda #0
    sta.z markForDeletion.part
    jsr markForDeletion
    lda.z markForDeletion.hasDeleted
    ldy.z player
    sta hasDeleted,y
    lda #3
    sta currentPlayerState,y
    jmp __b17
  __b13:
    lda.z player
    sta.z handleCommandForPlayer.player
    jsr handleCommandForPlayer
    lda.z player
    sta.z fallDownStep.player
    jsr fallDownStep
    lda.z fallDownStep.moved
    cmp #0
    bne __b17
    lda #2
    ldy.z player
    sta currentPlayerState,y
    jmp __b17
  addNewPlayerTile1:
    jsr rand
    lda #3
    and.z addNewPlayerTile1___5
    clc
    adc #1
    sta.z addNewPlayerTile1_tile2
    cmp #3+1
    bcs addNewPlayerTile1
  addNewPlayerTile1___b3:
    jsr rand
    lda #3
    and.z addNewPlayerTile1___9
    clc
    adc #1
    tay
    cpy #3+1
    bcs addNewPlayerTile1___b3
  addNewPlayerTile1___b5:
    jsr rand
    lda #7
    and.z addNewPlayerTile1___13
    tax
    cpx #6-2+1
    bcs addNewPlayerTile1___b5
    txa
    sta.z addNewPlayerTile1___16
    lda #0
    sta.z addNewPlayerTile1___16+1
    lda.z addNewPlayerTile1___0
    clc
    adc.z offset
    sta.z addNewPlayerTile1___0
    lda.z addNewPlayerTile1___0+1
    adc.z offset+1
    sta.z addNewPlayerTile1___0+1
    tya
    ora #$20
    tay
    clc
    lda.z __32
    adc #<canvas
    sta.z __32
    lda.z __32+1
    adc #>canvas
    sta.z __32+1
    tya
    ldy #0
    sta (__32),y
    txa
    sta.z addNewPlayerTile1___17
    tya
    sta.z addNewPlayerTile1___17+1
    lda.z addNewPlayerTile1___3
    clc
    adc.z addNewPlayerTile1___17
    sta.z addNewPlayerTile1___3
    lda.z addNewPlayerTile1___3+1
    adc.z addNewPlayerTile1___17+1
    sta.z addNewPlayerTile1___3+1
    lda #$20
    ora.z addNewPlayerTile1_tile2
    tax
    clc
    lda.z __33
    adc #<canvas+1
    sta.z __33
    lda.z __33+1
    adc #>canvas+1
    sta.z __33+1
    txa
    sta (__33),y
    lda #1
    ldy.z player
    sta currentPlayerState,y
    jmp __b17
    s: .text "mt: "
    .byte 0
    s1: .text "   "
    .byte 0
}
// Returns a pseudo-random number in the range of 0 to RAND_MAX (65535)
// Uses an xorshift pseudorandom number generator that hits all different values
// Information https://en.wikipedia.org/wiki/Xorshift
// Source http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html
rand: {
    .label __0 = $15
    .label __1 = $17
    .label __2 = $21
    .label return = $27
    lda.z rand_state_2+1
    lsr
    lda.z rand_state_2
    ror
    sta.z __0+1
    lda #0
    ror
    sta.z __0
    lda.z rand_state
    eor.z rand_state_2
    sta.z rand_state
    lda.z rand_state+1
    eor.z rand_state_2+1
    sta.z rand_state+1
    lsr
    sta.z __1
    lda #0
    sta.z __1+1
    lda.z rand_state_1
    eor.z rand_state
    sta.z rand_state_1
    lda.z rand_state_1+1
    eor.z rand_state+1
    sta.z rand_state_1+1
    lda.z rand_state_1
    sta.z __2+1
    lda #0
    sta.z __2
    lda.z rand_state_1
    eor.z __2
    sta.z rand_state_2
    lda.z rand_state_1+1
    eor.z __2+1
    sta.z rand_state_2+1
    lda.z rand_state_2
    sta.z return
    lda.z rand_state_2+1
    sta.z return+1
    rts
}
// fallDownStep(byte zp($a) player)
fallDownStep: {
    .label puyoAtPosition1_return = $e
    .label elem = $e
    .label puyoAtPosition2_return = $17
    .label y = 7
    .label x = 8
    .label puyoAtPosition3_return = $21
    .label player = $a
    .label moved = 6
    lda #0
    sta.z moved
    lda #$c-1
    sta.z y
  __b1:
    lda.z y
    cmp #0
    bne __b3
    rts
  __b3:
    lda #0
    sta.z x
  __b2:
    lda.z x
    cmp #6
    bcc puyoAtPosition1
    dec.z y
    jmp __b1
  puyoAtPosition1:
    lda #0
    cmp.z player
    bne !puyoAtPosition1___b1+
    jmp puyoAtPosition1___b1
  !puyoAtPosition1___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  __b12:
    ldx.z y
    dex
    lda #0
    cmp.z player
    bne !puyoAtPosition2___b1+
    jmp puyoAtPosition2___b1
  !puyoAtPosition2___b1:
    lda canvasLutY,x
    clc
    adc.z x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition2_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition2_return+1
  __b13:
    ldy #0
    lda (elem),y
    cmp #0
    bne __b4
    lda (puyoAtPosition2_return),y
    cmp #0
    beq __b4
    lda (puyoAtPosition2_return),y
    sta (elem),y
    tya
    sta (puyoAtPosition2_return),y
    lda #1
    sta.z moved
  __b4:
    lda #$20
    ldy #0
    and (elem),y
    cmp #0
    beq __b5
    // landing on bottom
    lda #$c-1
    cmp.z y
    beq __b6
    ldx.z y
    inx
    tya
    cmp.z player
    beq puyoAtPosition3___b1
    lda canvasLutY,x
    clc
    adc.z x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition3_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition3_return+1
  __b14:
    lda #0
    tay
    cmp (puyoAtPosition3_return),y
    beq __b5
    lda #$20
    and (puyoAtPosition3_return),y
    cmp #0
    bne __b5
    lda #7
    and (elem),y
    sta (elem),y
  __b5:
    inc.z x
    jmp __b2
  puyoAtPosition3___b1:
    lda canvasLutY,x
    clc
    adc.z x
    clc
    adc #<canvas
    sta.z puyoAtPosition3_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition3_return+1
    jmp __b14
  __b6:
    lda #7
    ldy #0
    and (elem),y
    sta (elem),y
    jmp __b5
  puyoAtPosition2___b1:
    lda canvasLutY,x
    clc
    adc.z x
    clc
    adc #<canvas
    sta.z puyoAtPosition2_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition2_return+1
    jmp __b13
  puyoAtPosition1___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp __b12
}
// handleCommandForPlayer(byte zp($a) player)
handleCommandForPlayer: {
    .label y = $20
    .label y_1 = 7
    .label y_2 = $1a
    .label player = $a
    // would have solved this with ?: notation, but
    // kickc crashes with 'dk.camelot64.kickc.model.InternalError: Error! Number integer type not
    // resolved to fixed size integer type'
    .label tileListOffset = 7
    lda #0
    ldy.z player
    cmp currentCommand,y
    bne __b1
    rts
  __b5:
    lda #0
    rts
  __b1:
    lda #1
    cmp.z player
    bne __b6
    lda #4
    sta.z tileListOffset
    jmp __b2
  __b6:
    lda #0
    sta.z tileListOffset
  __b2:
    lda #3
    ldy.z player
    cmp currentCommand,y
    bne __b3
    ldx.z tileListOffset
    jsr rotateTile
    lda #1
    rts
  __b3:
    lda #2
    ldy.z player
    cmp currentCommand,y
    bne __b4
    // second tile...
    ldy.z tileListOffset
    ldx playerTileList+2,y
    // get pos of second tile
    lda playerTileList+3,y
    sta.z y
    lda.z player
    sta.z movePlayerPuyoRight.player
    stx.z movePlayerPuyoRight.x
    ldx.z y
    jsr movePlayerPuyoRight
    // first tile
    ldy.z tileListOffset
    ldx playerTileList,y
    // get pos of first tile
    ldy.z y_1
    lda playerTileList+1,y
    sta.z y_1
    lda.z player
    sta.z movePlayerPuyoRight.player
    stx.z movePlayerPuyoRight.x
    ldx.z y_1
    jsr movePlayerPuyoRight
    lda #1
    rts
  __b4:
    lda #1
    ldy.z player
    cmp currentCommand,y
    bne __b5
    // first tile...
    ldy.z tileListOffset
    ldx playerTileList,y
    // get pos of first tile
    lda playerTileList+1,y
    sta.z y_2
    lda.z player
    sta.z movePlayerPuyoLeft.player
    txa
    tay
    ldx.z y_2
    jsr movePlayerPuyoLeft
    // second tile
    ldy.z tileListOffset
    ldx playerTileList+2,y
    // get pos of second tile
    ldy.z y_1
    lda playerTileList+3,y
    sta.z y_1
    lda.z player
    sta.z movePlayerPuyoLeft.player
    txa
    tay
    ldx.z y_1
    jsr movePlayerPuyoLeft
    lda #1
    rts
}
// movePlayerPuyoLeft(byte zp(6) player, byte register(Y) x, byte register(X) y)
movePlayerPuyoLeft: {
    .label puyoAtPosition1_return = $e
    .label srcPuyo = $e
    .label puyoAtPosition2_x = $19
    .label puyoAtPosition2_return = $17
    .label player = 6
    cpy #$ff
    bne __b1
  __breturn:
    rts
  __b1:
    cpy #0
    beq __breturn
    tya
    sec
    sbc #1
    sta.z puyoAtPosition2_x
    lda #0
    cmp.z player
    beq puyoAtPosition1___b1
    tya
    clc
    adc canvasLutY,x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  puyoAtPosition2:
    lda #0
    cmp.z player
    beq puyoAtPosition2___b1
    lda canvasLutY,x
    clc
    adc.z puyoAtPosition2_x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition2_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition2_return+1
  __b4:
    ldy #0
    lda (puyoAtPosition2_return),y
    cmp #0
    bne __breturn
    lda (srcPuyo),y
    sta (puyoAtPosition2_return),y
    tya
    sta (srcPuyo),y
    rts
  puyoAtPosition2___b1:
    lda canvasLutY,x
    clc
    adc.z puyoAtPosition2_x
    clc
    adc #<canvas
    sta.z puyoAtPosition2_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition2_return+1
    jmp __b4
  puyoAtPosition1___b1:
    tya
    clc
    adc canvasLutY,x
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp puyoAtPosition2
}
// movePlayerPuyoRight(byte zp(6) player, byte zp(8) x, byte register(X) y)
movePlayerPuyoRight: {
    .label puyoAtPosition1_x = 8
    .label puyoAtPosition1_return = $21
    .label srcPuyo = $21
    .label puyoAtPosition2_return = $e
    .label player = 6
    .label x = 8
    lda #$ff
    cmp.z puyoAtPosition1_x
    bne __b1
  __breturn:
    rts
  __b1:
    lda.z puyoAtPosition1_x
    cmp #6-1
    bcs __breturn
    tay
    iny
    lda #0
    cmp.z player
    beq puyoAtPosition1___b1
    lda canvasLutY,x
    clc
    adc.z puyoAtPosition1_x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  puyoAtPosition2:
    lda #0
    cmp.z player
    beq puyoAtPosition2___b1
    tya
    clc
    adc canvasLutY,x
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition2_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition2_return+1
  __b4:
    ldy #0
    lda (puyoAtPosition2_return),y
    cmp #0
    bne __breturn
    lda (srcPuyo),y
    sta (puyoAtPosition2_return),y
    tya
    sta (srcPuyo),y
    rts
  puyoAtPosition2___b1:
    tya
    clc
    adc canvasLutY,x
    clc
    adc #<canvas
    sta.z puyoAtPosition2_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition2_return+1
    jmp __b4
  puyoAtPosition1___b1:
    lda canvasLutY,x
    clc
    adc.z puyoAtPosition1_x
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp puyoAtPosition2
}
// rotateTile(byte zp($a) player, byte register(X) tileListOffset)
rotateTile: {
    .label xOld1 = $1c
    .label yOld1 = $1f
    .label yNew0 = $1b
    .label xNew1 = $19
    .label puyoAtPosition1_return = $e
    .label temp1 = $1d
    .label puyoAtPosition2_return = $17
    .label temp2 = $1e
    .label puyoAtPosition3_return = $21
    .label puyoAtPosition4_return = $23
    .label puyoAtPosition5_return = $2b
    .label puyoAtPosition6_return = $25
    .label srcPuyo = $25
    .label puyoAtPosition7_return = $c
    .label player = $a
    lda #RED
    jsr bordercolor
    lda playerTileList,x
    sta.z xNew1
    lda playerTileList+1,x
    sta.z yNew0
    lda playerTileList+2,x
    sta.z xOld1
    lda playerTileList+3,x
    sta.z yOld1
    ldx.z xNew1
    inx
    // horizontal tile
    cpx.z xOld1
    bne !__b1+
    jmp __b1
  !__b1:
    ldx.z yNew0
    inx
    cpx.z yOld1
    beq !__breturn+
    jmp __breturn
  !__breturn:
    ldx.z xNew1
    inx
    cpx #6
    bcc !__breturn+
    jmp __breturn
  !__breturn:
    lda #0
    cmp.z player
    bne !puyoAtPosition1___b1+
    jmp puyoAtPosition1___b1
  !puyoAtPosition1___b1:
    lda.z xNew1
    ldy.z yNew0
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  __b5:
    ldy #0
    lda (puyoAtPosition1_return),y
    sta.z temp1
    tya
    cmp.z player
    bne !puyoAtPosition2___b1+
    jmp puyoAtPosition2___b1
  !puyoAtPosition2___b1:
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition2_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition2_return+1
  __b6:
    ldy #0
    lda (puyoAtPosition2_return),y
    sta.z temp2
    tya
    cmp.z player
    beq puyoAtPosition3___b1
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition3_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition3_return+1
  __b7:
    lda #0
    tay
    sta (puyoAtPosition3_return),y
    cmp.z player
    beq puyoAtPosition4___b1
    ldy.z yNew0
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition4_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition4_return+1
  __b8:
    lda.z temp1
    ldy #0
    sta (puyoAtPosition4_return),y
    tya
    cmp.z player
    beq puyoAtPosition5___b1
    lda.z xNew1
    ldy.z yNew0
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition5_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition5_return+1
  __b9:
    lda.z temp2
    ldy #0
    sta (puyoAtPosition5_return),y
  __breturn:
    rts
  puyoAtPosition5___b1:
    lda.z xNew1
    ldy.z yNew0
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition5_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition5_return+1
    jmp __b9
  puyoAtPosition4___b1:
    ldy.z yNew0
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition4_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition4_return+1
    jmp __b8
  puyoAtPosition3___b1:
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition3_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition3_return+1
    jmp __b7
  puyoAtPosition2___b1:
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition2_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition2_return+1
    jmp __b6
  puyoAtPosition1___b1:
    lda.z xNew1
    ldy.z yNew0
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp __b5
  __b1:
    ldx.z yNew0
    inx
    cpx #$c-1
    bcs __breturn
    lda #0
    cmp.z player
    beq puyoAtPosition6___b1
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition6_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition6_return+1
  puyoAtPosition7:
    lda #0
    cmp.z player
    beq puyoAtPosition7___b1
    lda canvasLutY,x
    clc
    adc.z xNew1
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition7_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition7_return+1
  __b10:
    ldy #0
    lda (puyoAtPosition7_return),y
    cmp #0
    beq !__breturn+
    jmp __breturn
  !__breturn:
    lda (srcPuyo),y
    sta (puyoAtPosition7_return),y
    tya
    sta (srcPuyo),y
    rts
  puyoAtPosition7___b1:
    lda canvasLutY,x
    clc
    adc.z xNew1
    clc
    adc #<canvas
    sta.z puyoAtPosition7_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition7_return+1
    jmp __b10
  puyoAtPosition6___b1:
    lda.z xOld1
    ldy.z yOld1
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition6_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition6_return+1
    jmp puyoAtPosition7
}
// Set the color for the border. The old color setting is returned.
// bordercolor(byte register(A) color)
bordercolor: {
    // The border color register address
    .label CONIO_BORDERCOLOR = $d020
    sta CONIO_BORDERCOLOR
    rts
}
/* 
find puyos to delete
at least for c64 class machines, we have to do this
in two parts, because otherwise the analysis phase
would lock up the machine too long 
*/
// markForDeletion(byte zp(6) player, byte zp(7) part)
markForDeletion: {
    .label y = $19
    .label checkNeighbors1_puyoAtPosition1_return = $17
    .label checkNeighbors1_thisPuyoID = $1a
    .label checkNeighbors1_deleteListOffset = $1b
    .label checkNeighbors1_puyoAtPosition2_return = $21
    .label checkNeighbors1_markedPuyoID = $1c
    .label checkNeighbors1_puyoAtPosition3_return = $23
    .label checkNeighbors1_return = $b
    .label checkNeighbors1_puyoAtPosition4_return = $2b
    .label checkNeighbors1_currentPuyo = $2b
    .label checkNeighbors1_x = $1f
    .label checkNeighbors1_y = $a
    .label checkNeighbors1_puyoAtPosition5_return = $25
    .label checkNeighbors1_puyoAtPosition6_return = $c
    .label checkNeighbors1_numHits = $b
    .label checkNeighbors1_puyoAtPosition7_return = $e
    .label checkNeighbors1_puyoAtPosition8_return = $12
    .label x = $1e
    .label player = 6
    .label part = 7
    .label endY = 8
    .label checkNeighbors1_found = $14
    .label hasDeleted = $1d
    lda.z player
    sta.z clearMarked.player
    jsr clearMarked
    lda.z part
    cmp #0
    beq __b1
    lda #$c
    sta.z endY
    lda #$c/2
    sta.z y
    jmp __b2
  __b1:
    lda #$c/2
    sta.z endY
    lda #0
    sta.z y
  __b2:
    lda #0
    sta.z hasDeleted
  __b3:
    lda.z y
    cmp.z endY
    bcc __b5
    rts
  __b5:
    lda #0
    sta.z x
  __b4:
    lda.z x
    cmp #6
    bcc checkNeighbors1
    inc.z y
    jmp __b3
  checkNeighbors1:
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition1___b1+
    jmp checkNeighbors1_puyoAtPosition1___b1
  !checkNeighbors1_puyoAtPosition1___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition1_return+1
  checkNeighbors1___b29:
    ldy #0
    lda (checkNeighbors1_puyoAtPosition1_return),y
    sta.z checkNeighbors1_thisPuyoID
    lda #$80
    and.z checkNeighbors1_thisPuyoID
    tax
    tya
    cmp.z checkNeighbors1_thisPuyoID
    beq __b7
    cpx #0
    bne __b7
    ldy.z player
    lda deleteListOffsetTbl,y
    sta.z checkNeighbors1_deleteListOffset
    tax
    inx
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition2___b1+
    jmp checkNeighbors1_puyoAtPosition2___b1
  !checkNeighbors1_puyoAtPosition2___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition2_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition2_return+1
  checkNeighbors1___b30:
    txa
    asl
    tay
    lda.z checkNeighbors1_puyoAtPosition2_return
    sta deleteList,y
    lda.z checkNeighbors1_puyoAtPosition2_return+1
    sta deleteList+1,y
    lda #$80
    ora.z checkNeighbors1_thisPuyoID
    sta.z checkNeighbors1_markedPuyoID
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition3___b1+
    jmp checkNeighbors1_puyoAtPosition3___b1
  !checkNeighbors1_puyoAtPosition3___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition3_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition3_return+1
  checkNeighbors1___b31:
    lda.z checkNeighbors1_markedPuyoID
    ldy #0
    sta (checkNeighbors1_puyoAtPosition3_return),y
    lda #1
    sta.z checkNeighbors1_numHits
  checkNeighbors1___b4:
    lda #0
    sta.z checkNeighbors1_found
    sta.z checkNeighbors1_x
  checkNeighbors1___b5:
    lda.z checkNeighbors1_x
    cmp #6
    bcc __b9
    lda #0
    cmp.z checkNeighbors1_found
    bne checkNeighbors1___b4
    jmp __b8
  __b7:
    lda #0
    sta.z checkNeighbors1_return
  __b8:
    lda.z checkNeighbors1_return
    cmp #3+1
    bcc __b6
    lda.z player
    sta.z deleteMarkedPuyos.player
    jsr deleteMarkedPuyos
    lda #1
    sta.z hasDeleted
  __b6:
    inc.z x
    jmp __b4
  __b9:
    lda #0
    sta.z checkNeighbors1_y
  checkNeighbors1___b8:
    lda.z checkNeighbors1_y
    cmp #$c
    bcc checkNeighbors1_puyoAtPosition4
    inc.z checkNeighbors1_x
    jmp checkNeighbors1___b5
  checkNeighbors1_puyoAtPosition4:
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition4___b1+
    jmp checkNeighbors1_puyoAtPosition4___b1
  !checkNeighbors1_puyoAtPosition4___b1:
    lda.z checkNeighbors1_x
    ldy.z checkNeighbors1_y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition4_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition4_return+1
  checkNeighbors1___b32:
    ldy #0
    lda (checkNeighbors1_currentPuyo),y
    cmp.z checkNeighbors1_thisPuyoID
    beq !__b13+
    jmp __b13
  !__b13:
    ldx.z checkNeighbors1_x
    inx
    tya
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition5___b1+
    jmp checkNeighbors1_puyoAtPosition5___b1
  !checkNeighbors1_puyoAtPosition5___b1:
    ldy.z checkNeighbors1_y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition5_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition5_return+1
  checkNeighbors1___b33:
    lda.z checkNeighbors1_x
    cmp #6-1
    bcs __b10
    ldy #0
    lda (checkNeighbors1_puyoAtPosition5_return),y
    cmp.z checkNeighbors1_markedPuyoID
    bne __b10
    lda #$80
    ora (checkNeighbors1_currentPuyo),y
    sta (checkNeighbors1_currentPuyo),y
    inc.z checkNeighbors1_numHits
    lda.z checkNeighbors1_deleteListOffset
    clc
    adc.z checkNeighbors1_numHits
    asl
    tay
    lda.z checkNeighbors1_currentPuyo
    sta deleteList,y
    lda.z checkNeighbors1_currentPuyo+1
    sta deleteList+1,y
    lda #1
    sta.z checkNeighbors1_found
  __b10:
    ldx.z checkNeighbors1_x
    dex
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition6___b1+
    jmp checkNeighbors1_puyoAtPosition6___b1
  !checkNeighbors1_puyoAtPosition6___b1:
    ldy.z checkNeighbors1_y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition6_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition6_return+1
  checkNeighbors1___b34:
    lda.z checkNeighbors1_x
    cmp #0
    beq __b11
    ldy #0
    lda (checkNeighbors1_puyoAtPosition6_return),y
    cmp.z checkNeighbors1_markedPuyoID
    bne __b11
    lda #$80
    ora (checkNeighbors1_currentPuyo),y
    sta (checkNeighbors1_currentPuyo),y
    inc.z checkNeighbors1_numHits
    lda.z checkNeighbors1_deleteListOffset
    clc
    adc.z checkNeighbors1_numHits
    asl
    tay
    lda.z checkNeighbors1_currentPuyo
    sta deleteList,y
    lda.z checkNeighbors1_currentPuyo+1
    sta deleteList+1,y
    lda #1
    sta.z checkNeighbors1_found
  __b11:
    ldx.z checkNeighbors1_y
    dex
    lda #0
    cmp.z player
    bne !checkNeighbors1_puyoAtPosition7___b1+
    jmp checkNeighbors1_puyoAtPosition7___b1
  !checkNeighbors1_puyoAtPosition7___b1:
    lda canvasLutY,x
    clc
    adc.z checkNeighbors1_x
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition7_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition7_return+1
  checkNeighbors1___b35:
    lda.z checkNeighbors1_y
    cmp #0
    beq __b12
    ldy #0
    lda (checkNeighbors1_puyoAtPosition7_return),y
    cmp.z checkNeighbors1_markedPuyoID
    bne __b12
    lda #$80
    ora (checkNeighbors1_currentPuyo),y
    sta (checkNeighbors1_currentPuyo),y
    inc.z checkNeighbors1_numHits
    lda.z checkNeighbors1_deleteListOffset
    clc
    adc.z checkNeighbors1_numHits
    asl
    tay
    lda.z checkNeighbors1_currentPuyo
    sta deleteList,y
    lda.z checkNeighbors1_currentPuyo+1
    sta deleteList+1,y
    lda #1
    sta.z checkNeighbors1_found
  __b12:
    ldx.z checkNeighbors1_y
    inx
    lda #0
    cmp.z player
    beq checkNeighbors1_puyoAtPosition8___b1
    lda canvasLutY,x
    clc
    adc.z checkNeighbors1_x
    clc
    adc #<canvas+$c*6
    sta.z checkNeighbors1_puyoAtPosition8_return
    lda #>canvas+$c*6
    adc #0
    sta.z checkNeighbors1_puyoAtPosition8_return+1
  checkNeighbors1___b36:
    lda.z checkNeighbors1_y
    cmp #$c-1
    bcs __b13
    ldy #0
    lda (checkNeighbors1_puyoAtPosition8_return),y
    cmp.z checkNeighbors1_markedPuyoID
    bne __b13
    lda #$80
    ora (checkNeighbors1_currentPuyo),y
    sta (checkNeighbors1_currentPuyo),y
    inc.z checkNeighbors1_numHits
    lda.z checkNeighbors1_deleteListOffset
    clc
    adc.z checkNeighbors1_numHits
    asl
    tay
    lda.z checkNeighbors1_currentPuyo
    sta deleteList,y
    lda.z checkNeighbors1_currentPuyo+1
    sta deleteList+1,y
    lda #1
    sta.z checkNeighbors1_found
  __b13:
    inc.z checkNeighbors1_y
    jmp checkNeighbors1___b8
  checkNeighbors1_puyoAtPosition8___b1:
    lda canvasLutY,x
    clc
    adc.z checkNeighbors1_x
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition8_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition8_return+1
    jmp checkNeighbors1___b36
  checkNeighbors1_puyoAtPosition7___b1:
    lda canvasLutY,x
    clc
    adc.z checkNeighbors1_x
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition7_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition7_return+1
    jmp checkNeighbors1___b35
  checkNeighbors1_puyoAtPosition6___b1:
    ldy.z checkNeighbors1_y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition6_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition6_return+1
    jmp checkNeighbors1___b34
  checkNeighbors1_puyoAtPosition5___b1:
    ldy.z checkNeighbors1_y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition5_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition5_return+1
    jmp checkNeighbors1___b33
  checkNeighbors1_puyoAtPosition4___b1:
    lda.z checkNeighbors1_x
    ldy.z checkNeighbors1_y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition4_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition4_return+1
    jmp checkNeighbors1___b32
  checkNeighbors1_puyoAtPosition3___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition3_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition3_return+1
    jmp checkNeighbors1___b31
  checkNeighbors1_puyoAtPosition2___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition2_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition2_return+1
    jmp checkNeighbors1___b30
  checkNeighbors1_puyoAtPosition1___b1:
    lda.z x
    ldy.z y
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z checkNeighbors1_puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z checkNeighbors1_puyoAtPosition1_return+1
    jmp checkNeighbors1___b29
}
// deleteMarkedPuyos(byte zp($1f) player, byte zp($b) num)
deleteMarkedPuyos: {
    .label i = $a
    .label player = $1f
    .label num = $b
    lda #0
    sta.z i
  __b1:
    lda.z i
    cmp.z num
    bcc __b2
    rts
  __b2:
    lda.z player
    asl
    asl
    asl
    asl
    asl
    asl
    clc
    adc.z i
    asl
    tay
    lda #0
    ldx deleteList,y
    stx !+ +1
    ldx deleteList+1,y
    stx !+ +2
  !:
    sta $ffff
    inc.z i
    jmp __b1
}
// clearMarked(byte zp($20) player)
clearMarked: {
    .label puyoAtPosition1_return = $15
    .label y = $a
    .label player = $20
    lda #0
    sta.z y
  __b1:
    lda.z y
    cmp #$c
    bcc __b3
    rts
  __b3:
    ldx #0
  __b2:
    cpx #6
    bcc puyoAtPosition1
    inc.z y
    jmp __b1
  puyoAtPosition1:
    lda #0
    cmp.z player
    beq puyoAtPosition1___b1
    ldy.z y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  __b4:
    lda #$7f
    ldy #0
    and (puyoAtPosition1_return),y
    sta (puyoAtPosition1_return),y
    inx
    jmp __b2
  puyoAtPosition1___b1:
    ldy.z y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp __b4
}
// refreshScreen(byte zp(7) player)
refreshScreen: {
    .label __8 = $1d
    .label __10 = $e
    .label __12 = $e
    .label __13 = $1f
    .label __15 = $e
    .label __16 = $e
    .label __22 = $20
    .label y = 8
    .label offset = $e
    .label screenadr = $21
    .label coladr = $e
    .label puyoAtPosition1_return = $12
    .label currentPuyoID = $1e
    .label tileadr = $23
    .label screenadr_1 = $29
    .label coladr_1 = $25
    .label tileListOffset = $19
    .label player = 7
    lda #1
    cmp.z player
    bne __b2
    lda #4
    sta.z tileListOffset
    jmp __b1
  __b2:
    lda #0
    sta.z tileListOffset
  __b1:
    lda #$ff
    ldy.z tileListOffset
    sta playerTileList,y
    sta playerTileList+1,y
    sta playerTileList+2,y
    sta playerTileList+3,y
    lda #0
    sta.z y
  __b3:
    lda.z y
    cmp #$c
    bcc __b6
    rts
  __b6:
    ldx #0
  __b4:
    cpx #6
    bcc __b5
    inc.z y
    jmp __b3
  __b5:
    lda.z player
    cmp #0
    bne !__b7+
    jmp __b7
  !__b7:
    txa
    asl
    sta.z __8
    lda.z y
    asl
    tay
    lda.z __8
    clc
    adc screenLutY,y
    sta.z __10
    lda screenLutY+1,y
    adc #0
    sta.z __10+1
    lda #6*2+4
    clc
    adc.z __12
    sta.z __12
    bcc !+
    inc.z __12+1
  !:
  __b9:
    lda #6
    clc
    adc.z offset
    sta.z offset
    bcc !+
    inc.z offset+1
  !:
    lda.z offset
    clc
    adc #<DEFAULT_SCREEN
    sta.z screenadr
    lda.z offset+1
    adc #>DEFAULT_SCREEN
    sta.z screenadr+1
    clc
    lda.z coladr
    adc #<COLORRAM
    sta.z coladr
    lda.z coladr+1
    adc #>COLORRAM
    sta.z coladr+1
    lda #0
    cmp.z player
    bne !puyoAtPosition1___b1+
    jmp puyoAtPosition1___b1
  !puyoAtPosition1___b1:
    ldy.z y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas+$c*6
    sta.z puyoAtPosition1_return
    lda #>canvas+$c*6
    adc #0
    sta.z puyoAtPosition1_return+1
  __b12:
    lda #7
    ldy #0
    and (puyoAtPosition1_return),y
    sta.z currentPuyoID
    asl
    asl
    sta.z __22
    clc
    adc #<tiles
    sta.z tileadr
    lda #>tiles
    adc #0
    sta.z tileadr+1
    lda #$20
    and (puyoAtPosition1_return),y
    cmp #0
    beq __b10
    ldy.z tileListOffset
    txa
    sta playerTileList,y
    iny
    lda.z y
    sta playerTileList,y
    iny
    sty.z tileListOffset
  __b10:
    // tile
    ldy.z __22
    lda tiles,y
    ldy #0
    sta (screenadr),y
    inc.z screenadr
    bne !+
    inc.z screenadr+1
  !:
    inc.z tileadr
    bne !+
    inc.z tileadr+1
  !:
    ldy #0
    lda (tileadr),y
    sta (screenadr),y
    inc.z screenadr
    bne !+
    inc.z screenadr+1
  !:
    inc.z tileadr
    bne !+
    inc.z tileadr+1
  !:
    lda #$26
    clc
    adc.z screenadr
    sta.z screenadr_1
    lda #0
    adc.z screenadr+1
    sta.z screenadr_1+1
    lda #$26
    sta.z $ff
    ldy #0
    lda (tileadr),y
    ldy.z $ff
    sta (screenadr),y
    inc.z screenadr_1
    bne !+
    inc.z screenadr_1+1
  !:
    inc.z tileadr
    bne !+
    inc.z tileadr+1
  !:
    ldy #0
    lda (tileadr),y
    sta (screenadr_1),y
    // colour
    ldy.z currentPuyoID
    lda colours,y
    ldy #0
    sta (coladr),y
    inc.z coladr
    bne !+
    inc.z coladr+1
  !:
    ldy.z currentPuyoID
    lda colours,y
    ldy #0
    sta (coladr),y
    inc.z coladr
    bne !+
    inc.z coladr+1
  !:
    lda #$26
    clc
    adc.z coladr
    sta.z coladr_1
    lda #0
    adc.z coladr+1
    sta.z coladr_1+1
    ldy.z currentPuyoID
    lda colours,y
    ldy #$26
    sta (coladr),y
    inc.z coladr_1
    bne !+
    inc.z coladr_1+1
  !:
    ldy.z currentPuyoID
    lda colours,y
    ldy #0
    sta (coladr_1),y
    inx
    jmp __b4
  puyoAtPosition1___b1:
    ldy.z y
    txa
    clc
    adc canvasLutY,y
    clc
    adc #<canvas
    sta.z puyoAtPosition1_return
    lda #>canvas
    adc #0
    sta.z puyoAtPosition1_return+1
    jmp __b12
  __b7:
    txa
    asl
    sta.z __13
    lda.z y
    asl
    tay
    lda.z __13
    clc
    adc screenLutY,y
    sta.z __15
    lda screenLutY+1,y
    adc #0
    sta.z __15+1
    jmp __b9
}
// Output one character at the current cursor position
// Moves the cursor forward. Scrolls the entire screen if needed
// cputc(byte register(A) c)
cputc: {
    cmp #'\n'
    beq __b1
    ldy.z conio_cursor_x
    sta (conio_line_text),y
    lda.z conio_textcolor
    sta (conio_line_color),y
    inc.z conio_cursor_x
    lda #$28
    cmp.z conio_cursor_x
    bne __breturn
    jsr cputln
  __breturn:
    rts
  __b1:
    jsr cputln
    rts
}
// Print a newline
cputln: {
    lda #$28
    clc
    adc.z conio_line_text
    sta.z conio_line_text
    bcc !+
    inc.z conio_line_text+1
  !:
    lda #$28
    clc
    adc.z conio_line_color
    sta.z conio_line_color
    bcc !+
    inc.z conio_line_color+1
  !:
    lda #0
    sta.z conio_cursor_x
    inc.z conio_cursor_y
    jsr cscroll
    rts
}
// Scroll the entire screen if the cursor is beyond the last line
cscroll: {
    lda #$19
    cmp.z conio_cursor_y
    bne __breturn
    lda #<$19*$28-$28
    sta.z memcpy.num
    lda #>$19*$28-$28
    sta.z memcpy.num+1
    lda #<DEFAULT_SCREEN
    sta.z memcpy.destination
    lda #>DEFAULT_SCREEN
    sta.z memcpy.destination+1
    lda #<DEFAULT_SCREEN+$28
    sta.z memcpy.source
    lda #>DEFAULT_SCREEN+$28
    sta.z memcpy.source+1
    jsr memcpy
    lda #<$19*$28-$28
    sta.z memcpy.num
    lda #>$19*$28-$28
    sta.z memcpy.num+1
    lda #<COLORRAM
    sta.z memcpy.destination
    lda #>COLORRAM
    sta.z memcpy.destination+1
    lda #<COLORRAM+$28
    sta.z memcpy.source
    lda #>COLORRAM+$28
    sta.z memcpy.source+1
    jsr memcpy
    ldx #' '
    lda #<DEFAULT_SCREEN+$19*$28-$28
    sta.z memset.str
    lda #>DEFAULT_SCREEN+$19*$28-$28
    sta.z memset.str+1
    jsr memset
    ldx.z conio_textcolor
    lda #<COLORRAM+$19*$28-$28
    sta.z memset.str
    lda #>COLORRAM+$19*$28-$28
    sta.z memset.str+1
    jsr memset
    sec
    lda.z conio_line_text
    sbc #$28
    sta.z conio_line_text
    lda.z conio_line_text+1
    sbc #0
    sta.z conio_line_text+1
    sec
    lda.z conio_line_color
    sbc #$28
    sta.z conio_line_color
    lda.z conio_line_color+1
    sbc #0
    sta.z conio_line_color+1
    dec.z conio_cursor_y
  __breturn:
    rts
}
// Copies the character c (an unsigned char) to the first num characters of the object pointed to by the argument str.
// memset(void* zp($15) str, byte register(X) c)
memset: {
    .label end = $23
    .label dst = $15
    .label str = $15
    lda #$28
    clc
    adc.z str
    sta.z end
    lda #0
    adc.z str+1
    sta.z end+1
  __b2:
    lda.z dst+1
    cmp.z end+1
    bne __b3
    lda.z dst
    cmp.z end
    bne __b3
    rts
  __b3:
    txa
    ldy #0
    sta (dst),y
    inc.z dst
    bne !+
    inc.z dst+1
  !:
    jmp __b2
}
// Copy block of memory (forwards)
// Copies the values of num bytes from the location pointed to by source directly to the memory block pointed to by destination.
// memcpy(void* zp($25) destination, void* zp($23) source, word zp($12) num)
memcpy: {
    .label src_end = $12
    .label dst = $25
    .label src = $23
    .label source = $23
    .label destination = $25
    .label num = $12
    lda.z src_end
    clc
    adc.z source
    sta.z src_end
    lda.z src_end+1
    adc.z source+1
    sta.z src_end+1
  __b1:
    lda.z src+1
    cmp.z src_end+1
    bne __b2
    lda.z src
    cmp.z src_end
    bne __b2
    rts
  __b2:
    ldy #0
    lda (src),y
    sta (dst),y
    inc.z dst
    bne !+
    inc.z dst+1
  !:
    inc.z src
    bne !+
    inc.z src+1
  !:
    jmp __b1
}
// Set the cursor to the specified position
// gotoxy(byte register(A) x)
gotoxy: {
    cmp #$28
    bcc __b2
    lda #0
  __b2:
    sta.z conio_cursor_x
    lda #0
    sta.z conio_cursor_y
    lda #<DEFAULT_SCREEN
    sta.z conio_line_text
    lda #>DEFAULT_SCREEN
    sta.z conio_line_text+1
    lda #<COLORRAM
    sta.z conio_line_color
    lda #>COLORRAM
    sta.z conio_line_color+1
    rts
}
// Output a NUL-terminated string at the current cursor position
// cputs(byte* zp($27) s)
cputs: {
    .label s = $27
  __b1:
    ldy #0
    lda (s),y
    inc.z s
    bne !+
    inc.z s+1
  !:
    cmp #0
    bne __b2
    rts
  __b2:
    jsr cputc
    jmp __b1
}
// Print an unsigned char using a specific format
// printf_uchar(byte register(X) uvalue)
printf_uchar: {
    // Handle any sign
    lda #0
    sta printf_buffer
  // Format number into buffer
    jsr uctoa
    lda printf_buffer
  // Print using format
    jsr printf_number_buffer
    rts
}
// Print the contents of the number buffer using a specific format.
// This handles minimum length, zero-filling, and left/right justification from the format
// printf_number_buffer(byte register(A) buffer_sign)
printf_number_buffer: {
    .label buffer_digits = printf_buffer+OFFSET_STRUCT_PRINTF_BUFFER_NUMBER_DIGITS
    cmp #0
    beq __b2
    jsr cputc
  __b2:
    lda #<buffer_digits
    sta.z cputs.s
    lda #>buffer_digits
    sta.z cputs.s+1
    jsr cputs
    rts
}
// Converts unsigned number value to a string representing it in RADIX format.
// If the leading digits are zero they are not included in the string.
// - value : The number to be converted to RADIX
// - buffer : receives the string representing the number and zero-termination.
// - radix : The radix to convert the number to (from the enum RADIX)
// uctoa(byte register(X) value, byte* zp($23) buffer)
uctoa: {
    .const max_digits = 3
    .label digit_value = $20
    .label buffer = $23
    .label digit = $1d
    .label started = $1e
    lda #<printf_buffer+OFFSET_STRUCT_PRINTF_BUFFER_NUMBER_DIGITS
    sta.z buffer
    lda #>printf_buffer+OFFSET_STRUCT_PRINTF_BUFFER_NUMBER_DIGITS
    sta.z buffer+1
    lda #0
    sta.z started
    sta.z digit
  __b1:
    lda.z digit
    cmp #max_digits-1
    bcc __b2
    lda DIGITS,x
    ldy #0
    sta (buffer),y
    inc.z buffer
    bne !+
    inc.z buffer+1
  !:
    lda #0
    tay
    sta (buffer),y
    rts
  __b2:
    ldy.z digit
    lda RADIX_DECIMAL_VALUES_CHAR,y
    sta.z digit_value
    lda #0
    cmp.z started
    bne __b5
    cpx.z digit_value
    bcs __b5
  __b4:
    inc.z digit
    jmp __b1
  __b5:
    lda.z buffer
    sta.z uctoa_append.buffer
    lda.z buffer+1
    sta.z uctoa_append.buffer+1
    jsr uctoa_append
    inc.z buffer
    bne !+
    inc.z buffer+1
  !:
    lda #1
    sta.z started
    jmp __b4
}
// Used to convert a single digit of an unsigned number value to a string representation
// Counts a single digit up from '0' as long as the value is larger than sub.
// Each time the digit is increased sub is subtracted from value.
// - buffer : pointer to the char that receives the digit
// - value : The value where the digit will be derived from
// - sub : the value of a '1' in the digit. Subtracted continually while the digit is increased.
//        (For decimal the subs used are 10000, 1000, 100, 10, 1)
// returns : the value reduced by sub * digit so that it is less than sub.
// uctoa_append(byte* zp($29) buffer, byte register(X) value, byte zp($20) sub)
uctoa_append: {
    .label buffer = $29
    .label sub = $20
    ldy #0
  __b1:
    cpx.z sub
    bcs __b2
    lda DIGITS,y
    ldy #0
    sta (buffer),y
    rts
  __b2:
    iny
    txa
    sec
    sbc.z sub
    tax
    jmp __b1
}
scanKeyboard: {
    lda #KEY_J
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b1
    lda #KEY_L
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b2
    lda #KEY_I
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b8
    jmp __b3
  __b8:
    lda #3
    sta currentCommand+1
  __b3:
    lda #KEY_A
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b4
    lda #KEY_D
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b5
    lda #KEY_W
    sta.z keyPressed.aKey
    jsr keyPressed
    cmp #0
    bne __b11
    rts
  __b11:
    lda #3
    sta currentCommand
    rts
  __b5:
    lda #2
    sta currentCommand
    rts
  __b4:
    lda #1
    sta currentCommand
    rts
  __b2:
    lda #2
    sta currentCommand+1
    jmp __b3
  __b1:
    lda #1
    sta currentCommand+1
    jmp __b3
}
// keyPressed(byte zp($1f) aKey)
keyPressed: {
    .label aKey = $1f
    ldx.z aKey
    jsr keyboard_key_pressed
    cmp #0
    beq __b1
    lda.z lastKeyPressed
    cmp.z aKey
    bne __b4
    lda #0
    rts
  __b4:
    lda.z aKey
    sta.z lastKeyPressed
    lda #1
    rts
  __b1:
    ldx.z lastKeyPressed
    jsr keyboard_key_pressed
    cmp #0
    bne __b2
    lda #0
    sta.z lastKeyPressed
  __b2:
    lda #0
    rts
}
// Determines whether a specific key is currently pressed by accessing the matrix directly
// The key is a keyboard code defined from the keyboard matrix by %00rrrccc, where rrr is the row ID (0-7) and ccc is the column ID (0-7)
// All keys exist as as KEY_XXX constants.
// Returns zero if the key is not pressed and a non-zero value if the key is currently pressed
// keyboard_key_pressed(byte register(X) key)
keyboard_key_pressed: {
    txa
    and #7
    tay
    txa
    lsr
    lsr
    lsr
    tax
    jsr keyboard_matrix_read
    and keyboard_matrix_col_bitmask,y
    rts
}
// Read a single row of the keyboard matrix
// The row ID (0-7) of the keyboard matrix row to read. See the C64 key matrix for row IDs.
// Returns the keys pressed on the row as bits according to the C64 key matrix.
// Notice: If the C64 normal interrupt is still running it will occasionally interrupt right between the read & write
// leading to erroneous readings. You must disable the normal interrupt or sei/cli around calls to the keyboard matrix reader.
// keyboard_matrix_read(byte register(X) rowid)
keyboard_matrix_read: {
    lda keyboard_matrix_row_bitmask,x
    sta CIA1
    lda CIA1+OFFSET_STRUCT_MOS6526_CIA_PORT_B
    eor #$ff
    rts
}
drawWell: {
    .const pl2Offset = 6*2+4
    .label __7 = $21
    .label __9 = $25
    .label __11 = $2f
    .label __14 = $29
    .label __17 = $21
    .label __18 = $25
    .label __19 = $2f
    .label __20 = $29
    .label __23 = $21
    .label __24 = $25
    .label __25 = $2f
    .label __26 = $29
    .label __27 = $23
    .label __28 = $21
    .label __30 = $2d
    .label __31 = $25
    .label __33 = $27
    .label __34 = $2f
    .label __36 = $2b
    .label __37 = $29
    ldx #0
  __b1:
    cpx #6*2
    bcs !__b2+
    jmp __b2
  !__b2:
    ldx #2
  __b3:
    cpx #$19
    bcc __b4
    rts
  __b4:
    txa
    sta.z __17
    lda #0
    sta.z __17+1
    lda.z __17
    asl
    sta.z __27
    lda.z __17+1
    rol
    sta.z __27+1
    asl.z __27
    rol.z __27+1
    lda.z __28
    clc
    adc.z __27
    sta.z __28
    lda.z __28+1
    adc.z __27+1
    sta.z __28+1
    asl.z __7
    rol.z __7+1
    asl.z __7
    rol.z __7+1
    asl.z __7
    rol.z __7+1
    clc
    lda.z __23
    adc #<DEFAULT_SCREEN+5
    sta.z __23
    lda.z __23+1
    adc #>DEFAULT_SCREEN+5
    sta.z __23+1
    lda #$20+$80
    ldy #0
    sta (__23),y
    txa
    sta.z __18
    tya
    sta.z __18+1
    lda.z __18
    asl
    sta.z __30
    lda.z __18+1
    rol
    sta.z __30+1
    asl.z __30
    rol.z __30+1
    lda.z __31
    clc
    adc.z __30
    sta.z __31
    lda.z __31+1
    adc.z __30+1
    sta.z __31+1
    asl.z __9
    rol.z __9+1
    asl.z __9
    rol.z __9+1
    asl.z __9
    rol.z __9+1
    clc
    lda.z __24
    adc #<DEFAULT_SCREEN+6+6*2
    sta.z __24
    lda.z __24+1
    adc #>DEFAULT_SCREEN+6+6*2
    sta.z __24+1
    lda #$20+$80
    sta (__24),y
    txa
    sta.z __19
    tya
    sta.z __19+1
    lda.z __19
    asl
    sta.z __33
    lda.z __19+1
    rol
    sta.z __33+1
    asl.z __33
    rol.z __33+1
    lda.z __34
    clc
    adc.z __33
    sta.z __34
    lda.z __34+1
    adc.z __33+1
    sta.z __34+1
    asl.z __11
    rol.z __11+1
    asl.z __11
    rol.z __11+1
    asl.z __11
    rol.z __11+1
    clc
    lda.z __25
    adc #<DEFAULT_SCREEN+5+pl2Offset
    sta.z __25
    lda.z __25+1
    adc #>DEFAULT_SCREEN+5+pl2Offset
    sta.z __25+1
    lda #$20+$80
    sta (__25),y
    txa
    sta.z __20
    tya
    sta.z __20+1
    lda.z __20
    asl
    sta.z __36
    lda.z __20+1
    rol
    sta.z __36+1
    asl.z __36
    rol.z __36+1
    lda.z __37
    clc
    adc.z __36
    sta.z __37
    lda.z __37+1
    adc.z __36+1
    sta.z __37+1
    asl.z __14
    rol.z __14+1
    asl.z __14
    rol.z __14+1
    asl.z __14
    rol.z __14+1
    clc
    lda.z __26
    adc #<DEFAULT_SCREEN+6+6*2+pl2Offset
    sta.z __26
    lda.z __26+1
    adc #>DEFAULT_SCREEN+6+6*2+pl2Offset
    sta.z __26+1
    lda #$20+$80
    sta (__26),y
    inx
    jmp __b3
  __b2:
    lda #$20+$80
    sta DEFAULT_SCREEN+6+$18*$28,x
    sta DEFAULT_SCREEN+6+$18*$28+pl2Offset,x
    inx
    jmp __b1
}
// Initialize keyboard reading by setting CIA#$ Data Direction Registers
keyboard_init: {
    // Keyboard Matrix Columns Write Mode
    lda #$ff
    sta CIA1+OFFSET_STRUCT_MOS6526_CIA_PORT_A_DDR
    // Keyboard Matrix Columns Read Mode
    lda #0
    sta CIA1+OFFSET_STRUCT_MOS6526_CIA_PORT_B_DDR
    rts
}
setVIC3Mode: {
    .label key = $d02f
    .label vicmode = $d031
    lda #$a5
    sta key
    lda #$96
    sta key
    lda #$40
    ora vicmode
    sta vicmode
    rts
}
// Set the color for text output. The old color setting is returned.
// textcolor(byte register(A) color)
textcolor: {
    sta.z conio_textcolor
    rts
}
// Set the color for the background. The old color setting is returned.
bgcolor: {
    .const color = 0
    // The background color register address
    .label CONIO_BGCOLOR = $d021
    lda #color
    sta CONIO_BGCOLOR
    rts
}
setupLUTs: {
    .label __3 = $2d
    .label __5 = $2d
    .label __9 = $2f
    .label __10 = $2d
    ldx #0
  __b1:
    cpx #$c
    bcc __b2
    ldx #0
  __b3:
    cpx #$18
    bcc __b4
    rts
  __b4:
    txa
    sta.z __5
    lda #0
    sta.z __5+1
    lda.z __5
    asl
    sta.z __9
    lda.z __5+1
    rol
    sta.z __9+1
    asl.z __9
    rol.z __9+1
    lda.z __10
    clc
    adc.z __9
    sta.z __10
    lda.z __10+1
    adc.z __9+1
    sta.z __10+1
    asl.z __3
    rol.z __3+1
    asl.z __3
    rol.z __3+1
    asl.z __3
    rol.z __3+1
    asl.z __3
    rol.z __3+1
    txa
    asl
    tay
    lda.z __3
    sta screenLutY,y
    lda.z __3+1
    sta screenLutY+1,y
    inx
    jmp __b3
  __b2:
    txa
    asl
    stx.z $ff
    clc
    adc.z $ff
    asl
    sta canvasLutY,x
    inx
    jmp __b1
}
// clears the screen and moves the cursor to the upper left-hand corner of the screen.
clrscr: {
    .label line_text = $2b
    .label line_cols = $25
    lda #<COLORRAM
    sta.z line_cols
    lda #>COLORRAM
    sta.z line_cols+1
    lda #<DEFAULT_SCREEN
    sta.z line_text
    lda #>DEFAULT_SCREEN
    sta.z line_text+1
    ldx #0
  __b1:
    cpx #$19
    bcc __b2
    lda #0
    sta.z conio_cursor_x
    sta.z conio_cursor_y
    lda #<DEFAULT_SCREEN
    sta.z conio_line_text
    lda #>DEFAULT_SCREEN
    sta.z conio_line_text+1
    lda #<COLORRAM
    sta.z conio_line_color
    lda #>COLORRAM
    sta.z conio_line_color+1
    rts
  __b2:
    ldy #0
  __b3:
    cpy #$28
    bcc __b4
    lda #$28
    clc
    adc.z line_text
    sta.z line_text
    bcc !+
    inc.z line_text+1
  !:
    lda #$28
    clc
    adc.z line_cols
    sta.z line_cols
    bcc !+
    inc.z line_cols+1
  !:
    inx
    jmp __b1
  __b4:
    lda #' '
    sta (line_text),y
    lda.z conio_textcolor
    sta (line_cols),y
    iny
    jmp __b3
}
loadCharset: {
    lda #<$800
    sta.z memcpy.num
    lda #>$800
    sta.z memcpy.num+1
    lda #<$3000
    sta.z memcpy.destination
    lda #>$3000
    sta.z memcpy.destination+1
    lda #<charset
    sta.z memcpy.source
    lda #>charset
    sta.z memcpy.source+1
    jsr memcpy
    lda #$f0
    and VICII+OFFSET_STRUCT_MOS6569_VICII_MEMORY
    clc
    adc #$c
    sta VICII+OFFSET_STRUCT_MOS6569_VICII_MEMORY
    lda #$10
    ora VICII+OFFSET_STRUCT_MOS6569_VICII_CONTROL2
    sta VICII+OFFSET_STRUCT_MOS6569_VICII_CONTROL2
    lda #GREEN
    sta VICII+OFFSET_STRUCT_MOS6569_VICII_BG_COLOR1
    lda #WHITE
    sta VICII+OFFSET_STRUCT_MOS6569_VICII_BG_COLOR2
    rts
}
irqService: {
    inc.z ticks
    lda #8
    and.z ticks
    cmp #0
    bne !__ea31+
    jmp $ea31
  !__ea31:
    jmp $ea31
}
  charset: .byte $3c, $66, $6e, $6e, $60, $62, $3c, 0, $18, $3c, $66, $7e, $66, $66, $66, 0, $7c, $66, $66, $7c, $66, $66, $7c, 0, $3c, $66, $60, $60, $60, $66, $3c, 0, $78, $6c, $66, $66, $66, $6c, $78, 0, $7e, $60, $60, $78, $60, $60, $7e, 0, $7e, $60, $60, $78, $60, $60, $60, 0, $3c, $66, $60, $6e, $66, $66, $3c, 0, $66, $66, $66, $7e, $66, $66, $66, 0, $3c, $18, $18, $18, $18, $18, $3c, 0, $1e, $c, $c, $c, $c, $6c, $38, 0, $66, $6c, $78, $70, $78, $6c, $66, 0, $60, $60, $60, $60, $60, $60, $7e, 0, $63, $77, $7f, $6b, $63, $63, $63, 0, $66, $76, $7e, $7e, $6e, $66, $66, 0, $3c, $66, $66, $66, $66, $66, $3c, 0, $7c, $66, $66, $7c, $60, $60, $60, 0, $3c, $66, $66, $66, $66, $3c, $e, 0, $7c, $66, $66, $7c, $78, $6c, $66, 0, $3c, $66, $60, $3c, 6, $66, $3c, 0, $7e, $18, $18, $18, $18, $18, $18, 0, $66, $66, $66, $66, $66, $66, $3c, 0, $66, $66, $66, $66, $66, $3c, $18, 0, $63, $63, $63, $6b, $7f, $77, $63, 0, $66, $66, $3c, $18, $3c, $66, $66, 0, $66, $66, $66, $3c, $18, $18, $18, 0, $7e, 6, $c, $18, $30, $60, $7e, 0, $3c, $30, $30, $30, $30, $30, $3c, 0, $c, $12, $30, $7c, $30, $62, $fc, 0, $3c, $c, $c, $c, $c, $c, $3c, 0, 0, $18, $3c, $7e, $18, $18, $18, $18, 0, $10, $30, $7f, $7f, $30, $10, 0, 0, 0, 0, 0, 0, 0, 0, 0, $18, $18, $18, $18, 0, 0, $18, 0, $66, $66, $66, 0, 0, 0, 0, 0, $66, $66, $ff, $66, $ff, $66, $66, 0, $18, $3e, $60, $3c, 6, $7c, $18, 0, $62, $66, $c, $18, $30, $66, $46, 0, $3c, $66, $3c, $38, $67, $66, $3f, 0, 6, $c, $18, 0, 0, 0, 0, 0, $c, $18, $30, $30, $30, $18, $c, 0, $30, $18, $c, $c, $c, $18, $30, 0, 0, $66, $3c, $ff, $3c, $66, 0, 0, 0, $18, $18, $7e, $18, $18, 0, 0, 0, 0, 0, 0, 0, $18, $18, $30, 0, 0, 0, $7e, 0, 0, 0, 0, 0, 0, 0, 0, 0, $18, $18, 0, 0, 3, 6, $c, $18, $30, $60, 0, $3c, $66, $6e, $76, $66, $66, $3c, 0, $18, $18, $38, $18, $18, $18, $7e, 0, $3c, $66, 6, $c, $30, $60, $7e, 0, $3c, $66, 6, $1c, 6, $66, $3c, 0, 6, $e, $1e, $66, $7f, 6, 6, 0, $7e, $60, $7c, 6, 6, $66, $3c, 0, $3c, $66, $60, $7c, $66, $66, $3c, 0, $7e, $66, $c, $18, $18, $18, $18, 0, $3c, $66, $66, $3c, $66, $66, $3c, 0, $3c, $66, $66, $3e, 6, $66, $3c, 0, 0, 0, $18, 0, 0, $18, 0, 0, 0, 0, $18, 0, 0, $18, $18, $30, $e, $18, $30, $60, $30, $18, $e, 0, 0, 0, $7e, 0, $7e, 0, 0, 0, $70, $18, $c, 6, $c, $18, $70, 0, $3c, $66, 6, $c, $18, 0, $18, 0, 3, $f, $17, $2b, $23, $3f, $fd, $fd, $c0, $f0, $d4, $e8, $c8, $fc, $7f, $7f, $ff, $ff, $3b, $3e, $3f, $f, $f, 3, $ff, $ff, $ec, $bc, $fc, $f0, $f0, $c0, 0, 0, $ff, $ff, 0, 0, 0, 0, 0, $ff, $ff, 0, 0, 0, 0, 0, 0, 0, 0, 0, $ff, $ff, 0, 0, $30, $30, $30, $30, $30, $30, $30, $30, $c, $c, $c, $c, $c, $c, $c, $c, 0, 0, 0, $e0, $f0, $38, $18, $18, $18, $18, $1c, $f, 7, 0, 0, 0, $18, $18, $38, $f0, $e0, 0, 0, 0, $c0, $c0, $c0, $c0, $c0, $c0, $ff, $ff, $c0, $e0, $70, $38, $1c, $e, 7, 3, 3, 7, $e, $1c, $38, $70, $e0, $c0, $ff, $ff, $c0, $c0, $c0, $c0, $c0, $c0, $ff, $ff, 3, 3, 3, 3, 3, 3, 0, $3c, $7e, $7e, $7e, $7e, $3c, 0, 0, 0, 0, 0, 0, $ff, $ff, 0, $36, $7f, $7f, $7f, $3e, $1c, 8, 0, $60, $60, $60, $60, $60, $60, $60, $60, 0, 0, 0, 7, $f, $1c, $18, $18, $c3, $e7, $7e, $3c, $3c, $7e, $e7, $c3, 0, $3c, $7e, $66, $66, $7e, $3c, 0, $18, $18, $66, $66, $18, $18, $3c, 0, 6, 6, 6, 6, 6, 6, 6, 6, 8, $1c, $3e, $7f, $3e, $1c, 8, 0, $18, $18, $18, $ff, $ff, $18, $18, $18, $c0, $c0, $30, $30, $c0, $c0, $30, $30, $18, $18, $18, $18, $18, $18, $18, $18, 0, 0, 3, $3e, $76, $36, $36, 0, $ff, $7f, $3f, $1f, $f, 7, 3, 1, 0, 0, 0, 0, 0, 0, 0, 0, $f0, $f0, $f0, $f0, $f0, $f0, $f0, $f0, 0, 0, 0, 0, $ff, $ff, $ff, $ff, $ff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $ff, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $cc, $cc, $33, $33, $cc, $cc, $33, $33, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, $cc, $cc, $33, $33, $ff, $fe, $fc, $f8, $f0, $e0, $c0, $80, 3, 3, 3, 3, 3, 3, 3, 3, $18, $18, $18, $1f, $1f, $18, $18, $18, 0, 0, 0, 0, $f, $f, $f, $f, $18, $18, $18, $1f, $1f, 0, 0, 0, 0, 0, 0, $f8, $f8, $18, $18, $18, 0, 0, 0, 0, 0, 0, $ff, $ff, 0, 0, 0, $1f, $1f, $18, $18, $18, $18, $18, $18, $ff, $ff, 0, 0, 0, 0, 0, 0, $ff, $ff, $18, $18, $18, $18, $18, $18, $f8, $f8, $18, $18, $18, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $c0, $e0, $e0, $e0, $e0, $e0, $e0, $e0, $e0, 7, 7, 7, 7, 7, 7, 7, 7, $ff, $ff, 0, 0, 0, 0, 0, 0, $ff, $ff, $ff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, $ff, $ff, $ff, 3, 3, 3, 3, 3, 3, $ff, $ff, 0, 0, 0, 0, $f0, $f0, $f0, $f0, $f, $f, $f, $f, 0, 0, 0, 0, $18, $18, $18, $f8, $f8, 0, 0, 0, $f0, $f0, $f0, $f0, 0, 0, 0, 0, $f0, $f0, $f0, $f0, $f, $f, $f, $f, $c3, $99, $91, $91, $9f, $99, $c3, $ff, $e7, $c3, $99, $81, $99, $99, $99, $ff, $83, $99, $99, $83, $99, $99, $83, $ff, $c3, $99, $9f, $9f, $9f, $99, $c3, $ff, $87, $93, $99, $99, $99, $93, $87, $ff, $81, $9f, $9f, $87, $9f, $9f, $81, $ff, $81, $9f, $9f, $87, $9f, $9f, $9f, $ff, $c3, $99, $9f, $91, $99, $99, $c3, $ff, $99, $99, $99, $81, $99, $99, $99, $ff, $c3, $e7, $e7, $e7, $e7, $e7, $c3, $ff, $e1, $f3, $f3, $f3, $f3, $93, $c7, $ff, $99, $93, $87, $8f, $87, $93, $99, $ff, $9f, $9f, $9f, $9f, $9f, $9f, $81, $ff, $9c, $88, $80, $94, $9c, $9c, $9c, $ff, $99, $89, $81, $81, $91, $99, $99, $ff, $c3, $99, $99, $99, $99, $99, $c3, $ff, $83, $99, $99, $83, $9f, $9f, $9f, $ff, $c3, $99, $99, $99, $99, $c3, $f1, $ff, $83, $99, $99, $83, $87, $93, $99, $ff, $c3, $99, $9f, $c3, $f9, $99, $c3, $ff, $81, $e7, $e7, $e7, $e7, $e7, $e7, $ff, $99, $99, $99, $99, $99, $99, $c3, $ff, $99, $99, $99, $99, $99, $c3, $e7, $ff, $9c, $9c, $9c, $94, $80, $88, $9c, $ff, $99, $99, $c3, $e7, $c3, $99, $99, $ff, $99, $99, $99, $c3, $e7, $e7, $e7, $ff, $81, $f9, $f3, $e7, $cf, $9f, $81, $ff, $c3, $cf, $cf, $cf, $cf, $cf, $c3, $ff, $f3, $ed, $cf, $83, $cf, $9d, 3, $ff, $c3, $f3, $f3, $f3, $f3, $f3, $c3, $ff, $ff, $e7, $c3, $81, $e7, $e7, $e7, $e7, $ff, $ef, $cf, $80, $80, $cf, $ef, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $e7, $e7, $e7, $e7, $ff, $ff, $e7, $ff, $99, $99, $99, $ff, $ff, $ff, $ff, $ff, $99, $99, 0, $99, 0, $99, $99, $ff, $e7, $c1, $9f, $c3, $f9, $83, $e7, $ff, $9d, $99, $f3, $e7, $cf, $99, $b9, $ff, $c3, $99, $c3, $c7, $98, $99, $c0, $ff, $f9, $f3, $e7, $ff, $ff, $ff, $ff, $ff, $f3, $e7, $cf, $cf, $cf, $e7, $f3, $ff, $cf, $e7, $f3, $f3, $f3, $e7, $cf, $ff, $ff, $99, $c3, 0, $c3, $99, $ff, $ff, $ff, $e7, $e7, $81, $e7, $e7, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $e7, $e7, $cf, $ff, $ff, $ff, $81, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $e7, $e7, $ff, $ff, $fc, $f9, $f3, $e7, $cf, $9f, $ff, $c3, $99, $91, $89, $99, $99, $c3, $ff, $e7, $e7, $c7, $e7, $e7, $e7, $81, $ff, $c3, $99, $f9, $f3, $cf, $9f, $81, $ff, $c3, $99, $f9, $e3, $f9, $99, $c3, $ff, $f9, $f1, $e1, $99, $80, $f9, $f9, $ff, $81, $9f, $83, $f9, $f9, $99, $c3, $ff, $c3, $99, $9f, $83, $99, $99, $c3, $ff, $81, $99, $f3, $e7, $e7, $e7, $e7, $ff, $c3, $99, $99, $c3, $99, $99, $c3, $ff, $c3, $99, $99, $c1, $f9, $99, $c3, $ff, $ff, $ff, $e7, $ff, $ff, $e7, $ff, $ff, $ff, $ff, $e7, $ff, $ff, $e7, $e7, $cf, $f1, $e7, $cf, $9f, $cf, $e7, $f1, $ff, $ff, $ff, $81, $ff, $81, $ff, $ff, $ff, $8f, $e7, $f3, $f9, $f3, $e7, $8f, $ff, $c3, $99, $f9, $f3, $e7, $ff, $e7, $ff, $ff, $ff, $ff, 0, 0, $ff, $ff, $ff, $f7, $e3, $c1, $80, $80, $e3, $c1, $ff, $e7, $e7, $e7, $e7, $e7, $e7, $e7, $e7, $ff, $ff, $ff, 0, 0, $ff, $ff, $ff, $ff, $ff, 0, 0, $ff, $ff, $ff, $ff, $ff, 0, 0, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, $ff, $ff, $cf, $cf, $cf, $cf, $cf, $cf, $cf, $cf, $f3, $f3, $f3, $f3, $f3, $f3, $f3, $f3, $ff, $ff, $ff, $1f, $f, $c7, $e7, $e7, $e7, $e7, $e3, $f0, $f8, $ff, $ff, $ff, $e7, $e7, $c7, $f, $1f, $ff, $ff, $ff, $3f, $3f, $3f, $3f, $3f, $3f, 0, 0, $3f, $1f, $8f, $c7, $e3, $f1, $f8, $fc, $fc, $f8, $f1, $e3, $c7, $8f, $1f, $3f, 0, 0, $3f, $3f, $3f, $3f, $3f, $3f, 0, 0, $fc, $fc, $fc, $fc, $fc, $fc, $ff, $c3, $81, $81, $81, $81, $c3, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, $ff, $c9, $80, $80, $80, $c1, $e3, $f7, $ff, $9f, $9f, $9f, $9f, $9f, $9f, $9f, $9f, $ff, $ff, $ff, $f8, $f0, $e3, $e7, $e7, $3c, $18, $81, $c3, $c3, $81, $18, $3c, $ff, $c3, $81, $99, $99, $81, $c3, $ff, $e7, $e7, $99, $99, $e7, $e7, $c3, $ff, $f9, $f9, $f9, $f9, $f9, $f9, $f9, $f9, $f7, $e3, $c1, $80, $c1, $e3, $f7, $ff, $e7, $e7, $e7, 0, 0, $e7, $e7, $e7, $3f, $3f, $cf, $cf, $3f, $3f, $cf, $cf, $e7, $e7, $e7, $e7, $e7, $e7, $e7, $e7, $ff, $ff, $fc, $c1, $89, $c9, $c9, $ff, 0, $80, $c0, $e0, $f0, $f8, $fc, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $f, $f, $f, $f, $f, $f, $f, $f, $ff, $ff, $ff, $ff, 0, 0, 0, 0, 0, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, 0, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $33, $33, $cc, $cc, $33, $33, $cc, $cc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $ff, $ff, $ff, $ff, $33, $33, $cc, $cc, 0, 1, 3, 7, $f, $1f, $3f, $7f, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $fc, $e7, $e7, $e7, $e0, $e0, $e7, $e7, $e7, $ff, $ff, $ff, $ff, $f0, $f0, $f0, $f0, $e7, $e7, $e7, $e0, $e0, $ff, $ff, $ff, $ff, $ff, $ff, 7, 7, $e7, $e7, $e7, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, $ff, $ff, $ff, $e0, $e0, $e7, $e7, $e7, $e7, $e7, $e7, 0, 0, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, $e7, $e7, $e7, $e7, $e7, $e7, 7, 7, $e7, $e7, $e7, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $3f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $1f, $f8, $f8, $f8, $f8, $f8, $f8, $f8, $f8, 0, 0, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, 0, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, 0, 0, 0, $fc, $fc, $fc, $fc, $fc, $fc, 0, 0, $ff, $ff, $ff, $ff, $f, $f, $f, $f, $f0, $f0, $f0, $f0, $ff, $ff, $ff, $ff, $e7, $e7, $e7, 7, 7, $ff, $ff, $ff, $f, $f, $f, $f, $ff, $ff, $ff, $ff, $f, $f, $f, $f, $f0, $f0, $f0, $f0
  // Keyboard row bitmask as expected by CIA#1 Port A when reading a specific keyboard matrix row (rows are numbered 0-7)
  keyboard_matrix_row_bitmask: .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f
  // Keyboard matrix column bitmasks for a specific keybooard matrix column when reading the keyboard. (columns are numbered 0-7)
  keyboard_matrix_col_bitmask: .byte 1, 2, 4, 8, $10, $20, $40, $80
  // The digits used for numbers
  DIGITS: .text "0123456789abcdef"
  // Values of decimal digits
  RADIX_DECIMAL_VALUES_CHAR: .byte $64, $a
  tiles: .byte $20, $20, $20, $20, $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43, $40, $41, $42, $43
  colours: .byte BLACK, 8+RED, 8+BLUE, 8+PURPLE, 8+CYAN
  playerTileList: .fill 8, 0
  // table holding coordinates of currently falling tiles
  deleteList: .fill 2*2*$40, 0
  canvas: .fill 2*$c*6, 0
  playerStartTick: .fill 2, 0
  currentPlayerState: .fill 2, 0
  hasDeleted: .fill 2, 0
  currentCommand: .fill 2, 0
  canvasLutY: .fill $c, 0
  // lookup table for rows
  screenLutY: .fill 2*$19, 0
  /*
  Unfortunately, KickC doesn't do recursion. So we have to check for groups
  of puyos in a slightly more convoluted way than I had hoped...
*/
  deleteListOffsetTbl: .byte $ff, $40-1
  // Buffer used for stringified number being printed
  printf_buffer: .fill SIZEOF_STRUCT_PRINTF_BUFFER_NUMBER, 0
