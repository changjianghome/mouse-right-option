import Cocoa
import ApplicationServices

print("AXIsProcessTrusted:", AXIsProcessTrusted())
let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue) | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
let cb: CGEventTapCallBack = { proxy, type, event, refcon in
    let btn = event.getIntegerValueField(.mouseEventButtonNumber)
    print("got type=\(type.rawValue) button=\(btn)")
    return Unmanaged.passUnretained(event)
}
if let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: cb, userInfo: nil) {
    print("TAP_OK")
    let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    CFRunLoopRunInMode(.defaultMode, 1.0, false)
} else {
    print("TAP_FAIL_NO_PERMISSION")
}
