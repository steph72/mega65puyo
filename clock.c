#include <time.h>

void main(void) {
    clock_t current;
    clock_start();
    current=clock();
    do {
        // wait
    } while (clock()-current<10);
}