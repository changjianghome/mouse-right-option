// 鼠标按键 → 指定键盘按键（默认 F3，用于触发微信输入法语音输入）
// 极简菜单栏工具：按住指定鼠标键 = 按住目标按键。

import Cocoa
import ApplicationServices

// 要发送的目标按键，F3 = 99
let kTargetKeyCode: CGKeyCode = 99
let kDefaultButton: Int64 = 3

func logLine(_ text: String) {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/MouseRightOption.log")
    let stamp = ISO8601DateFormatter().string(from: Date())
    guard let data = "\(stamp) \(text)\n".data(using: .utf8) else { return }
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    } else {
        try? data.write(to: url)
    }
}

final class Controller: NSObject, NSMenuDelegate {

    static let shared = Controller()

    private let defaults = UserDefaults.standard
    private var boundButton: Int64
    private var enabled: Bool
    private var isBinding = false

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var permissionItem: NSMenuItem!
    private var stateItem: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var hintPanel: NSPanel?
    private var hintLabel: NSTextField?
    private var permissionTimer: Timer?

    override init() {
        let stored = defaults.object(forKey: "boundButton") as? Int
        boundButton = Int64(stored ?? Int(kDefaultButton))
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        super.init()
    }

    // MARK: - 启动

    func start() {
        logLine("APP_START trusted=\(AXIsProcessTrusted()) key=\(kTargetKeyCode) bound=\(boundButton) enabled=\(enabled)")
        setupStatusItem()
        refreshMenu()
        promptPermissionIfNeeded()
        installTap()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.tap == nil && AXIsProcessTrusted() {
                logLine("PERMISSION_GRANTED retry")
                self.installTap()
                self.refreshMenu()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "鼠标按键映射")
            img?.isTemplate = true
            button.image = img
            button.toolTip = "鼠标 \(boundButton) → F3"
        }

        menu = NSMenu()
        menu.delegate = self

        permissionItem = NSMenuItem(title: "需要辅助功能权限（点击打开设置）",
                                    action: #selector(openPermissionSettings), keyEquivalent: "")
        permissionItem.target = self
        permissionItem.isHidden = true
        menu.addItem(permissionItem)
        menu.addItem(NSMenuItem.separator())

        stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        let rebind = NSMenuItem(title: "重新绑定鼠标键…", action: #selector(startBinding), keyEquivalent: "")
        rebind.target = self
        menu.addItem(rebind)

        toggleItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        let trusted = AXIsProcessTrusted()
        permissionItem.isHidden = trusted

        if !trusted {
            stateItem.title = "状态：等待授权"
        } else if isBinding {
            stateItem.title = "请按一下要绑定的鼠标键…"
        } else if enabled {
            stateItem.title = "状态：已开启（\(buttonName(boundButton)) → F3）"
        } else {
            stateItem.title = "状态：已暂停"
        }
        toggleItem.title = enabled ? "暂停映射" : "开启映射"
        statusItem.button?.appearsDisabled = !trusted
    }

    private func buttonName(_ n: Int64) -> String {
        switch n {
        case 0: return "左键"
        case 1: return "右键"
        case 2: return "中键"
        case 3: return "第 4 键"
        case 4: return "第 5 键（侧键）"
        case 5: return "第 6 键"
        default: return "Button \(n)"
        }
    }

    // MARK: - 权限

    private func promptPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - 事件监听

    private func installTap() {
        guard tap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let mask = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)

        let info = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<Controller>.fromOpaque(refcon).takeUnretainedValue()
            return controller.handle(type: type, event: event)
        }

        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                              place: .headInsertEventTap,
                                              options: .defaultTap,
                                              eventsOfInterest: mask,
                                              callback: callback,
                                              userInfo: info) else {
            logLine("TAP_FAILED (no permission)")
            return
        }
        tap = created
        let source = CFMachPortCreateRunLoopSource(nil, created, 0)
        tapSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        logLine("TAP_INSTALLED bound=\(boundButton) enabled=\(enabled)")
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .otherMouseDown || type == .otherMouseUp else {
            return Unmanaged.passUnretained(event)
        }

        let number = event.getIntegerValueField(.mouseEventButtonNumber)

        if isBinding, type == .otherMouseDown {
            boundButton = number
            defaults.set(Int(number), forKey: "boundButton")
            logLine("BOUND button=\(number)")
            isBinding = false
            DispatchQueue.main.async { self.finishBinding() }
            return nil
        }

        guard enabled, number == boundButton else { return Unmanaged.passUnretained(event) }

        let down = (type == .otherMouseDown)
        sendKey(down: down)
        logLine("SIDE \(down ? "DOWN" : "UP  ") button=\(number) -> F3 \(down ? "down" : "up")")
        return nil
    }

    /// 发送目标按键（F3）
    private func sendKey(down: Bool) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: kTargetKeyCode,
                                  keyDown: down) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    // MARK: - 绑定流程

    @objc private func startBinding() {
        guard AXIsProcessTrusted() else {
            openPermissionSettings()
            return
        }
        isBinding = true
        showHint("请按一下要绑定的鼠标键…")
        refreshMenu()
    }

    private func finishBinding() {
        showHint("已绑定：\(buttonName(boundButton))")
        refreshMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.hideHint()
        }
    }

    private func showHint(_ text: String) {
        if hintPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered,
                                defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.hasShadow = true
            panel.ignoresMouseEvents = true

            let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 110))
            container.wantsLayer = true
            container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
            container.layer?.cornerRadius = 16
            container.layer?.borderWidth = 1
            container.layer?.borderColor = NSColor.separatorColor.cgColor
            panel.contentView = container

            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 20, y: 40, width: 320, height: 30)
            label.alignment = .center
            label.font = NSFont.systemFont(ofSize: 17, weight: .medium)
            label.textColor = .labelColor
            container.addSubview(label)

            hintLabel = label
            hintPanel = panel
        }

        hintLabel?.stringValue = text

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            hintPanel?.setFrameOrigin(NSPoint(x: f.midX - 180, y: f.maxY - 180))
        }
        hintPanel?.orderFrontRegardless()
    }

    private func hideHint() {
        hintPanel?.orderOut(nil)
    }

    // MARK: - 开关

    @objc private func toggleEnabled() {
        enabled.toggle()
        defaults.set(enabled, forKey: "enabled")
        refreshMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Controller.shared.start()
app.run()
