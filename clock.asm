// C standard library time.h
//  Functions to get and manipulate date and time information.
.pc = $801 "Basic"
:BasicUpstart(main)
.pc = $80d "Program"
  // Timer Control - Start/stop timer (0:stop, 1: start)
  .const CIA_TIMER_CONTROL_START = 1
  // Timer B Control - Timer counts (00:system cycles, 01: CNT pulses, 10: timer A underflow, 11: time A underflow while CNT is high)
  .const CIA_TIMER_CONTROL_B_COUNT_UNDERFLOW_A = $40
  .const OFFSET_STRUCT_MOS6526_CIA_TIMER_A_CONTROL = $e
  .const OFFSET_STRUCT_MOS6526_CIA_TIMER_B_CONTROL = $f
  // The CIA#2: Serial bus, RS-232, VIC memory bank
  .label CIA2 = $dd00
  // CIA#2 timer A&B as one single 32-bit value
  .label CIA2_TIMER_AB = $dd04
main: {
    .label __2 = 6
    .label __3 = 6
    .label current = 2
    jsr clock_start
    jsr clock
    lda.z clock.return
    sta.z clock.return_1
    lda.z clock.return+1
    sta.z clock.return_1+1
    lda.z clock.return+2
    sta.z clock.return_1+2
    lda.z clock.return+3
    sta.z clock.return_1+3
  __b1:
    jsr clock
    lda.z __3
    sec
    sbc.z current
    sta.z __3
    lda.z __3+1
    sbc.z current+1
    sta.z __3+1
    lda.z __3+2
    sbc.z current+2
    sta.z __3+2
    lda.z __3+3
    sbc.z current+3
    sta.z __3+3
    cmp #>$a>>$10
    bcc __b1
    bne !+
    lda.z __3+2
    cmp #<$a>>$10
    bcc __b1
    bne !+
    lda.z __3+1
    cmp #>$a
    bcc __b1
    bne !+
    lda.z __3
    cmp #<$a
    bcc __b1
  !:
    rts
}
// Returns the processor clock time used since the beginning of an implementation defined era (normally the beginning of the program).
// This uses CIA #2 Timer A+B on the C64, and must be initialized using clock_start()
clock: {
    .label return = 6
    .label return_1 = 2
    lda #<$ffffffff
    sec
    sbc CIA2_TIMER_AB
    sta.z return
    lda #>$ffffffff
    sbc CIA2_TIMER_AB+1
    sta.z return+1
    lda #<$ffffffff>>$10
    sbc CIA2_TIMER_AB+2
    sta.z return+2
    lda #>$ffffffff>>$10
    sbc CIA2_TIMER_AB+3
    sta.z return+3
    rts
}
// Reset & start the processor clock time. The value can be read using clock().
// This uses CIA #2 Timer A+B on the C64
clock_start: {
    // Setup CIA#2 timer A to count (down) CPU cycles
    lda #0
    sta CIA2+OFFSET_STRUCT_MOS6526_CIA_TIMER_A_CONTROL
    lda #CIA_TIMER_CONTROL_B_COUNT_UNDERFLOW_A
    sta CIA2+OFFSET_STRUCT_MOS6526_CIA_TIMER_B_CONTROL
    lda #<$ffffffff
    sta CIA2_TIMER_AB
    lda #>$ffffffff
    sta CIA2_TIMER_AB+1
    lda #<$ffffffff>>$10
    sta CIA2_TIMER_AB+2
    lda #>$ffffffff>>$10
    sta CIA2_TIMER_AB+3
    lda #CIA_TIMER_CONTROL_START|CIA_TIMER_CONTROL_B_COUNT_UNDERFLOW_A
    sta CIA2+OFFSET_STRUCT_MOS6526_CIA_TIMER_B_CONTROL
    lda #CIA_TIMER_CONTROL_START
    sta CIA2+OFFSET_STRUCT_MOS6526_CIA_TIMER_A_CONTROL
    rts
}
