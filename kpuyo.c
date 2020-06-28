
#include <c64.h>
#include <keyboard.h>
#include <stdio.h>
#include <conio.h>
#include "charset.h"

#define DEBUG

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
#define KP_BIT_IS_PLAYER_TILE 32

#define KP_STATE_BEGIN_FALL 0
#define KP_STATE_FALL_DOWN 1
#define KP_STATE_FIND_AND_DELETE_COMBOS1 2
#define KP_STATE_FIND_AND_DELETE_COMBOS2 3
#define KP_STATE_FALL_AFTER_DELETE 4

volatile byte ticks;

const byte tiles[] = {32, 32, 32, 32, 64, 65, 66, 67, 64, 65, 66, 67, 64, 65, 66, 67, 64, 65, 66, 67};
const byte colours[] = {BLACK, 8 + RED, 8 + BLUE, 8 + PURPLE, 8 + CYAN};

byte playerTileList[8]; // table holding coordinates of currently falling tiles
byte *deleteList[2 * DELETELIST_SIZE];
byte canvas[2 * WELLSIZE];

byte playerStartTick[2];
byte currentPlayerState[2];
byte hasDeleted[2]; // delete flags for state machine
byte baseTickDelay = 8;

byte canvasLutY[NUM_ROWS]; // lookup table for rows
word screenLutY[25];       // screen row LUT

#ifdef DEBUG
byte maxTicks;
#endif

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

/* 
find puyos to delete
at least for c64 class machines, we have to do this
in two parts, because otherwise the analysis phase
would lock up the machine too long 
*/

byte markForDeletion(byte player, byte part)
{
  byte x, y;
  byte *currentPuyo;
  byte currentPuyoID;
  byte count;
  byte hasDeleted;

  byte startY, endY;

  clearMarked(player);
  hasDeleted = 0;

  if (part == 0)
  {
    startY = 0;
    endY = NUM_ROWS / 2;
  }
  else
  {
    startY = NUM_ROWS / 2;
    endY = NUM_ROWS;
  }

  for (y = startY; y < endY; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      count = checkNeighbors(player, x, y);
      if (count > 3)
      {
        deleteMarkedPuyos(player, count);
        hasDeleted = 1;
      }
    }
  }
  return hasDeleted;
}

bool fallDownStep(byte player)
{
  bool moved = false;
  byte *elem, *prevElem, *nextElem;
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

      // stop player tiles if they have landed
      if (*elem & KP_BIT_IS_PLAYER_TILE)
      {
        if (y == NUM_ROWS - 1)
        {
          *elem = *elem & 7; // remove player tile bit
        }
        else
        {
          if (puyoIDAtPosition(player, x, y + 1))
          {
            *elem = *elem & 7;
          }
        }
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
  byte *currentPuyo;
  byte currentPuyoID;
  byte tileListOffset;
  word offset;
  byte x, y;

  tileListOffset = 0;
  if (player == 1)
  {
    tileListOffset = 4;
  }

  playerTileList[tileListOffset] = 0;
  playerTileList[tileListOffset + 1] = 0;
  playerTileList[tileListOffset + 2] = 0;
  playerTileList[tileListOffset + 3] = 0;

  // refreshing from bottom up to avoid flickering
  for (y = NUM_ROWS - 1; y != 0; y--)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      offset = 6 + ((player == 0) ? (x * 2 + (screenLutY[y])) : x * 2 + screenLutY[y] + (NUM_COLUMNS * 2) + 4);
      screenadr = (DEFAULT_SCREEN + offset);
      coladr = (COLORRAM + offset);
      currentPuyo = puyoAtPosition(player, x, y);
      currentPuyoID = *currentPuyo & 7;
      tileadr = &tiles[currentPuyoID * 4];

      // test for player tile
      if (*currentPuyo & KP_BIT_IS_PLAYER_TILE)
      {
        playerTileList[tileListOffset++] = x;
        playerTileList[tileListOffset++] = y;
      }

      // tile
      *(screenadr++) = *(tileadr++);
      *(screenadr++) = *(tileadr++);
      screenadr += 38;
      *(screenadr++) = *(tileadr++);
      *screenadr = *(tileadr);
      // colour
      *(coladr++) = colours[currentPuyoID];
      *(coladr++) = colours[currentPuyoID];
      coladr += 38;
      *(coladr++) = colours[currentPuyoID];
      *(coladr) = colours[currentPuyoID];
    }
  }
/*
#ifdef DEBUG
  gotoxy(0, 1);
  printf("%u,%u / %u,%u    \n", playerTileList[0], playerTileList[1], playerTileList[2], playerTileList[3]);
  printf("%u,%u / %u,%u    ", playerTileList[4], playerTileList[5], playerTileList[6], playerTileList[7]);
#endif
*/
}

inline void addNewPlayerTile(byte player, word offset)
{
  byte startColumn;
  byte tile1, tile2;

  do
  {
    tile2 = 1 + (rand() & 3);
  } while (tile2 > 3);

  do
  {
    tile1 = 1 + (rand() & 3);
  } while (tile1 > 3);

  do
  {
    startColumn = rand() & 7;
  } while (startColumn > NUM_COLUMNS - 2);

  canvas[offset + (word)startColumn] = tile1 | KP_BIT_IS_PLAYER_TILE;
  canvas[offset + (word)startColumn + 1] = tile2 | KP_BIT_IS_PLAYER_TILE;
}

// main game logic implemented as state machine
// (see kp_state defines for possible states)

void doPlayerTick(byte player)
{

  byte i, a;
  word offset = 0;

#ifdef DEBUG
  byte ct;
  ct = ticks - playerStartTick[player];
  if (ct > maxTicks)
  {
    maxTicks = ct;
    gotoxy(0, 0);
    printf("mt: %u   ", maxTicks);
  }
#endif

  if (ticks - playerStartTick[player] < baseTickDelay)
  {
    return;
  }

  if (player == 1)
  {
    offset = WELLSIZE;
  }

  playerStartTick[player] = ticks; //;currentTick;

#ifdef DEBUG
  gotoxy(35, 0);
  cputc('0' + currentPlayerState[player]);
#endif

  switch (currentPlayerState[player])
  {

  case KP_STATE_BEGIN_FALL:
  {
    addNewPlayerTile(player, offset);
    currentPlayerState[player] = KP_STATE_FALL_DOWN;
    break;
  }

  case KP_STATE_FALL_DOWN:
  {
    if (!fallDownStep(player))
    {
      currentPlayerState[player] = KP_STATE_FIND_AND_DELETE_COMBOS1;
    }
    break;
  }

  case KP_STATE_FIND_AND_DELETE_COMBOS1:
  {
    hasDeleted[player] = markForDeletion(player, 0);
    currentPlayerState[player] = KP_STATE_FIND_AND_DELETE_COMBOS2;
    break;
  }

  case KP_STATE_FIND_AND_DELETE_COMBOS2:
  {
    hasDeleted[player] |= markForDeletion(player, 1);
    if (hasDeleted[player])
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
      currentPlayerState[player] = KP_STATE_FIND_AND_DELETE_COMBOS1;
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

void setupLUTs()
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

void loadCharset()
{
  byte characterPointer;
  memcpy(0x3000, charset, 2048);
  characterPointer = (VICII->MEMORY & 240) + 12;
  VICII->MEMORY = characterPointer;
  VICII->CONTROL2 |= 16;
  VICII->BG_COLOR1 = GREEN;
  VICII->BG_COLOR2 = WHITE;
}

void main()
{
  loadCharset();
  asm { sei}
  *KERNEL_IRQ = &irqService;
  asm { cli}
  clrscr();
  setupLUTs();
  bgcolor(0);
  bordercolor(0);
  textcolor(GREEN);
  setVIC3Mode();
  // keyboard_init();
  test();
}
