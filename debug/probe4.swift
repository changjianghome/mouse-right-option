import Cocoa
import ApplicationServices

var results: [String] = []

// 监听后续鼠标事件，看它是否带着 Option 标记
let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    results.append("mouseDown btn=\(btn) alt=\(event.flags.contains(.maskAlternate))")
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
let pos = CGEvent(source: nil)?.location ?? .zero

func pump(_ s: Double) { CFRunLoopRunInMode(.defaultMode, s, false) }

func click(_ btn: Int64) {
    let d = CGEvent(mouseEventSource: esrc, mouseType: .otherMouseDown, mouseCursorPosition: pos, mouseButton: .center)!
    d.setIntegerValueField(.mouseEventButtonNumber, value: btn)
    d.post(tap: .cghidEventTap)
    pump(0.25)
    let u = CGEvent(mouseEventSource: esrc, mouseType: .otherMouseUp, mouseCursorPosition: pos, mouseButton: .center)!
    u.setIntegerValueField(.mouseEventButtonNumber, value: btn)
    u.post(tap: .cghidEventTap)
    pump(0.25)
}

// 对照组：不按 Option
click(5)
// 注入右 Option 按下
let down = CGEvent(keyboardEventSource: esrc, virtualKey: 61, keyDown: true)!
down.type = .flagsChanged
down.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
down.post(tap: .cghidEventTap)
pump(0.3)
// 实验组：应带 Option
click(5)
// 释放
let up = CGEvent(keyboardEventSource: esrc, virtualKey: 61, keyDown: false)!
up.type = .flagsChanged
up.flags = CGEventSource.flagsState(.combinedSessionState).subtracting(.maskAlternate)
up.post(tap: .cghidEventTap)
pump(0.3)
// 释放后再点一次
click(5)

print("结果：")
for r in results { print("  \(r)") }
