
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include <snes.h>
#include <cart.h>
#include <ppu.h>
#include <dsp.h>
#include <statehandler.h>

static const int stateVersion = 2;
/*
1: initial version
2: change snes->cycles/syncCycle to uint64
*/

bool snes_loadRom(Snes* snes, const uint8_t* data, int length) {
  // if smaller than smallest possible, don't load
  if(length < 0x8000) {
    printf("Failed to load rom: rom to small (%d bytes)\n", length);
    return false;
  }
  // check headers
  CartHeader headers[6];
  memset(headers, 0, sizeof(headers));
  for(int i = 0; i < 6; i++) {
    headers[i].score = -50;
  }
  if(length >= 0x8000) readHeader(data, length, 0x7fc0, &headers[0]); // lorom
  if(length >= 0x8200) readHeader(data, length, 0x81c0, &headers[1]); // lorom + header
  if(length >= 0x10000) readHeader(data, length, 0xffc0, &headers[2]); // hirom
  if(length >= 0x10200) readHeader(data, length, 0x101c0, &headers[3]); // hirom + header
  if(length >= 0x410000) readHeader(data, length, 0x40ffc0, &headers[4]); // exhirom
  if(length >= 0x410200) readHeader(data, length, 0x4101c0, &headers[5]); // exhirom + header
  // see which it is, go backwards to allow picking ExHiROM over HiROM for roms with headers in both spots
  int max = 0;
  int used = 0;
  for(int i = 5; i >= 0; i--) {
    if(headers[i].score > max) {
      max = headers[i].score;
      used = i;
    }
  }
  if(used & 1) {
    // odd-numbered ones are for headered roms
    data += 0x200; // move pointer past header
    length -= 0x200; // and subtract from size
  }
  // check if we can load it
  if(headers[used].cartType > 4) {
    printf("Failed to load rom: unsupported type (%d)\n", headers[used].cartType);
    return false;
  }
  // expand to a power of 2
  int newLength = 0x8000;
  while(true) {
    if(length <= newLength) {
      break;
    }
    newLength *= 2;
  }
  uint8_t* newData = (uint8_t*)malloc(newLength);
  memcpy(newData, data, length);
  int test = 1;
  while(length != newLength) {
    if(length & test) {
      memcpy(newData + length, newData + length - test, test);
      length += test;
    }
    test *= 2;
  }
  // coprocessor check
  if (headers[used].exCoprocessor == 0x10) {
    headers[used].cartType = 4; // cx4
  }
  // load it
  const char* typeNames[5] = {"(none)", "LoROM", "HiROM", "ExHiROM", "CX4"};
  printf("Loaded %s rom (%s)\n", typeNames[headers[used].cartType], headers[used].pal ? "PAL" : "NTSC");
  printf("\"%s\"\n", headers[used].name);
  int bankSize = used >= 2 ? 0x10000 : 0x8000; // 0, 1: LoROM, else HiROM
  printf(
    "%s banks: %d, ramsize: %d%s, coprocessor: %x\n",
    bankSize == 0x8000 ? "32K" : "64K", newLength / bankSize, headers[used].chips > 0 ? headers[used].ramSize : 0, (headers[used].hasBattery) ? " (battery-backed)" : "", headers[used].exCoprocessor
  );
  cart_load(
    snes->cart, headers[used].cartType,
    newData, newLength, headers[used].chips > 0 ? headers[used].ramSize : 0,
    headers[used].hasBattery
  );
  // -- cart specific config --
  snes->ramFill = 0x00; // default, 0-fill
  if (!strcmp(headers[used].name, "DEATH BRADE") || !strcmp(headers[used].name, "POWERDRIVE")) {
    snes->ramFill = 0xff;
  }
  if (!strcmp(headers[used].name, "ASHITANO JOE") || !strcmp(headers[used].name, "SUCCESS JOE")) {
    snes->ramFill = 0x3f; // game prefers 0x3f fill
  }
  snes_reset(snes, true); // reset after loading
  snes->palTiming = headers[used].pal; // set region
  free(newData);
  return true;
}

void snes_setButtonState(Snes* snes, int player, int button, bool pressed) {
  // set key in controller
  if(player == 0) {
    if(pressed) {
      snes->input1->currentState |= 1 << button;
    } else {
      snes->input1->currentState &= ~(1 << button);
    }
  } else {
    if(pressed) {
      snes->input2->currentState |= 1 << button;
    } else {
      snes->input2->currentState &= ~(1 << button);
    }
  }
}

void snes_setPixels(Snes* snes, uint8_t* pixelData) {
  // size is 4 (rgba) * 512 (w) * 480 (h)
  ppu_putPixels(snes->ppu, pixelData);
}

void snes_setSamples(Snes* snes, int16_t* sampleData, int samplesPerFrame) {
  // size is 2 (int16) * 2 (stereo) * samplesPerFrame
  // sets samples in the sampleData
  dsp_getSamples(snes->apu->dsp, sampleData, samplesPerFrame);
}

int snes_saveBattery(Snes* snes, uint8_t* data) {
  int size = 0;
  cart_handleBattery(snes->cart, true, data, &size);
  return size;
}

bool snes_loadBattery(Snes* snes, uint8_t* data, int size) {
  return cart_handleBattery(snes->cart, false, data, &size);
}

int snes_saveState(Snes* snes, uint8_t* data) {
  StateHandler* sh = sh_init(true, NULL, 0);
  uint32_t id = 0x4653534c; // 'LSSF' LakeSnes State File
  uint32_t version = stateVersion;
  sh_handleInts(sh, &id, &version, &version, NULL); // second version to be overridden by length
  cart_handleTypeState(snes->cart, sh);
  // save data
  snes_handleState(snes, sh);
  // store
  sh_placeInt(sh, 8, sh->offset);
  if(data != NULL) memcpy(data, sh->data, sh->offset);
  int size = sh->offset;
  sh_free(sh);
  return size;
}

bool snes_loadState(Snes* snes, uint8_t* data, int size) {
  StateHandler* sh = sh_init(false, data, size);
  uint32_t id = 0, version = 0, length = 0;
  sh_handleInts(sh, &id, &version, &length, NULL);
  bool cartMatch = cart_handleTypeState(snes->cart, sh);
  if(id != 0x4653534c || version != stateVersion || length != size || !cartMatch) {
    sh_free(sh);
    return false;
  }
  // load data
  snes_handleState(snes, sh);
  // finish
  sh_free(sh);
  return true;
}

void readHeader(const uint8_t* data, int length, int location, CartHeader* header) {
  // read name, TODO: non-ASCII names?
  for(int i = 0; i < 21; i++) {
    uint8_t ch = data[location + i];
    if(ch >= 0x20 && ch < 0x7f) {
      header->name[i] = ch;
    } else {
      header->name[i] = '.';
    }
  }
  header->name[21] = 0;
  // clean name (strip end space)
  int slen = strlen(header->name);
  while (slen > 0 && header->name[slen-1] == ' ') {
	  header->name[slen-1] = '\0';
	  slen--;
  }
  // read rest
  header->speed = data[location + 0x15] >> 4;
  header->type = data[location + 0x15] & 0xf;
  header->coprocessor = data[location + 0x16] >> 4;
  header->chips = data[location + 0x16] & 0xf;
  header->hasBattery = (header->chips == 0x02 || header->chips == 0x05 || header->chips == 0x06);
  header->romSize = 0x400 << data[location + 0x17];
  header->ramSize = 0x400 << data[location + 0x18];
  header->region = data[location + 0x19];
  header->maker = data[location + 0x1a];
  header->version = data[location + 0x1b];
  header->checksumComplement = (data[location + 0x1d] << 8) + data[location + 0x1c];
  header->checksum = (data[location + 0x1f] << 8) + data[location + 0x1e];
  // read v3 and/or v2
  header->headerVersion = 1;
  if(header->maker == 0x33) {
    header->headerVersion = 3;
    // maker code
    for(int i = 0; i < 2; i++) {
      uint8_t ch = data[location - 0x10 + i];
      if(ch >= 0x20 && ch < 0x7f) {
        header->makerCode[i] = ch;
      } else {
        header->makerCode[i] = '.';
      }
    }
    header->makerCode[2] = 0;
    // game code
    for(int i = 0; i < 4; i++) {
      uint8_t ch = data[location - 0xe + i];
      if(ch >= 0x20 && ch < 0x7f) {
        header->gameCode[i] = ch;
      } else {
        header->gameCode[i] = '.';
      }
    }
    header->gameCode[4] = 0;
    header->flashSize = 0x400 << data[location - 4];
    header->exRamSize = 0x400 << data[location - 3];
    header->specialVersion = data[location - 2];
    header->exCoprocessor = data[location - 1];
  } else if(data[location + 0x14] == 0) {
    header->headerVersion = 2;
    header->exCoprocessor = data[location - 1];
  }
  // get region
  header->pal = (header->region >= 0x2 && header->region <= 0xc) || header->region == 0x11;
  header->cartType = location < 0x9000 ? 1 : 2;
  if(location > 0x400000) header->cartType = 3;
  // get score
  // TODO: check name, maker/game-codes (if V3) for ASCII, more vectors,
  //   more first opcode, rom-sizes (matches?), type (matches header location?)
  int score = 0;
  score += (header->speed == 2 || header->speed == 3) ? 5 : -4;
  score += (header->type <= 3 || header->type == 5) ? 5 : -2;
  score += (header->coprocessor <= 5 || header->coprocessor >= 0xe) ? 5 : -2;
  score += (header->chips <= 6 || header->chips == 9 || header->chips == 0xa) ? 5 : -2;
  score += (header->region <= 0x14) ? 5 : -2;
  score += (header->checksum + header->checksumComplement == 0xffff) ? 8 : -6;
  uint16_t resetVector = data[location + 0x3c] | (data[location + 0x3d] << 8);
  score += (resetVector >= 0x8000) ? 8 : -20;
  // check first opcode after reset
  int opcodeLoc = location + 0x40 - 0x8000 + (resetVector & 0x7fff);
  uint8_t opcode = 0xff;
  if(opcodeLoc < length) {
    opcode = data[opcodeLoc];
  } else {
    score -= 14;
  }
  if(opcode == 0x78 || opcode == 0x18) {
    // sei, clc (for clc:xce)
    score += 6;
  }
  if(opcode == 0x4c || opcode == 0x5c || opcode == 0x9c) {
    // jmp abs, jml abl, stz abs
    score += 3;
  }
  if(opcode == 0x00 || opcode == 0xff || opcode == 0xdb) {
    // brk, sbc alx, stp
    score -= 6;
  }
  header->score = score;
}
