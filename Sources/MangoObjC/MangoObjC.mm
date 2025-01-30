//
//  MangoObjC.mm
//  Mango
//
//  Created by Jarrod Norwell on 8/8/2024.
//

#import "MangoObjC.h"

#include "cart.h"
#include "snes.h"

#include <memory>
#include <vector>
#include <iostream>
#include <fstream>
#include <stdexcept>

Snes* mangoEmulator;
int16_t* ab;
uint8_t* fb = new uint8_t[512 * 480 * 4];

static uint8_t* readFile(const char* name, long* length) {
    FILE* f = fopen(name, "rb");
    if(f == NULL) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    uint8_t* buffer = new uint8_t[size];
    if(fread(buffer, size, 1, f) != 1) {
        fclose(f);
        return NULL;
    }
    fclose(f);
    *length = size;
    return buffer;
}

std::string getSnesRegion(const std::string& romFilePath) {
    // SNES ROM region byte offsets
    const size_t LoROMOffset = 0xFFD9;
    const size_t HiROMOffset = 0x7FD9;

    std::ifstream romFile(romFilePath, std::ios::binary);
    if (!romFile.is_open()) {
        throw std::runtime_error("Failed to open the SNES ROM file");
    }

    // Determine file size
    romFile.seekg(0, std::ios::end);
    size_t fileSize = romFile.tellg();
    romFile.seekg(0, std::ios::beg);

    // Read the region byte
    uint8_t regionByte;
    if (fileSize > LoROMOffset) {
        romFile.seekg(LoROMOffset);
        romFile.read(reinterpret_cast<char*>(&regionByte), 1);
    } else if (fileSize > HiROMOffset) {
        romFile.seekg(HiROMOffset);
        romFile.read(reinterpret_cast<char*>(&regionByte), 1);
    } else {
        throw std::runtime_error("ROM file size is too small to contain a valid SNES header");
    }

    // Interpret the region code
    switch (regionByte) {
        case 0x00:
            return "Japan";
        case 0x01:
            return "USA";
        case 0x02:
            return "Europe";
        case 0x03:
            return "Sweden";
        case 0x04:
            return "Finland";
        case 0x05:
            return "Denmark";
        case 0x06:
            return "France";
        case 0x07:
            return "Netherlands";
        case 0x08:
            return "Spain";
        case 0x09:
            return "Germany";
        case 0x0A:
            return "Italy";
        case 0x0B:
            return "Hong Kong";
        case 0x0C:
            return "Indonesia";
        case 0x0D:
            return "South Korea";
        default:
            return "USA";
    }
}

@implementation MangoObjC
-(MangoObjC *) init {
    if (self = [super init]) {
        mangoEmulator = snes_init();
    } return self;
}

+(MangoObjC *) sharedInstance {
    static MangoObjC *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) insertCartridge:(NSURL *)url {
    long length = 0;
    uint8_t* file = readFile([url.path UTF8String], &length);
    snes_loadRom(mangoEmulator, file, (int)length);
    
    isPaused = FALSE;
    isRunning = TRUE;
    
    ab = new int16_t[48000 / (mangoEmulator->palTiming ? 50 : 60)];
}

-(void) reset {
    snes_reset(mangoEmulator, true);
}

-(void) stop {
    isPaused = TRUE;
    isRunning = FALSE;
    snes_free(mangoEmulator);
}

-(void) step {
    snes_runFrame(mangoEmulator);
}

-(BOOL) paused {
    return isPaused;
}

-(BOOL) running {
    return isRunning;
}

-(void) togglePaused {
    isPaused = !isPaused;
}

-(SNESRomType) type {
    return mangoEmulator->palTiming ? SNESRomTypePAL : SNESRomTypeNTSC;
}

-(int16_t* _Nullable) audioBuffer {
    snes_setSamples(mangoEmulator, ab, 48000 / (mangoEmulator->palTiming ? 50 : 60));
    if (ab)
        return ab;
    else
        return nullptr;
}

-(uint8_t* _Nullable) videoBuffer {
    snes_setPixels(mangoEmulator, fb);
    if (fb)
        return fb;
    else
        return nullptr;
}

-(NSString *) regionForCartridgeAtURL:(NSURL *)url {
    return [NSString stringWithCString:getSnesRegion([url.path UTF8String]).c_str() encoding:NSUTF8StringEncoding];
}

-(NSString *) titleForCartridgeAtURL:(NSURL *)url {
    CartHeader headers[6]{};
    long length = 0;
    uint8_t* file = readFile([url.path UTF8String], &length);
    
    for(int i = 0; i < 6; i++) {
        headers[i].score = -50;
    }
    
    if(length >= 0x8000)
        readHeader(file, (int)length, 0x7fc0, &headers[0]); // lorom
    if(length >= 0x8200)
        readHeader(file, (int)length, 0x81c0, &headers[1]); // lorom + header
    if(length >= 0x10000)
        readHeader(file, (int)length, 0xffc0, &headers[2]); // hirom
    if(length >= 0x10200)
        readHeader(file, (int)length, 0x101c0, &headers[3]); // hirom + header
    if(length >= 0x410000)
        readHeader(file, (int)length, 0x40ffc0, &headers[4]); // exhirom
    if(length >= 0x410200)
        readHeader(file, (int)length, 0x4101c0, &headers[5]); // exhirom + header
    
    free(file);
    
    int max = 0;
    int used = 0;
    for (int i = 5; i >= 0; i--) {
        if(headers[i].score > max) {
            max = headers[i].score;
            used = i;
            break;
        }
    }
    
    return [NSString stringWithCString:headers[used].name encoding:NSUTF8StringEncoding].capitalizedString;
}

-(void) button:(int)button player:(int)player pressed:(BOOL)pressed {
    snes_setButtonState(mangoEmulator, player, button, pressed);
}
@end
