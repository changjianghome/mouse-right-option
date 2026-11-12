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
        usleep(100000)
    }
}

func probe(_ name: String, key: CGKeyCode, tap: CGEventTapLocation, useType: Bool, src: CGEventSource?) {
    clearAlt()
    let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)!
    if useType { e.type = .flagsChanged }
    e.flags = CGEventSource.flagsState(.combinedSessionState).union(.maskAlternate)
    e.post(tap: tap)
    usleep(400000)
    print("\(name.padding(toLength: 42, withPad: " ", startingAt: 0)) alt=\(alt())")
    // release
    let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)!
    up.type = .flagsChanged
    up.flags = []
    up.post(tap: tap)
    usleep(200000)
}

let hid = CGEventSource(stateID: .hidSystemState)
let comb = CGEventSource(stateID: .combinedSessionState)

print("== keycode 58 (左Option) ==")
probe("58 flagsChanged cghid", key: 58, tap: .cghidEventTap, useType: true, src: hid)
probe("58 flagsChanged cgSession", key: 58, tap: .cgSessionEventTap, useType: true, src: hid)
probe("58 flagsChanged cgAnnotated", key: 58, tap: .cgAnnotatedSessionEventTap, useType: true, src: hid)
probe("58 plain cghid", key: 58, tap: .cghidEventTap, useType: false, src: hid)

print("== keycode 61 (右Option) ==")
probe("61 flagsChanged cghid", key: 61, tap: .cghidEventTap, useType: true, src: hid)
probe("61 flagsChanged cgAnnotated", key: 61, tap: .cgAnnotatedSessionEventTap, useType: true, src: hid)

print("== combinedSessionState source ==")
probe("58 flagsChanged cghid combSrc", key: 58, tap: .cghidEventTap, useType: true, src: comb)
probe("61 flagsChanged cghid combSrc", key: 61, tap: .cghidEventTap, useType: true, src: comb)

clearAlt()
print("end alt=\(alt())")
