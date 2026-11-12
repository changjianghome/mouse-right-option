# 调试与探测脚本（非交付件）

这些是排查问题时写的探测程序，保留作参考：

| 文件 | 用途 |
|---|---|
| `tapcheck.swift` | 检查是否有辅助功能权限、能否创建事件监听 |
| `probe.swift` / `probe2.swift` | 测试用 CGEvent 发送 Option 修饰键的各种写法 |
| `probe3.swift` | 用 listenOnly 监听确认注入的 flagsChanged 是否进入事件流 |
| `probe4.swift` | 验证注入 Option 后，后续鼠标事件是否带 Option 标记 |
| `btnwatch.swift` | 监听真实输入，确认鼠标侧键实际发出的按钮号 |
| `test_flags.swift` | 检查真实按键事件是否被加上 Option |
| `test_input.swift` | 用 TextEdit 验证 Option+a 是否输出 å |

结论：CGEvent 合成的修饰键事件不满足微信输入法（它只认硬件级按键），
最终采用「侧键 → 发送普通按键 F3」的方案。
