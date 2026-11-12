import Cocoa
import ApplicationServices

// 侦测真实输入：鼠标按钮 + 键盘事件，判断侧键到底是鼠标键还是模拟键盘键
let path = "/tmp/btnwatch.log"
FileManager.default.createFile(atPath: path, contents: nil)
var gFH: FileHandle = FileHandle(forWritingAtPath: path) ?? FileHandle.nullDevice

func w(_ s: String) {
    let t = DateFormatter()
    t.dateFormat = "HH:mm:ss.SSS"
    let line = "\(t.string(from: Date())) \(s)\n"
    gFH.seekToEndOfFile()
    gFH.write(line.data(using: .utf8)!)
}

let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .leftMouseDown, .rightMouseDown, .keyDown, .keyUp, .flagsChanged]
let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }

let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let name: String
    switch type {
    case .otherMouseDown: name = "OTHER_MOUSE_DOWN"
    case .otherMouseUp: name = "OTHER_MOUSE_UP"
    case .leftMouseDown: name = "LEFT_DOWN"
    case .rightMouseDown: name = "RIGHT_DOWN"
    case .keyDown: name = "KEY_DOWN"
    case .keyUp: name = "KEY_UP"
    case .flagsChanged: name = "FLAGS_CHANGED"
    default: name = "T\(type.rawValue)"
    }
    let alt = event.flags.contains(.maskAlternate)
    let cmd = event.flags.contains(.maskCommand)
    let shift = event.flags.contains(.maskShift)
    let ctrl = event.flags.contains(.maskControl)
    if type == .otherMouseDown || type == .otherMouseUp {
        w("\(name) button=\(btn) alt=\(alt)")
    } else if type == .flagsChanged {
        w("\(name) keycode=\(key) alt=\(alt) cmd=\(cmd)")
    } else if type == .keyDown || type == .keyUp {
        w("\(name) keycode=\(key) alt=\(alt) cmd=\(cmd) shift=\(shift) ctrl=\(ctrl)")
    } else {
        w("\(name) button=\(btn)")
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .listenOnly, eventsOfInterest: mask,
                                  callback: cb, userInfo: nil) else {
    w("TAP_FAIL")
    exit(1)
}
let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
w("WATCH_START 监听 240 秒")

let end = Date().addingTimeInterval(240)
while Date() < end {
    CFRunLoopRunInMode(.defaultMode, 0.3, false)
}
w("WATCH_END")
