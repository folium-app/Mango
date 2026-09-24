//
//  Mango.swift
//  Mango
//
//  Created by Jarrod Norwell on 2/9/2026.
//

import Foundation

public enum MangoButton : UInt32 {
    case a = 0x1
    case b = 0x2
    case select = 0x4
    case start = 0x8
    case right = 0x10
    case left = 0x20
    case up = 0x40
    case down = 0x80
    
    var uint32: UInt32 { rawValue }
}

public class MangoCommon {
    public init() {}
    
    public static var documentDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    public static var mangoDirectoryURL: String? {
        if let documentDirectoryURL {
            documentDirectoryURL.appending(component: "Mango").path
        } else {
            nil
        }
    }
}

public actor MangoSystem {
    private var fileManager: FileManager = .default
    
    public init() {}
    
    public func printAbout() {
        mango.print_about()
    }
    
    public func initializePaths() {
        mango.initialize_paths()
    }
    
    public func initializeSystem() {
        mango.initialize_system()
    }
    
    public func destroySystem() {
        mango.destroy_system()
    }
    
    public func insertDisc(at url: URL) {
        mango.insert_disc(std.string(url.path))
    }
    
    public func set(change: Bool = false, isRunning: Bool = false) {
        if change {
            running = isRunning
        }
    }
    
    public var running: Bool {
        get {
            mango.is_running()
        }
        set {
            mango.is_running(true, newValue)
        }
    }
    
    public func set(change: Bool = false, isPaused: Bool = false) {
        if change {
            paused = isPaused
        }
    }
    
    public var paused: Bool {
        get {
            mango.is_paused()
        }
        set {
            mango.is_paused(true, newValue)
        }
    }
    
    
    public func start() {
        mango.start()
    }
    
    public func stop() {
        mango.stop()
    }
    
    
    public var framebufferHeight: Int32 {
        mango.framebuffer_height()
    }
    
    public var framebufferWidth: Int32 {
        mango.framebuffer_width()
    }
    
    
    public nonisolated func press(button: MangoButton) {
        mango.press_button(button.uint32)
    }
    
    public nonisolated func release(button: MangoButton) {
        mango.release_button(button.uint32)
    }
    
    
    public nonisolated func audioBuffer(callback: mango.AudioVideoBufferCallback) {
        mango.audio_buffer_callback(callback)
    }
    
    public nonisolated func videoBuffer(callback: mango.AudioVideoBufferCallback) {
        mango.video_buffer_callback(callback)
    }
    
    
    public func setContext(context: UnsafeMutableRawPointer) {
        mango.set_context(context)
    }
    
    
    public nonisolated func boxartURLString(for url: URL) -> String? {
        let title: String = url.deletingPathExtension().lastPathComponent

        return "https://raw.githubusercontent.com/libretro/libretro-thumbnails/refs/heads/master/Nintendo - Nintendo Entertainment System/Named_Boxarts/\(title).png"
    }
}
