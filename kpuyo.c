
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

#define BASE_DELAY 20

#define SCREEN_WIDTH 40
#define SCREEN_MID 20
#define WELL_H_PADDING 3

#define NUM_ROWS 12
#define NUM_COLUMNS 6 // caution! well size can't be >255

#define WELL_YPOS 2

#define WELLSIZE NUM_ROWS *NUM_COLUMNS

#define KP_BIT_MARKED 128
#define KP_BIT_DELETE 64
#define KP_BIT_IS_PLAYER_TILE 32
#define KP_BIT_IS_NUISANCE 8

#define KP_STATE_BEGIN_FALL 0
#define KP_STATE_FALL_DOWN 1
#define KP_STATE_FIND_AND_DELETE_COMBOS1 2
#define KP_STATE_FIND_AND_DELETE_COMBOS2 3
#define KP_STATE_FALL_AFTER_DELETE 4

#define KP_POSITION_INVALID 255

volatile byte ticks;

const byte tiles[] = {
    32, 32, 32, 32,  // tile 0
    64, 65, 66, 67,  // tile 1
    64, 65, 66, 67,  // tile 2
    64, 65, 66, 67,  // tile 3
    64, 65, 66, 67,  // tile 4
    0, 0, 0, 0,      // tile 5
    0, 0, 0, 0,      // tile 6
    0, 0, 0, 0,      // tile 7
    68, 69, 70, 71}; // tile 8 (junk tile)

const byte colours[] = {BLACK, 8 + RED, 8 + BLUE, 8 + PURPLE, 8 + CYAN, 0, 0, 0, 8 + WHITE};

byte playerTileList[8]; // table holding coordinates of currently falling tiles
byte canvas[2 * WELLSIZE];

byte playerStartTick[2];
byte currentPlayerState[2];
byte hasDeleted[2];               // delete flags for state machine
byte numOfCurrentDeletedTiles[2]; // for keeping score
byte baseTickDelay[2] = {BASE_DELAY, BASE_DELAY};

volatile byte currentCommand[2];
byte lastKeyPressed;

byte canvasLutY[NUM_ROWS]; // lookup table for rows
word screenLutY[25];       // screen row LUT

byte currentPlayerKey[16];
byte nextTiles[16];

word playerTileCount[2];

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

inline byte checkNeighbors(byte player, byte px, byte py)
{
  byte found;
  register byte x, y;
  byte thisPuyoID;
  byte markedPuyoID;
  byte numHits = 1;

  byte *currentPuyo;

  thisPuyoID = *puyoAtPosition(player, px, py);

  // no puyo or already marked? don't check
  if (!thisPuyoID || thisPuyoID & KP_BIT_MARKED || thisPuyoID & KP_BIT_IS_NUISANCE)
  {
    return 0;
  }

  markedPuyoID = thisPuyoID | KP_BIT_MARKED;

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
            *currentPuyo |= KP_BIT_MARKED;
            numHits++;
            found = 1;
          }

          if (
              ((x > 0) && (*puyoAtPosition(player, x - 1, y) == markedPuyoID)))
          {
            *currentPuyo |= KP_BIT_MARKED;
            numHits++;
            found = 1;
          }

          if (
              ((y > 0) && (*puyoAtPosition(player, x, y - 1) == markedPuyoID)))
          {
            *currentPuyo |= KP_BIT_MARKED;
            numHits++;
            found = 1;
          }

          if (
              ((y < NUM_ROWS - 1) && (*puyoAtPosition(player, x, y + 1) == markedPuyoID)))
          {
            *currentPuyo |= KP_BIT_MARKED;
            numHits++;
            found = 1;
          }
        }
      }
    }
  } while (found);
  return numHits;
}

void deleteMarkedPuyos(byte player, byte num)
{
  byte x,y;
  byte *puyo;
  for (x=0;x<NUM_COLUMNS;x++) {
    for (y=0;y<NUM_ROWS;y++) {
      if (*puyoAtPosition(player,x,y) & KP_BIT_MARKED) {
        *puyoAtPosition(player,x,y) = 0;
      }
    }
  }
  return;

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
        hasDeleted = count;
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
        // landing on bottom
        if (y == NUM_ROWS - 1)
        {
          *elem = *elem & 7; // remove player tile bit
        }
        else
        {
          // landing on non-player-tile
          nextElem = puyoAtPosition(player, x, y + 1);
          if (*nextElem)
          {
            if (!(*nextElem & KP_BIT_IS_PLAYER_TILE))
            {
              *elem = *elem & 7;
            }
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

  playerTileList[tileListOffset] = KP_POSITION_INVALID;
  playerTileList[tileListOffset + 1] = KP_POSITION_INVALID;
  playerTileList[tileListOffset + 2] = KP_POSITION_INVALID;
  playerTileList[tileListOffset + 3] = KP_POSITION_INVALID;

  for (y = 0; y < NUM_ROWS; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      offset = 6 + ((player == 0) ? (x * 2 + (screenLutY[y])) : x * 2 + screenLutY[y] + (NUM_COLUMNS * 2) + 4);
      screenadr = (DEFAULT_SCREEN + offset);
      coladr = (COLORRAM + offset);
      currentPuyo = puyoAtPosition(player, x, y);
      // we AND the current puyo with 15 here, because we
      // explicitly want to draw the "8" (junk tiles) if needed
      currentPuyoID = *currentPuyo & 15;
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
}

void drawWell()
{
  byte x, y;
  const byte pl2Offset = (NUM_COLUMNS * 2) + 4;

  for (x = 0; x < NUM_COLUMNS * 2; ++x)
  {
    DEFAULT_SCREEN[6 + x + (24 * 40)] = 160;
    DEFAULT_SCREEN[6 + x + (24 * 40) + pl2Offset] = 160;
  }
  for (y = 2; y < 25; y++)
  {
    DEFAULT_SCREEN[5 + ((word)y * 40)] = 160;
    DEFAULT_SCREEN[6 + (NUM_COLUMNS * 2) + ((word)y * 40)] = 160;
    DEFAULT_SCREEN[6 + (NUM_COLUMNS * 2) + ((word)y * 40) + pl2Offset] = 160;
  }
}

inline void addJunk(byte player, byte lines)
{
  byte i;
  for (i = 0; i < NUM_COLUMNS; i++)
  {
    if (rand() & 2)
    {
      *puyoAtPosition(player, i, 0) = 8; // add junk puyo
    }
  }
}

inline void addNewPlayerTile(byte player, word offset)
{
  byte startColumn;
  byte tile1, tile2;

  srand(playerTileCount[player]++);

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

#define KP_CMD_NONE 0
#define KP_CMD_LEFT 1
#define KP_CMD_RIGHT 2
#define KP_CMD_TURN 3
#define KP_CMD_DROP 4

bool movePlayerPuyoRight(byte player, byte x, byte y)
{
  byte newX, newY;
  byte *srcPuyo, *destPuyo;

  if (x == KP_POSITION_INVALID)
  {
    return false;
  }

  if (x < NUM_COLUMNS - 1)
  {
    newX = x + 1;
    newY = y;
    srcPuyo = puyoAtPosition(player, x, y);
    destPuyo = puyoAtPosition(player, newX, newY);
    if (*destPuyo == 0)
    {
      *destPuyo = *srcPuyo;
      *srcPuyo = 0;
      return true;
    }
  }
  return false;
}

bool movePlayerPuyoLeft(byte player, byte x, byte y)
{
  byte newX, newY;
  byte *srcPuyo, *destPuyo;

  if (x == KP_POSITION_INVALID)
  {
    return false;
  }

  if (x > 0)
  {
    newX = x - 1;
    newY = y;
    srcPuyo = puyoAtPosition(player, x, y);
    destPuyo = puyoAtPosition(player, newX, newY);
    if (*destPuyo == 0)
    {
      *destPuyo = *srcPuyo;
      *srcPuyo = 0;
      return true;
    }
  }
  return false;
}

void rotateTile(byte player, byte tileListOffset)
{
  byte xOld0, yOld0, xOld1, yOld1;
  byte xNew0, yNew0, xNew1, yNew1;
  byte *srcPuyo;
  byte *destPyuo;
  byte temp1, temp2;

  bordercolor(RED);

  xOld0 = playerTileList[tileListOffset];
  yOld0 = playerTileList[tileListOffset + 1];
  xOld1 = playerTileList[tileListOffset + 2];
  yOld1 = playerTileList[tileListOffset + 3];

  // horizontal tile
  if (xOld1 == (xOld0 + 1))
  {
    xNew0 = xOld0;
    yNew0 = yOld0;
    xNew1 = xOld0;
    yNew1 = yOld0 + 1;
    if (yNew1 < NUM_ROWS - 1)
    {
      srcPuyo = puyoAtPosition(player, xOld1, yOld1);
      destPyuo = puyoAtPosition(player, xNew1, yNew1);
      if (*destPyuo == 0)
      {
        *destPyuo = *srcPuyo;
        *srcPuyo = 0;
      }
    }
  }
  // vertical tile
  /*

        ab -->  a  -->  ba
                b

  */
  else if (yOld1 == (yOld0 + 1))
  {
    xNew0 = xOld0 + 1;
    yNew0 = yOld0;
    xNew1 = xOld0;
    yNew1 = yOld0;
    if (xNew0 < NUM_COLUMNS)
    {
      temp1 = *puyoAtPosition(player, xOld0, yOld0);
      temp2 = *puyoAtPosition(player, xOld1, yOld1);
      *puyoAtPosition(player, xOld1, yOld1) = 0;
      *puyoAtPosition(player, xNew0, yNew0) = temp1;
      *puyoAtPosition(player, xNew1, yNew1) = temp2;
    }
  }
}

bool handleCommandForPlayer(byte player)
{

  byte tileListOffset;
  byte x, y;

  if (!currentCommand[player])
  {
    return false;
  }

  // would have solved this with ?: notation, but
  // kickc crashes with 'dk.camelot64.kickc.model.InternalError: Error! Number integer type not
  // resolved to fixed size integer type'

  tileListOffset = 0;
  if (player == 1)
  {
    tileListOffset = 4;
  }

  if (currentCommand[player] == KP_CMD_DROP)
  {
    baseTickDelay[player] = 5;
    return true;
  }

  if (currentCommand[player] == KP_CMD_TURN)
  {
    rotateTile(player, tileListOffset);
    return true;
  }

  if (currentCommand[player] == KP_CMD_RIGHT)
  {
    // second tile...
    x = playerTileList[tileListOffset + 2]; // get pos of second tile
    y = playerTileList[tileListOffset + 3];
    movePlayerPuyoRight(player, x, y);

    // first tile
    x = playerTileList[tileListOffset]; // get pos of first tile
    y = playerTileList[tileListOffset + 1];
    movePlayerPuyoRight(player, x, y);
    return true;
  }

  if (currentCommand[player] == KP_CMD_LEFT)
  {
    // first tile...
    x = playerTileList[tileListOffset]; // get pos of first tile
    y = playerTileList[tileListOffset + 1];
    movePlayerPuyoLeft(player, x, y);

    // second tile
    x = playerTileList[tileListOffset + 2]; // get pos of second tile
    y = playerTileList[tileListOffset + 3];
    movePlayerPuyoLeft(player, x, y);
    return true;
  }

  return false;
}

// main game logic implemented as state machine
// (see kp_state defines for possible states)

void doPlayerTick(byte player)
{

  byte i, a;
  word offset = 0;

  getPlayerKeypress();
  if (handleCommandForPlayer(player))
  {
    refreshScreen(player);
    currentCommand[player] = KP_CMD_NONE;
  }

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

  if (ticks - playerStartTick[player] < baseTickDelay[player])
  {
    return;
  }

  if (player == 1)
  {
    offset = WELLSIZE;
  }

  playerStartTick[player] = ticks; //;currentTick;

#ifdef DEBUG2
  gotoxy(35, 0);
  cputc('0' + currentPlayerState[player]);
#endif

  switch (currentPlayerState[player])
  {

  case KP_STATE_BEGIN_FALL:
  {
    baseTickDelay[player] = BASE_DELAY;
    addNewPlayerTile(player, offset);
    currentPlayerState[player] = KP_STATE_FALL_DOWN;
    numOfCurrentDeletedTiles[player] = 0;
    break;
  }

  case KP_STATE_FALL_DOWN:
  {
    handleCommandForPlayer(player);

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
    hasDeleted[player] += markForDeletion(player, 1);
    numOfCurrentDeletedTiles[player] += hasDeleted[player];
    if (hasDeleted[player])
    {
      currentPlayerState[player] = KP_STATE_FALL_AFTER_DELETE;
    }
    else
    {
      //gotoxy((player + 1) * 4, 24);
      //printf("%u   ", numOfCurrentDeletedTiles[player]);
      if (numOfCurrentDeletedTiles[player] > 3)
      {
        if (player)
        {
          addJunk(0, 1);
        }
        else
        {
          addJunk(1, 1);
        }
      }
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
  drawWell();

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

void changePlayerCommandState(byte player, byte state, byte event)
{
  byte offset = 0;

  if (player == 1)
  {
    offset = 8;
  }

  //key released?
  if (event & 0x40)
  {
    // printf("-%u ", state);
    currentPlayerKey[offset + state] = 0;
  }
  else
  // key pressed
  {
    if (currentPlayerKey[offset + state] == 0)
    {
      currentCommand[player] = state;
      // printf("+%u ", state);
    }
    currentPlayerKey[offset + state] = 1;
  }
}

void getPlayerKeypress(void)
{
  byte event;
  byte keycode;

  asm { sei}
  keyboard_event_scan();
  event = keyboard_event_get();
  asm { cli }

  if (event == 0xff)
  {
    return;
  }

  keycode = event & 0x3f;

  switch (keycode)
  {
  case KEY_I:
    changePlayerCommandState(1, KP_CMD_TURN, event);
    break;

  case KEY_J:
    changePlayerCommandState(1, KP_CMD_LEFT, event);
    break;

  case KEY_K:
    changePlayerCommandState(1, KP_CMD_DROP, event);
    break;

  case KEY_L:
    changePlayerCommandState(1, KP_CMD_RIGHT, event);
    break;

  case KEY_W:
    changePlayerCommandState(0, KP_CMD_TURN, event);
    break;

  case KEY_A:
    changePlayerCommandState(0, KP_CMD_LEFT, event);
    break;

  case KEY_S:
    changePlayerCommandState(0, KP_CMD_DROP, event);
    break;

  case KEY_D:
    changePlayerCommandState(0, KP_CMD_RIGHT, event);
    break;

  default:
    break;
  }
}

void main()
{
  byte a;

  textcolor(BLUE);
  loadCharset();
  asm { sei}
  *KERNEL_IRQ = &irqService;
  asm { cli}
  clrscr();
  setupLUTs();
  bgcolor(0);
  bordercolor(BLACK);
  textcolor(GREEN);
  setVIC3Mode();
  keyboard_init();
  test();
  /*
  do
  {
    getPlayerKeypress();
  } while (1);
  */
}
