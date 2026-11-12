import Cocoa
import ApplicationServices

// 按住侧键(Button 3) + 真实按键 a，看前台编辑器是否输入 å（Option+a）
let esrc = CGEventSource(stateID: .hidSystemState)!

func side(_ down: Bool) {
    let type: CGEventType = down ? .otherMouseDown : .otherMouseUp
    let e = CGEvent(mouseEventSource: esrc, mouseType: type, mouseCursorPosition: .zero, mouseButton: .center)!
    e.setIntegerValueField(.mouseEventButtonNumber, value: 3)
    e.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.4)
}

func run(_ script: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    p.arguments = ["-e", script]
    let out = Pipe()
    p.standardOutput = out
    p.standardError = Pipe()
    try? p.run()
    p.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

print("1) 准备 TextEdit 文档")
_ = run("""
tell application "TextEdit"
    activate
    if (count of documents) = 0 then make new document
end tell
delay 0.8
""")

print("2) 清空文档")
_ = run("""
tell application "TextEdit"
    set text of document 1 to ""
end tell
delay 0.3
""")

print("3) 按住侧键 + 真实输入字母 a")
side(true)
let typed = run("""
tell application "System Events"
    keystroke "a"
end tell
delay 0.4
""")
_ = typed
side(false)

Thread.sleep(forTimeInterval: 0.6)

let result = run("""
tell application "TextEdit"
    get text of document 1
end tell
""")

print("4) 文档内容 = 「\(result)」")
if result == "å" {
    print("VERIFY_PASS：侧键确实起到了右 Option 的作用（a 变成了 å）")
} else if result == "a" {
    print("VERIFY_FAIL：输入的是普通 a，Option 没生效")
} else {
    print("VERIFY_UNKNOWN：内容异常，需要人工核对")
}
