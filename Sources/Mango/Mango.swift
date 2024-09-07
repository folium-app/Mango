// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import MangoObjC

public struct Mango : @unchecked Sendable {
    public static let shared = Mango()
    
    fileprivate let mangoObjC = MangoObjC.shared()
    
    public func insertCartridge(from url: URL) {
        mangoObjC.insert(cartridge: url)
    }
    
    public func reset() {
        mangoObjC.reset()
    }
    
    public func stop() {
        mangoObjC.stop()
    }
    
    public func step() {
        mangoObjC.step()
    }
    
    public func paused() -> Bool {
        mangoObjC.paused()
    }
    
    public func running() -> Bool {
        mangoObjC.running()
    }
    
    public func togglePaused() {
        mangoObjC.togglePaused()
    }
    
    public func type() -> SNESRomType {
        mangoObjC.type()
    }
    
    public func audioBuffer() -> UnsafeMutablePointer<Int16> {
        mangoObjC.audioBuffer()
    }
    
    public func videoBuffer() -> UnsafeMutablePointer<UInt8> {
        mangoObjC.videoBuffer()
    }
    
    public func titleForCartridge(at url: URL) -> String {
        mangoObjC.titleForCartridge(at: url)
    }
    
    public func button(button: Int32, player: Int32, pressed: Bool) {
        mangoObjC.button(button, player: player, pressed: pressed)
    }
}
