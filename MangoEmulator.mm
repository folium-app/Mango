//
//  MangoEmulator.mm
//  Mango
//
//  Created by Jarrod Norwell on 4/8/2025.
//

#import "MangoEmulator.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <cart.h>
#include <snes.h>

#include <atomic>
#include <condition_variable>
#include <fstream>
#include <iostream>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

struct Object {
    Snes* mangoEmulator;
    SDL_AudioStream* stream;
    std::jthread thread;
    int16_t* ab;
    uint8_t* fb;
} object;

std::atomic<bool> paused;
std::mutex mutex;
std::condition_variable_any cv;

static uint8_t* readFile(const char* name, long* length) {
    FILE* f = fopen(name, "rb");
    if(f == NULL) return NULL;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    static std::vector<uint8_t> buffer(size);
    if(fread(buffer.data(), size, 1, f) != 1) {
        fclose(f);
        return NULL;
    }
    fclose(f);
    *length = size;
    return buffer.data();
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

@implementation MangoEmulator
-(MangoEmulator *) init {
    if (self = [super init]) {
        object.mangoEmulator = snes_init();
    } return self;
}

+(MangoEmulator *) sharedInstance {
    static MangoEmulator *sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(void) insertCartridge:(NSURL *)url {
    long length = 0;
    uint8_t* file = readFile([url.path UTF8String], &length);
    snes_loadRom(object.mangoEmulator, file, (int)length);
    
    object.ab = new int16_t[48000 / (object.mangoEmulator->palTiming ? 50 : 60)];
    object.fb = new uint8_t[512 * 480 * 4];
}

-(void) reset {
    snes_reset(object.mangoEmulator, true);
}

-(void) stop {
    object.thread.request_stop();
    if (object.thread.joinable())
        object.thread.join();
    
    snes_free(object.mangoEmulator);
    
    delete [] object.ab;
    delete [] object.fb;
    
    paused.store(false);
}

-(void) start {
    SDL_SetMainReady();
    SDL_Init(SDL_INIT_AUDIO);
    
    // open audio device
    SDL_AudioSpec spec;
    SDL_zero(spec);
    spec.channels = 2;
    spec.format = SDL_AUDIO_S16;
    spec.freq = 48000;
    
    auto device = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec);
    
    object.stream = SDL_OpenAudioDeviceStream(device, &spec, nil, nil);
    if (object.stream)
        SDL_ResumeAudioStreamDevice(object.stream);
    
    paused.store(false);
    
    object.thread = std::jthread([&](std::stop_token token) {
        using namespace std::chrono;

        const int fps = object.mangoEmulator->palTiming ? 50 : 60;
        const auto frameDuration = duration<double>(1.0 / fps);

        while (!token.stop_requested()) {
            {
                std::unique_lock lock(mutex);
                cv.wait(lock, token, []() {
                    return !paused.load();
                });
                
                if (token.stop_requested())
                    break;
            }
            
            auto frameStart = steady_clock::now();

            snes_runFrame(object.mangoEmulator);
            snes_setSamples(object.mangoEmulator, object.ab, 48000 / fps);
            snes_setPixels(object.mangoEmulator, object.fb);
            
            if (object.ab) {
                auto wantedSamples = 48000 / fps;
                if (SDL_GetAudioStreamQueued(object.stream) <= wantedSamples * 4 * 6) {
                    SDL_PutAudioStreamData(object.stream, object.ab, wantedSamples * 4);
                }
            }

            if (auto buffer = [[MangoEmulator sharedInstance] fb])
                if (object.fb)
                    dispatch_async(dispatch_get_main_queue(), ^{
                        buffer(object.fb);
                    });

            // Limit FPS
            auto frameEnd = steady_clock::now();
            auto elapsed = frameEnd - frameStart;
            if (elapsed < frameDuration)
                std::this_thread::sleep_for(frameDuration - elapsed);
        }
    });
}

-(BOOL) isPaused {
    return paused.load();
}

-(void) pause:(BOOL)pause {
    if (pause)
        paused.store(true);
    else {
        paused.store(false);
        cv.notify_all();
    }
}

-(SNESRomType) type {
    return object.mangoEmulator->palTiming ? SNESRomTypePAL : SNESRomTypeNTSC;
}

-(NSString *) regionForCartridge:(NSURL *)url {
    return [NSString stringWithCString:getSnesRegion([url.path UTF8String]).c_str() encoding:NSUTF8StringEncoding];
}

-(NSString *) titleForCartridge:(NSURL *)url {
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
    snes_setButtonState(object.mangoEmulator, player, button, pressed);
}
@end
