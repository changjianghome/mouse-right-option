# 鼠标侧键 → 键盘按键 映射工具

## 现状（已生效）

- **鼠标第 4 键（Button 3）按下 → 发送 F3 按键**
- 微信输入法的「语音输入」快捷键设为 **F3**，因此按住侧键即可启动语音输入
- 已加入开机自启（登录项）

## 为什么不是"映射成 Option"

最初目标是让侧键等同「右 Option」，试过三代方案：

| 方案 | 结果 | 原因 |
|---|---|---|
| CGEvent 注入 flagsChanged（右 Option） | 失败 | 微信输入法只认硬件级修饰键事件，不认程序合成的 Option |
| 给真实事件打 Option 标记 | 失败 | 同上，输入法读的是按键事件本身 |
| Karabiner-Elements 虚拟键盘 | 失败 | Karabiner 能抓住键盘，但抓不到这个杂牌 2.4G 接收器鼠标（Devices 里不出现） |
| **改微信输入法快捷键为 F3 + 发送 F3** | **成功** | 普通按键注入可靠，不依赖硬件级驱动 |

结论：杂牌无线鼠标的侧键不适合"伪装修饰键"，改成"发送普通按键"最稳。

## 文件

- 源码：`/Users/wuwu/Documents/work/wk/mouse-right-option/main.swift`
- 构建脚本：`build.sh`
- 安装位置：`/Applications/MouseRightOption.app`
- 运行日志：`~/Library/Logs/MouseRightOption.log`

## 使用

菜单栏出现键盘图标，点开可以：

- 查看当前绑定状态
- **重新绑定鼠标键…**：点一下后按任意鼠标键，即绑定为该键
- 暂停 / 开启映射
- 退出

## 修改目标按键

目标按键写死在源码顶部：

```swift
let kTargetKeyCode: CGKeyCode = 99   // F3
```

常用 keycode：F1=122, F2=120, F3=99, F4=118, F5=96, F6=97, F13=105, F14=107, F15=113

改完重新执行 `./build.sh`，然后复制到 `/Applications` 并重新签名：

```bash
cd /Users/wuwu/Documents/work/wk/mouse-right-option
./build.sh
rm -rf /Applications/MouseRightOption.app
cp -R build/MouseRightOption.app /Applications/
codesign --force --deep -s "Apple Development: 985929029@qq.com (3HA3QXHGSA)" /Applications/MouseRightOption.app
```

## 注意

- 需要「辅助功能」权限（`系统设置 → 隐私与安全性 → 辅助功能`），已授权
- 签名用的是本机 Apple Development 证书，重新编译后 TCC 授权一般仍有效；如果失效，在辅助功能里删掉重加
- 该工具会**吞掉**被绑定鼠标键的原事件，因此浏览器里不会再触发"后退/前进"

## 未使用的组件

- Karabiner-Elements 已安装但抓不到该鼠标，可用于键盘映射；不需要可卸载
