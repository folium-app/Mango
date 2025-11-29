//
//  Mango.swift
//  Mango
//
//  Created by Jarrod Norwell on 4/8/2025.
//

public enum SNESButton : Int32 {
    case b = 0
    case y = 1
    case select = 2
    case start = 3
    case up = 4
    case down = 5
    case left = 6
    case right = 7
    case a = 8
    case x = 9
    case l = 10
    case r = 11
}

public actor Mango {
    private var emulator: MangoEmulator = .shared()
    
    public init() {}
    
    public func insert(_ cartridge: URL) {
        emulator.insert(cartridge)
    }
    
    public func start() {
        emulator.start()
    }
    
    public func stop() {
        emulator.stop()
    }
    
    public var isPaused: Bool {
        get {
            emulator.isPaused()
        }
        set {
            pause(newValue)
        }
    }
    
    public func pause(_ pause: Bool) {
        emulator.pause(pause)
    }
    
    public var type: SNESRomType {
        emulator.type()
    }
    
    public func framebuffer(_ buffer: @escaping (UnsafeMutablePointer<UInt8>) -> Void) {
        emulator.fb = buffer
    }
    
    public func region(from url: URL) -> String { emulator.region(from: url) }
    public func title(at url: URL) -> String { emulator.title(from: url) }
    
    public func button(button: SNESButton, player: Int, pressed: Bool) {
        emulator.button(button.rawValue, player: Int32(player), pressed: pressed)
    }
}
