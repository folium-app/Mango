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

Snes* mangoEmulator;

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
    if (!mangoEmulator)
        mangoEmulator = snes_init();
    
    long length = 0;
    uint8_t* file = readFile([url.path UTF8String], &length);
    snes_loadRom(mangoEmulator, file, (int)length);
    free(file);
    
    isPaused = FALSE;
    isRunning = TRUE;
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

-(int16_t *) audioBuffer {
    static std::vector<int16_t> buffer(48000 / (mangoEmulator->palTiming ? 50 : 60));
    snes_setSamples(mangoEmulator, buffer.data(), 48000 / (mangoEmulator->palTiming ? 50 : 60));
    return buffer.data();
}

-(uint8_t *) videoBuffer {
    static std::vector<uint8_t> buffer(512 * 480);
    snes_setPixels(mangoEmulator, buffer.data());
    return buffer.data();
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
        }
    }
    
    return [NSString stringWithCString:headers[used].name encoding:NSUTF8StringEncoding].capitalizedString;
}

-(void) button:(int)button player:(int)player pressed:(BOOL)pressed {
    snes_setButtonState(mangoEmulator, player, button, pressed);
}
@end
