#include <stdio.h>

byte something = 4;

byte getTileListOffset(byte player)
{
    byte tileListOffset;
      tileListOffset = 0;

    tileListOffset = (player == 1) ? 4 : 0;
    return tileListOffset;
}

void main(void)
{
    byte offset = getTileListOffset(something);
    printf("%u", offset);
}