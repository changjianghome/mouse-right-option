import Cocoa
import ApplicationServices

// 用 listenOnly tap 看注入的 flagsChanged 是否真的进入事件流
var seen: [String] = []

let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
         | CGEventMask(1 << CGEventType.keyDown.rawValue)

let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    let hasAlt = flags.contains(.maskAlternate)
    let name = type == .flagsChanged ? "flagsChanged" : "keyDown"
    seen.append("\(name) key=\(key) alt=\(hasAlt)")
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .listenOnly, eventsOfInterest: mask,
                                  callback: cb, userInfo: nil) else {
    print("TAP_FAIL"); exit(1)
}
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

let esrc = CGEventSource(stateID: .hidSystemState)!

// 注入右 Option 按下
let down = CGEvent(keyboardEventSource: esrc, virtualKey: 61, keyDown: true)!
down.type = .flagsChanged
down.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
down.post(tap: .cghidEventTap)

CFRunLoopRunInMode(.defaultMode, 0.3, false)

// 再注入一个普通键 a
let a = CGEvent(keyboardEventSource: esrc, virtualKey: 0, keyDown: true)!
a.post(tap: .cghidEventTap)

CFRunLoopRunInMode(.defaultMode, 0.3, false)

let up = CGEvent(keyboardEventSource: esrc, virtualKey: 61, keyDown: false)!
up.type = .flagsChanged
up.flags = []
up.post(tap: .cghidEventTap)

CFRunLoopRunInMode(.defaultMode, 0.3, false)

print("捕获到的事件：")
for s in seen { print("  \(s)") }
if seen.isEmpty { print("  （无，注入事件没有进入流）") }

// 清理：再发一次空 flags
let c = CGEvent(source: nil)!
c.type = .flagsChanged
c.flags = []
c.post(tap: .cghidEventTap)
