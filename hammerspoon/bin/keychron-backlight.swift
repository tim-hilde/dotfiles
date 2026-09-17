// Controls the Keychron K2 Pro backlight over the VIA raw-HID interface
// (vendor 0x3434, usage page 0xFF60, usage 0x61, 32-byte reports).
//
// Build: swiftc -O -o ~/.local/bin/keychron-backlight hammerspoon/bin/keychron-backlight.swift
// Usage: keychron-backlight <on|off|0-255>

import Foundation
import IOKit.hid

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: keychron-backlight <on|off|0-255>", 64)
}

let level: UInt8
switch CommandLine.arguments[1] {
case "on":
    level = 255
case "off":
    level = 0
case let arg:
    guard let value = UInt8(arg) else {
        fail("invalid level: \(arg)", 64)
    }
    level = value
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let match: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x3434,
    kIOHIDDeviceUsagePageKey as String: 0xFF60,
    kIOHIDDeviceUsageKey as String: 0x61,
]
IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)

guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
    fail("cannot open HID manager", 2)
}

var device: IOHIDDevice?
for _ in 0..<10 where device == nil {
    if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
        device = devices.first
    }
    if device == nil {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}

guard let keyboard = device else {
    fail("Keychron not found (connected? cable mode?)", 1)
}

guard IOHIDDeviceOpen(keyboard, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
    fail("cannot open keyboard", 2)
}

var report = [UInt8](repeating: 0, count: 32)
report[0] = 0x07  // VIA command: set value
report[1] = 0x80  // channel: backlight brightness
report[2] = level

let result = report.withUnsafeBufferPointer {
    IOHIDDeviceSetReport(keyboard, kIOHIDReportTypeOutput, 0, $0.baseAddress!, report.count)
}

guard result == kIOReturnSuccess else {
    fail("report failed: 0x\(String(result, radix: 16))", 2)
}
