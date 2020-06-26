#!/bin/sh
echo "byte align(0x800) charset[]={" > charset.c
hexdump -ve '1/1 "0x%.2x,"' kpuyochars-charset.raw >> charset.c
echo "};" >> charset.c

