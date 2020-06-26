
#include <c64.h>
#include <keyboard.h>
#include <stdio.h>
#include <conio.h>

// fix for vscode syntax checking: define unknown types
#ifdef __UTYPES__
typedef unsigned char byte;
typedef unsigned char bool;
typedef unsigned int word;
#define true 1
#define false 0
#endif

#define SCREEN_WIDTH 40
#define DELETELIST_SIZE 64
#define SCREEN_MID 20
#define WELL_H_PADDING 3

#define NUM_ROWS 12
#define NUM_COLUMNS 6 // caution! well size can't be >255

#define WELL_YPOS 2

#define WELLSIZE NUM_ROWS *NUM_COLUMNS

#define KP_BIT_CHECKED 128
#define KP_BIT_DELETE 64

#define KP_STATE_BEGIN_FALL 0
#define KP_STATE_FALL_DOWN 1
#define KP_STATE_FIND_AND_DELETE_COMBOS 2
#define KP_STATE_FALL_AFTER_DELETE 3

volatile byte ticks;

const byte tiles[] = "    abcdefghijklmnop";
const byte colours[] = {BLACK, GREEN, BLUE, PURPLE};

byte *deleteList[2 * DELETELIST_SIZE];
byte canvas[2 * WELLSIZE];

byte playerStartTick[2];
byte currentPlayerState[2];
byte baseTickDelay = 15;

byte canvasLutY[NUM_ROWS]; // lookup table for rows
word screenLutY[25];       // screen row LUT

/*
byte *puyoAtPosition(byte player, byte x, byte y)
{
  return player == 1 ? &canvas[WELLSIZE + x + canvasLutY[y]] : &canvas[x + canvasLutY[y]];
}
*/

inline byte *puyoAtPosition(byte player, byte x, byte y)
{
  if (player)
  {
    return &canvas[WELLSIZE + x + canvasLutY[y]];
  }
  return &canvas[x + canvasLutY[y]];
}

void dbgWaitkey(void)
{

  // wait until there is no event (return 0xff)
  while (keyboard_event_get() != 0xff)
  {
    keyboard_event_scan();
  }

  // wait until key pressed
  while (keyboard_event_get() == 0xff)
  {
    keyboard_event_scan();
  }

  while (keyboard_event_get() == 0xff)
  {
    keyboard_event_scan();
  }
}

// return the puyo id at a given position
inline byte puyoIDAtPosition(byte player, byte x, byte y)
{
  return *puyoAtPosition(player, x, y) & 7;
}

/*
  Unfortunately, KickC doesn't do recursion. So we have to check for groups
  of puyos in a slightly more convoluted way than I had hoped...
*/

const byte deleteListOffsetTbl[] = {255, DELETELIST_SIZE - 1};

inline byte checkNeighbors(byte player, byte px, byte py)
{
  byte found;
  register byte x, y;
  byte thisPuyoID;
  byte markedPuyoID;
  byte numHits = 1;
  byte deleteListOffset;

  byte *currentPuyo;

  thisPuyoID = *puyoAtPosition(player, px, py);

  // no puyo or already marked? don't check
  if (!thisPuyoID || thisPuyoID & 128)
  {
    return 0;
  }

  deleteListOffset = deleteListOffsetTbl[player];

  deleteList[deleteListOffset + numHits] = puyoAtPosition(player, px, py);
  markedPuyoID = thisPuyoID | 128;

  // mark this puyo
  *puyoAtPosition(player, px, py) = markedPuyoID;

  found = 1;

  do
  {
    found = 0;
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      for (y = 0; y < NUM_ROWS; y++)
      {

        currentPuyo = puyoAtPosition(player, x, y);

        // same colour?
        if (*currentPuyo == thisPuyoID)
        {
          // check if there's a puyo of the same colour already
          // marked in the neighborhood. if yes, also mark the current puyo
          if (
              ((x < NUM_COLUMNS - 1) && (*puyoAtPosition(player, x + 1, y) == markedPuyoID)))
          {
            *currentPuyo |= 128;
            numHits++;
            found = 1;
            deleteList[deleteListOffset + numHits] = currentPuyo;
          }

          if (
              ((x > 0) && (*puyoAtPosition(player, x - 1, y) == markedPuyoID)))
          {
            *currentPuyo |= 128;
            numHits++;
            found = 1;
            deleteList[deleteListOffset + numHits] = currentPuyo;
          }

          if (
              ((y > 0) && (*puyoAtPosition(player, x, y - 1) == markedPuyoID)))
          {
            *currentPuyo |= 128;
            numHits++;
            found = 1;
            deleteList[deleteListOffset + numHits] = currentPuyo;
          }

          if (
              ((y < NUM_ROWS - 1) && (*puyoAtPosition(player, x, y + 1) == markedPuyoID)))
          {
            *currentPuyo |= 128;
            numHits++;
            found = 1;
            deleteList[deleteListOffset + numHits] = currentPuyo;
          }
        }
      }
    }
  } while (found);
  return numHits;
}

void deleteMarkedPuyos(byte player, byte num)
{
  byte i;
  for (i = 0; i < num; i++)
  {
    *deleteList[(player * DELETELIST_SIZE) + i] = 0;
  }
}

void clearMarked(byte player)
{
  byte x, y;
  for (y = 0; y < NUM_ROWS; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      *puyoAtPosition(player, x, y) &= 127;
    }
  }
}

bool markForDeletion(byte player)
{
  byte x, y;
  byte *currentPuyo;
  byte currentPuyoID;
  byte count;
  bool hasDeleted;

  clearMarked(player);
  hasDeleted = false;

  for (y = 0; y < NUM_ROWS; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      count = checkNeighbors(player, x, y);
      if (count > 3)
      {
        deleteMarkedPuyos(player, count);
        hasDeleted = true;
      }
    }
  }
  return hasDeleted;
}

bool fallDownStep(byte player)
{
  bool moved = false;
  byte *elem, *prevElem;
  byte x, y;

  for (y = NUM_ROWS - 1; y != 0; y--)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      elem = puyoAtPosition(player, x, y);
      prevElem = puyoAtPosition(player, x, y - 1);

      if (*elem == 0 && *prevElem != 0)
      {
        moved = true;
        *elem = *prevElem;
        *prevElem = 0;
      }
    }
  }
  return moved;
}

void refreshScreen(byte player)
{
  byte *screenadr;
  byte *coladr;
  byte *tileadr;
  byte currentPuyo;
  word offset;
  byte x, y;

  // refreshing from bottom up to avoid flickering
  for (y = NUM_ROWS - 1; y != 0; y--)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      offset = 6 + ((player == 0) ? (x * 2 + (screenLutY[y])) : x * 2 + screenLutY[y] + (NUM_COLUMNS * 2) + 4);
      screenadr = (DEFAULT_SCREEN + offset);
      coladr = (COLORRAM + offset);
      currentPuyo = puyoIDAtPosition(player, x, y);
      tileadr = &tiles[currentPuyo * 4];
      // tile
      *(screenadr++) = *(tileadr++) | 128;
      *(screenadr++) = *(tileadr++) | 128;
      screenadr += 38;
      *(screenadr++) = *(tileadr++) | 128;
      *screenadr = *(tileadr) | 128;
      // colour
      *(coladr++) = colours[currentPuyo];
      *(coladr++) = colours[currentPuyo];
      coladr += 38;
      *(coladr++) = colours[currentPuyo];
      *(coladr) = colours[currentPuyo];
    }
  }
}

// main game logic implemented as state machine
// (see kp_state defines for possible states)

void doPlayerTick(byte player)
{

  byte i, a;
  word offset = 0;

  if (ticks - playerStartTick[player] < baseTickDelay)
  {
    return;
  }

  if (player == 1)
  {
    offset = WELLSIZE;
  }

  playerStartTick[player] = ticks; //;currentTick;

  switch (currentPlayerState[player])
  {

  case KP_STATE_BEGIN_FALL:
  {
    for (i = 0; i < NUM_COLUMNS; i++)
    {
      a = rand() & 3;
      canvas[offset + i] = a;
    }
    currentPlayerState[player] = KP_STATE_FALL_DOWN;
    break;
  }

  case KP_STATE_FALL_DOWN:
  {
    if (!fallDownStep(player))
    {
      currentPlayerState[player] = KP_STATE_FIND_AND_DELETE_COMBOS;
    }
    break;
  }

  case KP_STATE_FIND_AND_DELETE_COMBOS:
  {
    if (markForDeletion(player))
    {
      currentPlayerState[player] = KP_STATE_FALL_AFTER_DELETE;
    }
    else
    {
      currentPlayerState[player] = KP_STATE_BEGIN_FALL;
    }
    break;
  }

  case KP_STATE_FALL_AFTER_DELETE:
  {
    if (!fallDownStep(player))
    {
      currentPlayerState[player] = KP_STATE_FIND_AND_DELETE_COMBOS;
    }
    break;
  }
  }

  refreshScreen(player);
}

void test()
{
  word i, i2;
  byte a;
  byte count;

  currentPlayerState[0] = KP_STATE_BEGIN_FALL;
  currentPlayerState[1] = KP_STATE_BEGIN_FALL;

  while (true)
  {
    // empty canvas
    for (i = 0; i < (WELLSIZE * 2); canvas[i++] = 0)
    {
    }

    while (true)
    {
      doPlayerTick(0);
      doPlayerTick(1);
    }
  }
}

interrupt(kernel_keyboard) void irqService(void)
{
  ticks++;
}

void setupLUT()
{
  byte a;
  for (a = 0; a < NUM_ROWS; a++)
  {
    canvasLutY[a] = a * NUM_COLUMNS;
  }
  for (a = 0; a < 24; a++)
  {
    screenLutY[a] = (word)a * 80;
  }
}

void setVIC3Mode()
{
  const byte *key = 0xd02f;
  const byte *vicmode = 0xd031;
  *key = 165;
  *key = 150;
  *vicmode |= 64;
}

void main()
{

  asm { sei}
  *KERNEL_IRQ = &irqService;
  asm { cli}

  clrscr();
  setupLUT();
  bgcolor(0);
  bordercolor(0);
  setVIC3Mode();
  // keyboard_init();
  test();
}
