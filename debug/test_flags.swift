import Cocoa
import ApplicationServices

// 观察真实按键事件（System Events 发出的）是否被加了 Option 标记
var hits: [String] = []
let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let alt = event.flags.contains(.maskAlternate)
    hits.append("keycode=\(key) alt=\(alt)")
    return Unmanaged.passUnretained(event)
}
// tail 位置：在我们的 app 改写之后观察
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                                  options: .listenOnly, eventsOfInterest: mask,
                                  callback: cb, userInfo: nil) else {
    print("TAP_FAIL"); exit(1)
}
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

func pump(_ s: Double) { CFRunLoopRunInMode(.defaultMode, s, false) }

func side(_ down: Bool) {
    let esrc = CGEventSource(stateID: .hidSystemState)!
    let type: CGEventType = down ? .otherMouseDown : .otherMouseUp
    let e = CGEvent(mouseEventSource: esrc, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    e.setIntegerValueField(.mouseEventButtonNumber, value: 3)
    e.post(tap: .cghidEventTap)
    pump(0.4)
}

func typeA() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", "tell application \"System Events\" to keystroke \"a\""]
    p.standardOutput = Pipe()
    p.standardError = Pipe()
    try? p.run()
    p.waitUntilExit()
    pump(0.6)
}

print("基线：不按侧键，输入 a")
typeA()
print("实验：按住侧键，输入 a")
side(true)
typeA()
side(false)
print("收尾：松开后输入 a")
typeA()

print("捕获：")
for (i, h) in hits.enumerated() { print("  [\(i)] \(h)") }
let ok = hits.count >= 3
    && hits[0].hasSuffix("false")
    && hits[1].hasSuffix("true")
    && hits[2].hasSuffix("false")
print(ok ? "VERIFY_PASS：真实按键确实带上了 Option" : "VERIFY_FAIL")
