
#ifndef CART_H
#define CART_H

#include <stdint.h>
#include <stdbool.h>

typedef struct Cart Cart;

#include "mango/snes.h"
#include "mango/statehandler.h"

typedef struct CartHeader {
  // normal header
  uint8_t headerVersion; // 1, 2, 3
  char name[22]; // $ffc0-$ffd4 (max 21 bytes + \0), $ffd4=$00: header V2
  uint8_t speed; // $ffd5.7-4 (always 2 or 3)
  uint8_t type; // $ffd5.3-0
  uint8_t coprocessor; // $ffd6.7-4
  uint8_t chips; // $ffd6.3-0
  uint32_t romSize; // $ffd7 (0x400 << x)
  uint32_t ramSize; // $ffd8 (0x400 << x)
  uint8_t region; // $ffd9 (also NTSC/PAL)
  uint8_t maker; // $ffda ($33: header V3)
  uint8_t version; // $ffdb
  uint16_t checksumComplement; // $ffdc,$ffdd
  uint16_t checksum; // $ffde,$ffdf
  // v2/v3 (v2 only exCoprocessor)
  char makerCode[3]; // $ffb0,$ffb1: (2 chars + \0)
  char gameCode[5]; // $ffb2-$ffb5: (4 chars + \0)
  uint32_t flashSize; // $ffbc (0x400 << x)
  uint32_t exRamSize; // $ffbd (0x400 << x) (used for GSU?)
  uint8_t specialVersion; // $ffbe
  uint8_t exCoprocessor; // $ffbf (if coprocessor = $f)
  // calculated stuff
  int16_t score; // score for header, to see which mapping is most likely
  bool pal; // if this is a rom for PAL regions instead of NTSC
  uint8_t cartType; // calculated type
  bool hasBattery; // battery
} CartHeader;

void readHeader(const uint8_t* data, int length, int location, CartHeader* header);

struct Cart {
  Snes* snes;
  uint8_t type;
  bool hasBattery;

  uint8_t* rom;
  uint32_t romSize;
  uint8_t* ram;
  uint32_t ramSize;
};

// TODO: how to handle reset & load?

Cart* cart_init(Snes* snes);
void cart_free(Cart* cart);
void cart_reset(Cart* cart); // will reset special chips etc, general reading is set up in load
bool cart_handleTypeState(Cart* cart, StateHandler* sh);
void cart_handleState(Cart* cart, StateHandler* sh);
void cart_load(Cart* cart, int type, uint8_t* rom, int romSize, int ramSize, bool hasBattery); // loads rom, sets up ram buffer
bool cart_handleBattery(Cart* cart, bool save, uint8_t* data, int* size); // saves/loads ram
uint8_t cart_read(Cart* cart, uint8_t bank, uint16_t adr);
void cart_write(Cart* cart, uint8_t bank, uint16_t adr, uint8_t val);

#endif
