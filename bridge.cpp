//
//  bridge.cpp
//  Mango
//
//  Created by Jarrod Norwell on 2/7/2026.
//

#include "bridge.h"
#include "mesence.h"

#include "Shared/EmuSettings.h"
#include "Shared/MessageManager.h"
#include "Utilities/FolderUtilities.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <mutex>
#include <thread>

#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "Mango-Swift.h"
using namespace Mango;

struct cntnr_m {
    MangoCommon mangoCommon{MangoCommon::init()};
    MangoSystem mangoSystem{MangoSystem::init()};
    
    std::unique_ptr<Emulator> emulator;
    std::unique_ptr<NESInput> input;
    std::unique_ptr<iOSRenderer> renderer;
    std::unique_ptr<iOSSink> sink;
    
    std::condition_variable_any cv;
    std::mutex mutex;
    std::atomic<bool> paused, running;
    std::jthread thread;
    
    uint32_t height, width;
    
    std::filesystem::path mango_path, debugger_path, firmware_path;
    std::filesystem::path hd_packs_path, recent_games_path, saves_path;
    std::filesystem::path save_states_path, screenshots_path, system_data_path;
} cntnr_m;

void mango::print_about(void) {
    printf("Welcome to Mango\n");
    printf("Nintendo Entertainment System emulation provided by MesenCE\n");
}

void mango::initialize_paths(void) {
    auto mangoDirectoryURL{cntnr_m.mangoCommon.getMangoDirectoryURL()};
    if (mangoDirectoryURL.isSome()) {
        auto mango_path{std::filesystem::path{mangoDirectoryURL.get()}};
        
        cntnr_m.mango_path = mango_path;
        cntnr_m.debugger_path = mango_path / "debugger";
        cntnr_m.firmware_path = mango_path / "firmware";
        cntnr_m.hd_packs_path = mango_path / "hd_packs";
        cntnr_m.recent_games_path = mango_path / "recent_games";
        cntnr_m.saves_path = mango_path / "saves";
        cntnr_m.save_states_path = mango_path / "save_states";
        cntnr_m.screenshots_path = mango_path / "screenshots";
        cntnr_m.system_data_path = mango_path / "system_data";
    }
}

void mango::initialize_system(void) {
    auto mm{std::make_unique<iOSMessageManager>()};
    MessageManager::SetOptions(false, true);
    MessageManager::RegisterMessageManager(mm.get());
    
    cntnr_m.emulator = std::make_unique<Emulator>();
    cntnr_m.emulator->Initialize(false);
    
    cntnr_m.input = std::make_unique<NESInput>();
    cntnr_m.renderer = std::make_unique<iOSRenderer>(cntnr_m.emulator, 240, 256);
    cntnr_m.sink = std::make_unique<iOSSink>(cntnr_m.emulator, 48000);
    
    NesConfig nes = cntnr_m.emulator->GetSettings()->GetNesConfig();
    memcpy(nes.UserPalette, nes::kNesPalette2C02, sizeof(nes::kNesPalette2C02));
    nes.IsFullColorPalette = false;
    for (int i = 0; i < sizeof(nes.ChannelVolumes) / sizeof(nes.ChannelVolumes[0]); i++)
        nes.ChannelVolumes[i] = 100;
    nes.NtscOverscan.Left = nes::kNesOverscanLeft;
    nes.PalOverscan.Left = nes::kNesOverscanLeft;
    nes.Port1.Type = ControllerType::NesController;
    cntnr_m.emulator->GetSettings()->SetNesConfig(nes);
}


void mango::destroy_system(void) {
    mango::initialize_system();
}


void mango::insert_disc(std::string path) {
    FolderUtilities::SetHomeFolder(cntnr_m.mango_path.string());
    FolderUtilities::SetFolderOverrides({}, {}, {}, cntnr_m.system_data_path);
    
    cntnr_m.emulator->LoadRom({path}, {});
    cntnr_m.emulator->RegisterInputProvider(cntnr_m.input.get());
}


bool mango::is_paused(bool change, bool set_paused) {
    if (change)
        cntnr_m.paused.store(set_paused);
    
    if (change)
        set_paused ? cntnr_m.emulator->Pause() : cntnr_m.emulator->Resume();
    
    if (change && !set_paused)
        cntnr_m.cv.notify_one();
    
    return cntnr_m.paused.load();
}

bool mango::is_running(bool change, bool set_running) {
    if (change)
        cntnr_m.running.store(set_running);
    return cntnr_m.running.load();
}


void mango::start(void) {
    cntnr_m.thread = std::jthread([&](std::stop_token token) {
        using namespace std::chrono;
        
        const auto frameDuration = duration<double>(1.0 / 60.0);
        
        while (!token.stop_requested()) {
            {
                std::unique_lock lock(cntnr_m.mutex);
                cntnr_m.cv.wait(lock, token, []() {
                    return !cntnr_m.paused.load();
                });
                
                if (token.stop_requested())
                    break;
            }
            
            auto frameStart = steady_clock::now();
            
            std::vector<uint32_t> data{0};
            if (cntnr_m.renderer->GetFrameIfReady(data, cntnr_m.height, cntnr_m.width))
                mango::video_callback(mango::context, data.data(), 0);

            // Limit FPS
            auto frameEnd = steady_clock::now();
            auto elapsed = frameEnd - frameStart;
            if (elapsed < frameDuration)
                std::this_thread::sleep_for(frameDuration - elapsed);
        }
    });
}

void mango::stop(void) {
    cntnr_m.emulator->Stop(false, true);
    
    cntnr_m.thread.request_stop();
    if (cntnr_m.thread.joinable())
        cntnr_m.thread.join();
    
    cntnr_m.paused.store(false);
    cntnr_m.running.store(false);
}


int mango::framebuffer_height(void) {
    return cntnr_m.height;
}

int mango::framebuffer_width(void) {
    return cntnr_m.width;
}


void mango::audio_buffer_callback(mango::AudioVideoBufferCallback callback) {
    mango::audio_callback = callback;
}

void mango::video_buffer_callback(mango::AudioVideoBufferCallback callback) {
    mango::video_callback = callback;
}


void mango::press_button(uint32_t button) {
    cntnr_m.input->keys |= button;
}

void mango::release_button(uint32_t button) {
    cntnr_m.input->keys &= ~button;
}


void mango::set_context(void* context) {
    mango::context = context;
}
