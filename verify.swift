import Cocoa
import ApplicationServices

// 验证：按住侧键期间，真实流中的事件是否被加上 Option 标记
// 用 mouseMoved 验证，避免真打字污染输入框
let bound = Int64(CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 3)

var log: [String] = []
let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)

// tail 位置：确保在我们的 app 改写之后才看到事件
let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    log.append("mouseMoved alt=\(event.flags.contains(.maskAlternate))")
    return Unmanaged.passUnretained(event)
}
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                                  options: .listenOnly, eventsOfInterest: mask,
                                  callback: cb, userInfo: nil) else {
    print("TAP_FAIL"); exit(1)
}
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

let esrc = CGEventSource(stateID: .hidSystemState)!
func pump(_ s: Double) { CFRunLoopRunInMode(.defaultMode, s, false) }
func move() {
    let p = CGEvent(source: nil)?.location ?? .zero
    let e = CGEvent(mouseEventSource: esrc, mouseType: .mouseMoved,
                    mouseCursorPosition: CGPoint(x: p.x + 1, y: p.y), mouseButton: .left)!
    e.post(tap: .cghidEventTap)
    pump(0.25)
}
func side(_ down: Bool) {
    let type: CGEventType = down ? .otherMouseDown : .otherMouseUp
    let e = CGEvent(mouseEventSource: esrc, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    e.setIntegerValueField(.mouseEventButtonNumber, value: bound)
    e.post(tap: .cghidEventTap)
    pump(0.3)
}

move()              // 基线
side(true)          // 按住侧键
move()              // 应带 Option
side(false)         // 松开
move()              // 应恢复

print("观测：")
for (i, r) in log.enumerated() { print("  [\(i)] \(r)") }
let ok = log.count >= 3
    && log[0].hasSuffix("false")
    && log[1].hasSuffix("true")
    && log[2].hasSuffix("false")
print(ok ? "VERIFY_PASS：按住侧键期间事件带 Option，松开恢复" : "VERIFY_FAIL")
exit(ok ? 0 : 2)
