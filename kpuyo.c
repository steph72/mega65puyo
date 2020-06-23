
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

#define NUM_ROWS 20
#define NUM_COLUMNS 10 // caution! well size can't be >255

#define WELL_XPOS SCREEN_WIDTH / 2 - NUM_COLUMNS / 2
#define WELL_YPOS 2

#define WELLSIZE NUM_ROWS *NUM_COLUMNS

#define KP_BIT_CHECKED 128
#define KP_BIT_DELETE 64

#define puyoAtPosition(x, y) &canvas[(x) + ((y)*NUM_COLUMNS)]

byte graphChars[] = {' ', 'a' + 128, 'b' + 128, 'c' + 128};
byte colours[] = {BLACK, GREEN, BLUE, PURPLE};
byte *deleteList[64];
byte canvas[WELLSIZE];

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

void dbgSetColor(byte x, byte y, byte c)
{
  COLORRAM[(word)(WELL_XPOS + x + ((word)(WELL_YPOS + y) * 40))] = c;
}

void resetColors()
{
  byte x, y;
  for (x = 0; x < NUM_COLUMNS; x++)
  {
    for (y = 0; y < NUM_ROWS; y++)
    {
      dbgSetColor(x, y, LIGHT_BLUE);
    }
  }
}

// return the puyo id at a given position, or 0 if position is invalid
// (for fast neighbor checking)
byte puyoIDAtPosition(byte x, byte y)
{
  if (x > NUM_COLUMNS - 1 || y > NUM_ROWS - 1)
  {
    return 0;
  }
  return *puyoAtPosition(x, y) & 7;
}

/*
  Unfortunately, KickC doesn't do recursion. So we have to check for groups
  of puyos in a slightly more convoluted way than I had hoped...
*/

byte checkNeighbors(byte px, byte py)
{
  bool found;
  register byte x, y;
  byte thisPuyoID;
  byte markedPuyoID;
  byte numHits = 1;

  *DEFAULT_SCREEN = '0' + numHits;
  thisPuyoID = *puyoAtPosition(px, py);

  // no puyo or already marked? don't check
  if (!thisPuyoID || thisPuyoID & 128)
  {
    return 0;
  }

  deleteList[numHits - 1] = puyoAtPosition(px, py);
  markedPuyoID = thisPuyoID | 128;

  // mark this puyo
  *puyoAtPosition(px, py) = markedPuyoID; // mark this puyo

  found = true;

  while (found)
  {
    found = false;
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      for (y = 0; y < NUM_ROWS; y++)
      {
        // same colour?
        if (*puyoAtPosition(x, y) == thisPuyoID)
        {
          if (
              ((x < NUM_COLUMNS - 1) && (*puyoAtPosition(x + 1, y) == markedPuyoID)))
          {
            *puyoAtPosition(x, y) |= 128;
            numHits++;
            found = true;
            deleteList[numHits - 1] = puyoAtPosition(x, y);
          }

          if (
              ((x > 0) && (*puyoAtPosition(x - 1, y) == markedPuyoID)))
          {
            *puyoAtPosition(x, y) |= 128;
            numHits++;
            found = true;
            deleteList[numHits - 1] = puyoAtPosition(x, y);
          }

          if (
              ((y > 0) && (*puyoAtPosition(x, y - 1) == markedPuyoID)))
          {
            *puyoAtPosition(x, y) |= 128;
            numHits++;
            found = true;
            deleteList[numHits - 1] = puyoAtPosition(x, y);
          }

          if (
              ((y < NUM_ROWS - 1) && (*puyoAtPosition(x, y + 1) == markedPuyoID)))
          {
            *puyoAtPosition(x, y) |= 128;
            numHits++;
            found = true;
            deleteList[numHits - 1] = puyoAtPosition(x, y);
          }
        }
      }
    }
  }
  return numHits;
}

void deleteMarkedPuyos(byte num)
{
  byte i;
  for (i = 0; i < num; i++)
  {
    *deleteList[i] = 0;
  }
  // gotoxy(0, 1);
  // printf("%u deleted   ", num);
  // drawCanvas();
  // dbgWaitkey();
}

void clearMarked(void)
{
  byte x, y;
  for (y = 0; y < NUM_ROWS; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      *puyoAtPosition(x, y) &= 127;
    }
  }
}

bool markForDeletion(void)
{
  byte x, y;
  byte *currentPuyo;
  byte currentPuyoID;
  byte count;
  bool hasDeleted;

  clearMarked();
  hasDeleted = false;

  for (y = 0; y < NUM_ROWS; y++)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      count = checkNeighbors(x, y);
      if (count > 3)
      {
        deleteMarkedPuyos(count);
        hasDeleted = true;
      }
    }
  }
  return hasDeleted;
}

bool fallDownStep(void)
{
  bool moved = false;
  byte *elem, *prevElem;
  byte x, y;

  for (y = NUM_ROWS - 1; y != 0; y--)
  {
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      elem = puyoAtPosition(x, y);
      prevElem = puyoAtPosition(x, y - 1);

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

void drawCanvas(void)
{
  byte x, y;
  byte *baseadr;
  byte *screenadr;
  byte *colourAdr;
  byte pID;

  // start address of well screen area
  screenadr = DEFAULT_SCREEN + WELL_XPOS + (40 * WELL_YPOS);
  colourAdr = COLORRAM + WELL_XPOS + (40 * WELL_YPOS);

  for (y = 0; y < NUM_ROWS; y++)
  {
    baseadr = canvas + (y * NUM_COLUMNS);
    // blit current canvas line onto screen
    for (x = 0; x < NUM_COLUMNS; x++)
    {
      pID = (*baseadr++) & 7;
      // *screenadr++ = *baseadr++; // debugging only
      *screenadr++ = graphChars[pID];
      *colourAdr++ = colours[pID];
    }
    // increase screen line
    screenadr += (40 - NUM_COLUMNS);
    colourAdr += (40 - NUM_COLUMNS);
  }
}

void test()
{
  word i, i2;
  byte a;
  byte count;

  while (true)
  {
    // empty canvas
    for (i = 0; i < (NUM_ROWS * NUM_COLUMNS); canvas[i++] = 0)
    {
    }

    for (i2 = 0; i2 < NUM_ROWS; i2++)
    {
      // fill upper row with random puyos
      for (i = 0; i < NUM_COLUMNS; i++)
      {
        a = sid_rnd() & 3;
        canvas[i] = a;
      }
      while (fallDownStep())
      {
        drawCanvas();
      }
      while (markForDeletion())
      {
        do
        {
          drawCanvas();
        } while (fallDownStep());
      }
    }
  }
}

void main()
{
  clrscr();
  bordercolor(0);
  bgcolor(0);
  sid_rnd_init();
  keyboard_init();
  test();
}