import Cocoa
import ApplicationServices

func alt() -> Bool { CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate) }
func clearAlt() {
    for _ in 0..<2 {
        let e = CGEvent(source: nil)!
        e.type = .flagsChanged
        e.flags = []
        e.setIntegerValueField(.keyboardEventKeycode, value: 61)
        e.post(tap: .cghidEventTap)
        usleep(120000)
    }
}

let src = CGEventSource(stateID: .hidSystemState)!

// 方法 A：keyboardEventSource + 改 type
clearAlt()
let a = CGEvent(keyboardEventSource: src, virtualKey: 61, keyDown: true)!
a.type = .flagsChanged
a.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
a.post(tap: .cghidEventTap)
usleep(500000)
print("A keyboardEventSource+type:  alt=\(alt())")

// 方法 B：CGEvent(source:) + keycode + flags
clearAlt()
let b = CGEvent(source: nil)!
b.type = .flagsChanged
b.setIntegerValueField(.keyboardEventKeycode, value: 61)
b.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
b.post(tap: .cghidEventTap)
usleep(500000)
print("B CGEvent(source:)+keycode:  alt=\(alt())")

// 方法 C：直接用 keyDown 不改 type
clearAlt()
let c = CGEvent(keyboardEventSource: src, virtualKey: 61, keyDown: true)!
c.flags = .maskAlternate
c.post(tap: .cghidEventTap)
usleep(500000)
print("C plain keyDown:             alt=\(alt())")
let c2 = CGEvent(keyboardEventSource: src, virtualKey: 61, keyDown: false)!
c2.flags = []
c2.post(tap: .cghidEventTap)
usleep(300000)

// 方法 D：source 用 combinedSessionState
clearAlt()
let src2 = CGEventSource(stateID: .combinedSessionState)!
let d = CGEvent(keyboardEventSource: src2, virtualKey: 61, keyDown: true)!
d.type = .flagsChanged
d.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
d.post(tap: .cgSessionEventTap)
usleep(500000)
print("D combinedSession+cgSession: alt=\(alt())")

clearAlt()
print("cleanup done alt=\(alt())")
