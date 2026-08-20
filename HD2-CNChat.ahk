; ============================================================================
; HD2-CNChat —— 绝地潜兵2 中文输入助手 (AutoHotkey v2)
; ----------------------------------------------------------------------------
; 原理：
;   游戏内按“开始输入键”（默认 Enter，与游戏聊天键一致）时，
;   工具在游戏窗口底部弹出一个自绘输入条（系统输入法 IME 可直接使用），
;   输入中文后按 Enter，工具把文本以模拟按键的方式注入游戏聊天框并回车发送。
;   全程不修改游戏文件、不读写游戏内存，仅模拟键盘输入。
;
; 特色：
;   1. 极简悬浮输入条（参考 GRW-CNChat）：仅一个输入框 + 关闭按钮，
;      系统输入法 IME 直接可用，Enter 发送、Esc 取消；固定在游戏窗口右侧居中
;   2. 发送历史：主面板「历史记录」查看/重发（v1.10.5 起屏蔽输入条内 ↑/↓ 与 Ctrl+Y 快捷键）
;   3. 输入条自动跟随游戏窗口移动，位置按分辨率记忆
;   4. 5 种发送方式可切换，默认 Unicode 直发（SendEvent {U+nnnn}，参考 GRW-CNChat 方案）
;   5. “修复乱码”：发送时自动把游戏线程输入法切换为中文，发完恢复
;   6. IME 合成状态精确检测（ImmGetCompositionString），避免合成中误发送
;   7. 游戏窗口匹配：进程名与窗口标题任一命中（标题含 HELLDIVERS™ 2 等均可匹配）
;   8. Enter/小键盘Enter 均可打开输入条，回调内实时检测游戏状态并给出原因提示
;
; 免责声明：
;   本工具仅模拟键盘输入，不涉及游戏文件及内存数据篡改。
;   使用本工具在游戏中输入中文可能带来的后果，由使用者自行承担。
; ============================================================================

; ============================================================================
; 许可协议：GNU GPL v3（共版权 Copyleft）
;
; 本程序是修改版/衍生作品：基于 GRW-CNChat（游戏无缝输入中文）优化改写而来，
; 输入条 UI 部分复用自该作品。
;   原作者：GameXueRen
;   原始版权：Copyright © 2024-2025 GameXueRen
;   原始项目：https://github.com/GameXueRen/GRW-CNChat （GPL v3）
; 本修改版的 Copyright (C) 2026 崔素妍
;
; 本程序是自由软件：你可以依据自由软件基金会发布的 GNU 通用公共许可证
; 第 3 版（或任选更新的版本）的条款重新分发和/或修改它。
; 任何修改版/衍生作品必须同样以 GPL v3 授权并公开源代码。
;
; 本程序按“现状”分发，不附带任何明示或默示的担保；详情见随附的
; LICENSE 文件，或访问 https://www.gnu.org/licenses/gpl-3.0.html
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; ============================================================================
;
; ============================================================================
; 修改记录（相对 GRW-CNChat v3，GPL v3 第 5 条：显著标注本作品为修改版）
; 代码内标记约定：各功能区块注释已标明「源自 GRW-CNChat v3」或「HD2-CNChat 新增/重写」。
;   v1.0~v1.9（2026-8-19）：适配《绝地潜兵 2》；主界面简化为单游戏助手面板；
;       新增发送历史、按分辨率记忆输入条位置；删除战术短语库/单词查询表
;   v1.10  (2026-08-19)：Enter 系统热键启动即常驻注册 + 回调实时判定（修复游戏内 Enter 无反应）；
;       启动热键全部改 lambda（修复本机 Invalid callback function）；诊断日志增强
;   v1.10.1（2026-8-20）：系统热键回调成为 Enter 唯一决策者（修复钩子弹条+热键销毁的双触发）；
;       打开输入条时补发 Enter 打开游戏聊天框
;   v1.10.2（2026-8-20）：新增 SendGameKey（keybd_event+按下保持40ms；修复聊天框概率性打不开）
;   v1.10.3（2026-8-20）：所有 Enter 注入前先暂停常驻热键（修复提交回车被吞、桌面 Enter 被吞）
;   v1.10.4（2026-8-20）：屏蔽 Alt+左键拖动；输入条固定在游戏窗口右侧居中（原“右下角偏上+按分辨率记忆偏移”废弃）
;   v1.10.5（2026-8-20）：屏蔽输入条内 ↑/↓ 历史切换与 Ctrl+Y 重发快捷键（用户要求；历史记录窗口保留）
;   v1.10.6（2026-8-20）：修复①中文输入法下按 Enter 提交拼音成英文失效（输入条可见时暂停 Enter 系统热键，
;       把 Enter 交还 IME，发送由钩子通道负责）；②面板监听状态显示过期（改为实时查询，不依赖轮询缓存）
;   v1.10.7（2026-8-20）：输入法提交英文后不再自动发送——英文留在输入条里继续输入，
;       再次按 Enter 才发送（修复“打完 ChoiSoyeon 想继续打字却被直接发送”）
; ============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

;编译属性（Ahk2Exe）
;@Ahk2Exe-SetName HD2-CNChat
;@Ahk2Exe-SetProductName HD2中文输入助手
;@Ahk2Exe-SetDescription 绝地潜兵2中文输入助手
;@Ahk2Exe-SetCopyright Copyright (c) 2024-2025 GameXueRen; 2026 HD2-CNChat 崔素妍
;@Ahk2Exe-SetVersion 1.10.7.0
;@Ahk2Exe-SetMainIcon HD2-CNChat.ico
;@Ahk2Exe-ExeName HD2-CNChat.exe

; 快速窗口标题匹配（包含式）
SetTitleMatchMode 2
SetTitleMatchMode "Fast"
CoordMode "ToolTip", "Screen"

; ===================== 语法检查模式 =====================
; 启动参数为 check 时：整个脚本被解析(语法校验)后立即退出，不显示界面
; 启动参数为 selftest 时：执行内部自检（见文件末尾 Selftest）
; 启动参数为 debug 时：把按键/发送等关键事件写入 hd2cnc_debug.log 便于排障
isSelfTest := A_Args.Length && A_Args[1] = "selftest"
isDebug    := A_Args.Length && A_Args[1] = "debug"
; 调试日志（仅 debug 模式写入）
DebugLog(msg) {
    global isDebug
    if !isDebug
        return
    try
        FileAppend(Format("[{}] {}", A_TickCount, msg) "`n", A_ScriptDir "\hd2cnc_debug.log")
}
if isSelfTest
    FileAppend("M1:started args=" A_Args.Length " a1=" (A_Args.Length ? A_Args[1] : "-") "`n", A_ScriptDir "\selftest_debug.txt")
if A_Args.Length && A_Args[1] = "check"
    ExitApp 0
if isSelfTest
    FileAppend("M2:after-check`n", A_ScriptDir "\selftest_debug.txt")
if A_Args.Length && A_Args[1] = "selftest"
    FileAppend("M3:selftest-arg`n", A_ScriptDir "\selftest_debug.txt")

; ===================== 基本信息 =====================
AppName := "HD2中文输入助手"
AppVer  := "v1.10.7"

; ===================== 配置文件 =====================
; 优先使用脚本目录（便携），目录不可写时退回用户数据目录
cfgPath := A_ScriptDir "\HD2-CNChat.ini"
try {
    FileAppend("", cfgPath)
} catch {
    dir := A_AppData "\HD2-CNChat"
    if !DirExist(dir)
        DirCreate(dir)
    cfgPath := dir "\HD2-CNChat.ini"
}

; ===================== 全局状态 =====================
armed         := false      ; 是否已启动监听
gameExistsNow := false      ; 游戏窗口是否存在（由监测定时器刷新）
gameActiveNow := false      ; 游戏窗口是否在前台（由监测定时器刷新）
gameMinimized := false      ; 游戏窗口是否最小化
barGui        := 0          ; 输入条窗口对象
barHwnd       := 0          ; 输入条窗口句柄
barVisible    := false      ; 输入条是否显示
barEdit       := 0          ; 输入条编辑框
barW          := 0          ; 输入条宽
barH          := 0          ; 输入条高
lastGX := 0, lastGY := 0, lastGW := 0, lastGH := 0   ; 游戏窗口位置缓存
chatKeyRegistered := ""     ; 已注册的“开始输入键”
lastTipText   := ""         ; 状态提示内容缓存
sysEnterSuppress := false   ; Enter 系统热键自触发抑制：注入的 Enter 被回调消费
hookSawEnter  := 0          ; 最近一次 AHK 钩子通道收到 Enter 的时间戳（判断钩子是否工作）
justSent      := 0          ; 最近一次成功发送的时间戳（发送后短暂忽略“打开输入条”，防注入 Enter 触发重开）
enterInjectUntil := 0       ; 注入 Enter 后的抑制截止时间（A_TickCount）：窗口内忽略所有 Enter 自触发
                            ; （注入的 Enter 可能延迟数百毫秒才被系统热键派发，单次消费标志覆盖不到）

; ===================== 运行时配置（由 LoadCfg 填充） =====================
cfgInputKey     := "Enter"
cfgSendMethod   := 1
cfgFixGarbled   := 1
cfgPreSendDelay := 150
cfgBarWidth     := 560
cfgFontSize     := 14
cfgMaxLen       := 300
cfgAutoHideBar  := 1
cfgShowStatusTip := 1
cfgArmAtStart   := 0
cfgCheckAdmin   := 0
cfgMaxHistory   := 30
cfgExe          := "helldivers2.exe"
cfgTitle        := "HELLDIVERS"

; ===================== 配置读写 =====================
ReadCfg(key, def := "") {
    return IniRead(cfgPath, "main", key, def)
}
WriteCfg(key, val) {
    IniWrite(val, cfgPath, "main", key)
}
; 首次运行写入默认配置
InitDefaults() {
    WriteCfg("gameExe", "helldivers2.exe")
    WriteCfg("gameTitle", "HELLDIVERS")
    WriteCfg("inputKey", "Enter")
    WriteCfg("sendMethod", "1")
    WriteCfg("fixGarbled", "1")
    WriteCfg("preSendDelay", "150")
    WriteCfg("barWidth", "560")
    WriteCfg("fontSize", "14")
    WriteCfg("maxLen", "300")
    WriteCfg("autoHideBar", "1")
    WriteCfg("showStatusTip", "0")      ; 屏幕上方状态提示默认关闭
    WriteCfg("armAtStart", "0")         ; 启动时自动监听默认关闭（需手动点“启动监听”）
    WriteCfg("checkAdmin", "0")
    WriteCfg("maxHistory", "30")
}
; 加载并校验全部配置到全局变量
LoadCfg() {
    ; 首次运行（INI 不存在或为空）时写入默认配置
    if !FileExist(cfgPath) || ReadCfg("gameExe") = ""
        InitDefaults()
    global cfgInputKey := NormalizeHotkey(ReadCfg("inputKey", "Enter"), "Enter")
    global cfgSendMethod := Integer(ReadCfg("sendMethod", "1"))
    if cfgSendMethod < 1 || cfgSendMethod > 5
        cfgSendMethod := 1
    global cfgFixGarbled := Integer(ReadCfg("fixGarbled", "1"))
    if cfgFixGarbled != 0 && cfgFixGarbled != 1
        cfgFixGarbled := 1
    global cfgPreSendDelay := Integer(ReadCfg("preSendDelay", "150"))
    cfgPreSendDelay := Min(Max(cfgPreSendDelay, 0), 3000)
    global cfgBarWidth := Integer(ReadCfg("barWidth", "560"))
    cfgBarWidth := Min(Max(cfgBarWidth, 400), 900)
    global cfgFontSize := Integer(ReadCfg("fontSize", "14"))
    cfgFontSize := Min(Max(cfgFontSize, 10), 24)
    global cfgMaxLen := Integer(ReadCfg("maxLen", "300"))
    cfgMaxLen := Min(Max(cfgMaxLen, 50), 1000)
    global cfgAutoHideBar := Integer(ReadCfg("autoHideBar", "1"))
    global cfgShowStatusTip := Integer(ReadCfg("showStatusTip", "0"))
    global cfgArmAtStart := Integer(ReadCfg("armAtStart", "0"))
    global cfgCheckAdmin := Integer(ReadCfg("checkAdmin", "0"))
    global cfgMaxHistory := Integer(ReadCfg("maxHistory", "30"))
    cfgMaxHistory := Min(Max(cfgMaxHistory, 5), 100)
    global cfgExe := ReadCfg("gameExe", "helldivers2.exe")
    global cfgTitle := ReadCfg("gameTitle", "HELLDIVERS")
}
; 校验热键名称，非法时返回默认值
NormalizeHotkey(k, def) {
    n := GetKeyName(k)
    if !n
        return def
    ; 排除修饰键与大小写键
    if n = "CapsLock" || n = "LWin" || n = "RWin" || n = "LControl" || n = "RControl" || n = "LShift" || n = "RShift" || n = "LAlt" || n = "RAlt"
        return def
    return n
}
; 数字编辑框取值辅助：非法时用默认值
NumOrDef(s, def) {
    if IsInteger(s)
        return Integer(s)
    return def
}
; ============================================================================
; 游戏窗口匹配：进程名 与 窗口标题 任一命中即算游戏窗口
; （标题用包含式匹配，HELLDIVERS 可命中 "HELLDIVERS 2" / "HELLDIVERS™ 2"）
; ============================================================================
; 游戏窗口是否存在
GameExists() {
    return (cfgExe && WinExist("ahk_exe " cfgExe)) || (cfgTitle && WinExist(cfgTitle))
}
; 游戏窗口是否在前台
GameActive() {
    return (cfgExe && WinActive("ahk_exe " cfgExe)) || (cfgTitle && WinActive(cfgTitle))
}
; 前台窗口是否属于游戏进程（用 PID 比较，比 WinActive 更底层可靠，
; 兼容全屏/无边框/窗口化等各种游戏窗口模式）
IsGameForeground() {
    hwnd := GameHwnd()
    if !hwnd
        return false
    try {
        fgHwnd := WinGetID("A")
        if !fgHwnd
            return false
        if fgHwnd = hwnd
            return true
        return WinGetPID(fgHwnd) = WinGetPID(hwnd)
    }
    return false
}
; 获取游戏窗口句柄（进程名优先，标题兜底）
GameHwnd() {
    if cfgExe && WinExist("ahk_exe " cfgExe)
        return WinGetID("ahk_exe " cfgExe)
    if cfgTitle && WinExist(cfgTitle)
        return WinGetID(cfgTitle)
    return 0
}
; 当前匹配条件的文字说明
GameMatchDesc() {
    d := "未配置"
    if cfgExe
        d := "进程 " cfgExe
    if cfgTitle
        d := d = "未配置" ? ("标题 " cfgTitle) : (d " 或 标题 " cfgTitle)
    return d
}

; ============================================================================
; 底层按键注入（SendInput，失败时回退 keybd_event）
; 源自 GRW-CNChat v3；HD2-CNChat 新增 SendGameKey/SendGameEnter（keybd_event + 按下保持）
; ============================================================================
; 发送一个键盘事件；返回是否由 SendInput 成功注入
SendKeyEvent(vk, scan, flags) {
    input := Buffer(28, 0)
    NumPut("UInt", 1, input, 0)       ; INPUT_KEYBOARD
    NumPut("UShort", vk, input, 4)
    NumPut("UShort", scan, input, 6)
    NumPut("UInt", flags, input, 8)
    r := DllCall("SendInput", "UInt", 1, "Ptr", input, "Int", 28, "Int")
    if r = 0
        DllCall("keybd_event", "UChar", vk, "UChar", scan, "UInt", flags, "UPtr", 0)
    return r != 0
}
; 发送一个按键（按下+释放）
SendVKey(vk) {
    SendKeyEvent(vk, 0, 0)
    SendKeyEvent(vk, 0, 2)      ; KEYEVENTF_KEYUP
}
; 给游戏发送一次按键（keybd_event 通道，按下-保持-释放）
; 实测教训：SendInput 瞬时 down+up 会被按帧采样输入的游戏偶发漏掉
; （HD2 聊天框偶发打不开——v1.10.1 实机故障），而 keybd_event + 保持 40ms
; 跨多个游戏帧，可靠性接近物理按键；文本注入（SendEvent/keybd_event）实测一直有效
SendGameKey(vk, scan) {
    DllCall("keybd_event", "UChar", vk, "UChar", scan, "UInt", 0, "UPtr", 0)
    Sleep 40
    DllCall("keybd_event", "UChar", vk, "UChar", scan, "UInt", 2, "UPtr", 0)
    Sleep 30
}
; 给游戏发送 Enter（打开/提交聊天框；主键盘 Enter 扫描码 0x1C）
SendGameEnter() {
    SendGameKey(0x0D, 0x1C)
}
; 发送 Alt+GBK 码（用 AHK 内置 SendEvent {ASC} 实现：Alt+小键盘数字，
; 兼容性经过多款游戏验证；需配合中文键盘布局，见 SwitchGameIME）
SendAltCode(code) {
    SendEvent("{ASC " code "}")
    Sleep 8
}
; GBK Alt码方式发送整段文本（需游戏线程为中文键盘布局，见 SwitchGameIME）
SendGBKText(text) {
    ; 确保 NumLock 开启（Alt+小键盘数字依赖它）
    nlOn := GetKeyState("NumLock", "T")
    if !nlOn {
        SendVKey(0x90)                   ; NumLock
        Sleep 40
    }
    SetKeyDelay(15, 15)
    try {
        for ch in StrSplit(text) {
            buf := Buffer(4, 0)
            n := StrPut(ch, buf, "CP936")
            if n < 1
                continue                 ; 无法编码的字符跳过
            code := NumGet(buf, 0, "UChar")
            if n >= 2
                code := (code << 8) | NumGet(buf, 1, "UChar")
            SendAltCode(code)
        }
    }
    if !nlOn
        SendVKey(0x90)                   ; 恢复 NumLock 状态
}
; Unicode 方式发送整段文本
; 参考 GRW-CNChat：逐字转 {U+nnnn} 序列，用 SendEvent 一次注入，
; 不依赖键盘布局，绝大多数游戏可正常接收
SendUnicodeText(text) {
    unicode := ""
    for ch in StrSplit(text)
        unicode .= Format("{{}U+{:04X}{}}", Ord(ch))
    SendEvent unicode
}
; 剪贴板粘贴方式发送整段文本
SendClipboardText(text) {
    saved := ClipboardAll()
    A_Clipboard := text
    if ClipWait(2) {
        Sleep 30
        SendKeyEvent(0x11, 0, 0)         ; Ctrl 按下
        SendKeyEvent(0x56, 0, 0)         ; V 按下
        SendKeyEvent(0x56, 0, 2)
        SendKeyEvent(0x11, 0, 2)         ; Ctrl 释放
        Sleep 50
    }
    A_Clipboard := saved
}
; PostMessage WM_CHAR 方式发送整段文本
SendPostMsgText(text) {
    hwnd := GameHwnd()
    if !hwnd
        return
    for ch in StrSplit(text) {
        PostMessage(0x102, Ord(ch), 0, , hwnd)   ; WM_CHAR
        Sleep 3
    }
}
; 切换游戏窗口线程的键盘布局（WM_INPUTLANGCHANGEREQUEST），返回原布局ID
SwitchGameIME(langId) {
    hwnd := GameHwnd()
    if !hwnd
        return -1
    tid := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    old := DllCall("GetKeyboardLayout", "UInt", tid, "Ptr")
    if old != langId && old != 0 {
        PostMessage(0x50, 0, langId, , hwnd)
        Sleep 60
    }
    return old
}
; 检测输入条编辑框当前是否处于 IME 合成状态
IsComposing() {
    if !barEdit
        return false
    hIMC := DllCall("Imm32.dll\ImmGetContext", "Ptr", barEdit.Hwnd, "Ptr")
    if !hIMC
        return false
    ; GCS_COMPSTR = 0x8：取合成字符串长度，大于0说明正在合成
    len := DllCall("Imm32.dll\ImmGetCompositionStringW", "Ptr", hIMC, "UInt", 0x8, "Ptr", 0, "UInt", 0, "Int")
    DllCall("Imm32.dll\ImmReleaseContext", "Ptr", barEdit.Hwnd, "Ptr", hIMC)
    return len > 0
}

; ============================================================================
; 发送引擎（源自 GRW-CNChat v3，HD2-CNChat 深度改写：热键暂停/抑制、keybd_event 保持注入）
; ============================================================================
; 把文本发送到游戏窗口；pressEnter=true 时发送后补一个回车（提交聊天）
; 返回空串表示成功，否则返回错误说明
SendTextToGame(text, pressEnter := false) {
    DebugLog("SendTextToGame 开始 text=[" text "] 方式=" cfgSendMethod " 回车=" pressEnter)
    if !GameExists() {
        DebugLog("SendTextToGame 失败：未检测到游戏窗口")
        return "未检测到游戏窗口（" GameMatchDesc() "）"
    }
    hwnd := GameHwnd()
    if !WinActive(hwnd) {
        WinActivate(hwnd)
        if !WinWaitActive(hwnd, , 2) {
            DebugLog("SendTextToGame 失败：无法激活游戏窗口")
            return "无法激活游戏窗口"
        }
    }
    Sleep cfgPreSendDelay
    SetKeyDelay(15, 15)
    oldLay := -1
    ; 修复乱码：仅 GBK Alt码方式需要中文键盘布局
    if cfgSendMethod = 2 && cfgFixGarbled
        oldLay := SwitchGameIME(0x08040804)     ; 中文(简体)-美式键盘 0x08040804
    try {
        switch cfgSendMethod {
            case 1: SendUnicodeText(text)
            case 2: SendGBKText(text)
            case 3: SendClipboardText(text)
            case 4: SendPostMsgText(text)
            case 5: ControlSendText(text, , hwnd)
            default: SendUnicodeText(text)
        }
    } catch as e {
        DebugLog("SendTextToGame 注入异常：" e.Message)
    }
    if oldLay != -1
        SwitchGameIME(oldLay)                   ; 恢复原输入法
    if pressEnter {
        Sleep 40
        ; 提交回车：必须先暂停 Enter 系统热键再注入——
        ; 热键注册期间注入的 Enter 会被系统热键吞掉（游戏收不到，发送永远不生效），
        ; v1.10.2 实机故障：文字已进聊天框但必须手动再按 2-3 次 Enter 才能发出
        try {
            if sysHkEnterReg {
                DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
                global sysHkEnterReg := false
                DebugLog("提交回车：暂停 Enter 热键")
            }
            global sysEnterSuppress := true      ; 钩子通道对注入的 Enter 直接放行
            global enterInjectUntil := A_TickCount + 1200   ; 时间窗兜底（防止恢复注册后延迟派发自触发）
            SendGameEnter()                     ; keybd_event + 保持：提交聊天（对 HD2 可靠）
            Sleep 30
        } finally {
            global sysEnterSuppress := false
            if !sysHkEnterReg {
                RegisterSysEnter()
                DebugLog("提交回车：恢复 Enter 热键 ok=" sysHkEnterReg)
            }
        }
    }
    PushHistory(text)
    global justSent := A_TickCount
    return ""
}

; ============================================================================
; 输入条（悬浮输入框）—— UI 源自 GRW-CNChat v3，HD2-CNChat 简化为单行极简样式
; ============================================================================
; 创建输入条窗口（懒创建，首次显示时建立）
; 极简设计（参考 GRW-CNChat）：仅一个输入框 + 关闭按钮
CreateBar() {
    fs := cfgFontSize
    editH := Round(fs * A_ScreenDPI / 72) + 10
    global barW := cfgBarWidth
    global barGui := Gui("+ToolWindow -SysMenu +Border -Caption +AlwaysOnTop", AppName "输入条")
    barGui.MarginX := 6
    barGui.MarginY := 5
    barGui.BackColor := "15171A"
    barGui.SetFont("s" fs, "Microsoft YaHei UI")

    ; 输入框 + 关闭按钮（一行）
    global barEdit := barGui.AddEdit("w" (barW - 62) " h" editH " cWhite Background15171A Limit" cfgMaxLen)
    try
        SendMessage(0x1501, true, StrPtr("输入中文，按 Enter 发送，Esc 取消"), barEdit.Hwnd)   ; EM_SETCUEBANNER
    cBtn := barGui.AddButton("x+2 w56 h" editH, "✕")
    cBtn.SetFont("s10 bold")

    global barH := 5 + editH + 5

    barGui.Show("Hide")
    global barHwnd := barGui.Hwnd

    ; 事件
    barEdit.OnEvent("LoseFocus", (*) => SetTimer(CheckBarFocus, -60))
    cBtn.OnEvent("Click", (*) => HideBar())
}
; 销毁输入条（下次显示时重建，用于布局参数变更后）
DestroyBar() {
    global barVisible := false
    if barGui
        barGui.Destroy()
    global barGui := 0, barHwnd := 0, barEdit := 0
}
; 把输入条移动到固定锚点：游戏窗口右侧居中（距右缘 30px，垂直居中）
; 注意：不检查 barVisible——首次显示时（ShowBar）也需要定位；
; 实时查询游戏窗口（不依赖轮询状态），无游戏窗口时兜底显示在屏幕右侧居中
; v1.10.4：屏蔽 Alt+左键拖动，位置固定不可调（原按分辨率记忆偏移已废弃）
MoveBarToGame() {
    if !barGui
        return
    if !GameExists() {
        ; 兜底：屏幕右侧居中
        tx := A_ScreenWidth - barW - 30
        ty := (A_ScreenHeight - barH) // 2
        barGui.Move(Min(Max(tx, 0), A_ScreenWidth - barW), Min(Max(ty, 0), A_ScreenHeight - barH))
        return
    }
    hwnd := GameHwnd()
    if !hwnd
        return
    try {
        WinGetClientPos(&gx, &gy, &gw, &gh, hwnd)
    } catch {
        return
    }
    if gw < 50 || gh < 50
        return
    ; 固定锚点：游戏窗口右侧居中
    tx := gx + gw - barW - 30
    ty := gy + (gh - barH) // 2
    tx := Min(Max(tx, 0), A_ScreenWidth - barW)
    ty := Min(Max(ty, 0), A_ScreenHeight - barH)
    barGui.Move(tx, ty)
}
; 显示输入条（不依赖监听状态——游戏内按 Enter 直接可用）
ShowBar() {
    if !barGui
        CreateBar()
    if !barVisible {
        MoveBarToGame()
        barGui.Show()
        global barVisible := true
        barEdit.Enabled := true
        barGui.GetPos(&bx, &by)
        DebugLog("ShowBar 输入条已显示 pos=" bx "," by)
        UpdateBarHotkeys()
        UpdateSysHotkeys()
        barEdit.Focus()
        if barEdit.Text
            PostMessage(0xB1, -1, -1, barEdit, barGui)   ; EM_SETSEL 光标移到末尾
    } else {
        barEdit.Focus()
    }
}
; 隐藏输入条（保留已输入文本）
HideBar() {
    if !barVisible
        return
    global barVisible := false
    barEdit.Enabled := false
    barGui.Hide()
    UpdateBarHotkeys()
    UpdateSysHotkeys()
}

; ============================================================================
; 输入条热键回调
; ============================================================================
; 打开输入条（游戏在前台时有效；不依赖监听状态）
OpenInputBar() {
    DebugLog("OpenInputBar 入口 barVisible=" barVisible " ownWin=" IsOwnWindowActive() " GameActive=" GameActive() " GameExists=" GameExists())
    if barVisible
        return
    if A_TickCount - justSent < 500
        return                                  ; 刚发送过：忽略（防注入 Enter 触发重开）
    if IsOwnWindowActive()
        return                                  ; 焦点在本工具窗口上，不打扰
    if !GameActive() {
        ; 游戏在后台时给出提示；游戏未运行则静默（不打扰日常使用）
        if GameExists()
            Tip3s("游戏在后台，点击游戏窗口后再按 Enter")
        return
    }
    ShowBar()
}
; 前台窗口是否属于本工具（主面板/设置/历史等）
IsOwnWindowActive() {
    try {
        fgPid := WinGetPID("A")
        ownPid := WinGetPID(A_ScriptHwnd)
        return fgPid = ownPid
    }
    return false
}
; 3 秒后自动消失的提示
Tip3s(text) {
    ToolTip(text, , , 3)
    SetTimer(() => ToolTip(,,, 3), -3000)
}
; Enter：发送（v1.10.7 交互模式）
; 按键释放后比对输入框文本：
;   - 文本变化（输入法刚提交了英文，如中文输入法下按 Enter 提交拼音）→ 本次 Enter 只提交，
;     不发送——英文留在输入条里，用户继续输入，之后再次按 Enter 才发送
;     （例：要发“你好我是ChoiSoyeon很高兴认识你”，打完 ChoiSoyeon 按 Enter 只提交英文，
;      继续打“很高兴认识你”，再按 Enter 才整体发送）
;   - 文本未变化 → 立即发送
; 完全不依赖 IME 合成状态检测，任何输入法都稳定。
; busy 防重：AHK 钩子与系统热键双通道可能同时触发，防止重复发送
BarEnter() {
    static busy := false
    if busy
        return
    busy := true
    try {
        if !barVisible
            return
        oldText := barEdit.Text
        DebugLog("BarEnter old=[" oldText "]")
        KeyWait "Enter"                     ; 等按键释放，让输入法完成处理
        Sleep 50
        if barEdit.Text != oldText {
            DebugLog("BarEnter 文本变化(输入法提交英文)，本次不发送，继续输入")
            return
        }
        DoBarEnter()
    } finally {
        busy := false
    }
}
; 实际执行发送
DoBarEnter() {
    if !barVisible
        return
    txt := Trim(barEdit.Text, " `t`r`n")
    HideBar()
    if txt = "" {
        barEdit.Text := ""
        return
    }
    DebugLog("DoBarEnter 发送 [" txt "] 方式=" cfgSendMethod)
    err := SendTextToGame(txt, true)
    DebugLog("DoBarEnter 结果 err=[" err "]")
    if err {
        Tip3s("发送失败：" err)
    } else {
        barEdit.Text := ""
    }
}
; Esc：取消并退出（v3 模式：~Esc Up 触发，无条件退出，不比对文本）
; 合成中按 Esc 也会直接退出输入，并激活游戏发送 Esc 关闭游戏聊天框
BarEsc() {
    if !barVisible
        return
    DebugLog("BarEsc 退出")
    barEdit.Text := ""
    HideBar()
    ; 激活游戏后发送 Esc 关闭游戏内聊天框（实时检测，不依赖轮询状态）
    if GameActive() {
        hwnd := GameHwnd()
        if hwnd {
            WinActivate(hwnd)
            if WinWaitActive(hwnd, , 1) {
                Sleep 30
                SendGameKey(0x1B, 0x01)    ; Esc（keybd_event + 保持，可靠性同 Enter）
            }
        }
    }
}
; F9：循环切换发送方式（游戏内调试用）
CycleSendMethod() {
    if !barVisible
        return
    global cfgSendMethod := Mod(cfgSendMethod, 5) + 1
    WriteCfg("sendMethod", cfgSendMethod)
    if IsSet(methodDDL)
        methodDDL.Value := cfgSendMethod
    names := ["Unicode直发", "GBK Alt码", "剪贴板粘贴", "PostMessage", "ControlSendText"]
    Tip3s("发送方式：" names[cfgSendMethod])
}
; 输入条失去焦点后的处理（点击游戏等场景自动隐藏；不依赖监听状态）
CheckBarFocus() {
    if !barVisible || !barGui
        return
    if WinActive("ahk_id " barHwnd)
        return
    if cfgAutoHideBar
        HideBar()
}

; ============================================================================
; 热键管理（采用 GRW-CNChat v3 的动态注册方式，不使用 #HotIf 条件热键）
; 双通道机制（AHK 钩子 + Win32 系统热键）为 HD2-CNChat 重写/新增
; 原则：
;   - Enter/NumpadEnter：脚本启动时全局注册（常驻），回调内自行判断——
;     输入条可见→发送；游戏前台→打开输入条；其他场景→放行（无副作用）
;   - 输入条按键（Esc/F9）：输入条显示时注册，隐藏时注销
; 不依赖任何焦点/激活状态的条件求值，任何环境下都稳定生效。
; ============================================================================
barKeysRegistered  := false     ; 输入条热键（Esc/历史/重发/方式切换）是否已注册

; 统一 Enter 处理（钩子通道，v1.10.1 起为“候补”角色）：
;   系统热键常驻时（sysHkEnterReg=1），Enter 已被系统热键吞掉，由系统热键回调统一处理，
;   本函数直接让位（否则双通道会同时动作：钩子弹输入条、系统热键再当“发送”销毁它）。
;   系统热键未注册（注册失败等）时才由本函数按原逻辑兜底。
EnterKeyHandler() {
    global hookSawEnter := A_TickCount
    if A_TickCount < enterInjectUntil      ; 注入的 Enter（时间窗兜底）
        return
    if sysEnterSuppress                   ; 注入的 Enter：不消费标志（由系统热键回调消费），仅放行
        return
    if sysHkEnterReg {
        DebugLog("EnterKey 系统热键常驻，让位")
        return
    }
    DebugLog("EnterKey barVisible=" barVisible " GameActive=" GameActive() " Foreground=" IsGameForeground())
    if barVisible {
        BarEnter()
        return
    }
    if GameActive() || IsGameForeground() {
        OpenInputBar()
        return
    }
    ; 其他场景：无操作，Enter 照常传递给前台窗口
}
; Ctrl+Enter：强制打开输入条（备用通道，只要游戏进程存在即可，绕过前台判断）
ForceOpenInputBar() {
    DebugLog("Ctrl+Enter 强制打开 barVisible=" barVisible " GameExists=" GameExists())
    if barVisible
        return
    if IsOwnWindowActive()
        return
    if !GameExists()
        return
    ShowBar()
}

; ============================================================================
; 系统级热键通道（Win32 RegisterHotKey）—— HD2-CNChat 新增（原版 GRW-CNChat 无此机制）
; 由 Windows 内核处理，不依赖 AHK 键盘钩子——AHK 钩子失效时的备用通道。
;   Enter      ：启动时注册一次并常驻（v1.10 起）→ 回调内实时判断：
;                 输入条可见→发送；游戏前台（实时查询）→ 打开输入条并补开游戏聊天；
;                 其他场景→重新注入 Enter 放行（系统热键吞掉的原按键必须补还）
;   Esc        ：输入条可见时注册 → 退出输入
;   Ctrl+Enter ：游戏在前台时注册 → 强制打开输入条（备用）
; 系统热键会拦截按键（游戏收不到），打开/发送流程与手动发送相同（注入文字+回车）。
; 注意：v1.10 起 Enter 常驻注册不再依赖 RefreshGameState 的 250ms 轮询——
; 之前“游戏前台→注册”的条件链任何一环失效（定时器死掉/状态冻结/判定错误）
; 都会导致游戏内按 Enter 无任何反应（v1.8~v1.9 的实机故障）。
; v1.10.1 要点：RegisterHotKey 会无条件吞掉按键（即使钩子通道 ~ 透传，游戏也收不到），
; 所以本回调是 Enter 的“唯一决策者”：
;   - 钩子通道（EnterKeyHandler）在 sysHkEnterReg=1 时让位，杜绝“钩子弹条、热键发送”双触发销毁
;   - 每次吞掉的 Enter 要么被使用（发送/打开），要么重新注入放行，绝不静默丢弃
;   - 打开输入条时必须给游戏补发 Enter 打开聊天框（游戏聊天框是发送文本的落点）
; ============================================================================
sysHkEnterReg := false      ; Enter 系统热键是否已注册（v1.10 起：常驻，仅 SysOpenBar 短暂暂停）
sysHkEscReg  := false       ; Esc 系统热键是否已注册
sysHkCEnterReg := false     ; Ctrl+Enter 系统热键是否已注册

OnMessage(0x0312, OnSysHotkey)          ; WM_HOTKEY
OnSysHotkey(wParam, lParam, msg, hwnd) {
    try {
        if wParam = 0x4844 {                ; 'HD' Enter（常驻，唯一决策者）
            if A_TickCount < enterInjectUntil {
                DebugLog("抑制注入 Enter（时间窗）")
                return
            }
            DebugLog("系统热键 Enter 触发 barVisible=" barVisible " GameActive=" GameActive())
            if sysEnterSuppress {           ; 刚注入的 Enter（放行/发送/开聊天），消费掉防自触发
                global sysEnterSuppress := false
                return
            }
            if barVisible {
                BarEnter()
                return
            }
            if GameActive() {
                SysOpenBar()                ; 打开输入条 + 给游戏补发 Enter 打开聊天框
                return
            }
            ; 非游戏场景：系统热键已吞掉原按键，重新注入 Enter 放行（必须补还，不能静默丢弃）
            ; 注意：必须先暂停热键再注入——否则注入的 Enter 又被自己的热键吞掉，
            ; 前台窗口永远收不到（v1.10.2 实机确认：桌面 Enter 会被静默吃掉）
            if sysHkEnterReg {
                DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
                global sysHkEnterReg := false
            }
            global sysEnterSuppress := true      ; 钩子通道对注入的 Enter 直接放行
            global enterInjectUntil := A_TickCount + 1200   ; 时间窗兜底
            SendVKey(0x0D)
            Sleep 30
            global sysEnterSuppress := false
            if !sysHkEnterReg
                RegisterSysEnter()               ; 恢复常驻
            return
        } else if wParam = 0x4845 {         ; 'HE' Esc
            DebugLog("系统热键 Esc 触发")
            BarEsc()
        } else if wParam = 0x4843 {         ; 'HC' Ctrl+Enter
            DebugLog("系统热键 Ctrl+Enter 触发")
            ForceOpenInputBar()
        }
    } catch as e {
        DebugLog("OnSysHotkey 异常：" e.Message " @ " e.Line)
    }
}
; Enter 系统热键常驻注册（启动时调用一次；SysOpenBar 暂停后用于恢复）
; 失败时重试几次（旧实例 #SingleInstance 退出需要一点时间，避免注册冲突）
RegisterSysEnter() {
    loop 4 {
        ok := DllCall("RegisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844, "UInt", 0, "UInt", 0x0D)
        if ok {
            global sysHkEnterReg := true
            DebugLog("系统热键注册 Enter(常驻) ok=1")
            return true
        }
        global sysHkEnterReg := false
        DebugLog("系统热键注册 Enter(常驻) 失败 err=" A_LastError " 重试中")
        Sleep 400
    }
    DebugLog("系统热键注册 Enter(常驻) 最终失败 err=" A_LastError)
    return false
}
; 系统热键通道打开输入条（Enter 的“打开”分支）：
; 游戏的原 Enter 已被系统热键吞掉，游戏收不到 → 聊天框不会开。
; 必须：暂停热键 → 注入 Enter 给游戏打开聊天框 → 显示输入条 → 恢复热键。
; （v1.10.1：不再判断钩子是否透传——RegisterHotKey 吞键与钩子无关，一律补发）
SysOpenBar() {
    if barVisible || IsOwnWindowActive()
        return
    if A_TickCount - justSent < 500
        return                                  ; 刚发送过：忽略（防注入 Enter 触发重开）
    if !GameActive()
        return
    if sysHkEnterReg {
        ; 暂停 Enter 系统热键，避免补发的 Enter 自触发
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
        global sysHkEnterReg := false
        global sysEnterSuppress := true         ; 钩子通道对本函数注入的 Enter 直接放行
        global enterInjectUntil := A_TickCount + 1200   ; 时间窗兜底（注入事件可能延迟派发）
        DebugLog("SysOpenBar 暂停 Enter 热键，注入 Enter 打开游戏聊天")
        SendGameEnter()                         ; keybd_event + 保持：对 HD2 可靠
        Sleep 120                               ; 等游戏完全处理完 Enter 再弹输入条（防焦点切换干扰）
        global sysEnterSuppress := false
    }
    ShowBar()
    ; 注意：不再在此恢复 Enter 热键——ShowBar 内的 UpdateSysHotkeys 会按 barVisible 管理：
    ; 输入条可见期间 Enter 热键保持暂停（交还 IME），隐藏时自动恢复注册
}
; 诊断：前台窗口信息（用于定位“游戏在前台但检测不到”的问题）
DiagForeground() {
    try {
        fgHwnd := WinGetID("A")
        if !fgHwnd
            return "fg=<none>"
        return "fg=hwnd:" fgHwnd " pid:" WinGetPID(fgHwnd) " exe:" WinGetProcessName(fgHwnd) " title:[" WinGetTitle(fgHwnd) "]"
    }
    return "fg=?"
}
; 更新系统热键注册（由常驻状态定时器调用）
UpdateSysHotkeys() {
    ; Enter：输入条可见时暂停注册（系统热键会吞掉 Enter，中文输入法需要它提交拼音成英文；
    ; 此时输入条内 Enter 的发送由钩子通道 EnterKeyHandler 负责——本机钩子已验证可用）；
    ; 输入条隐藏时恢复注册（游戏内打开输入条 + 桌面放行）
    if barVisible && sysHkEnterReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
        global sysHkEnterReg := false
        DebugLog("系统热键注销 Enter（输入条可见，交还 IME）")
    } else if !barVisible && !sysHkEnterReg && A_TickCount >= enterInjectUntil {
        RegisterSysEnter()
    }
    ; Ctrl+Enter：游戏在前台（强制打开备用通道）
    shouldCEnter := gameActiveNow && !barVisible
    if shouldCEnter && !sysHkCEnterReg {
        ok := DllCall("RegisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4843, "UInt", 0x2, "UInt", 0x0D)
        global sysHkCEnterReg := ok != 0
        DebugLog("系统热键注册 Ctrl+Enter ok=" sysHkCEnterReg (ok ? "" : " err=" A_LastError))
    } else if !shouldCEnter && sysHkCEnterReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4843)
        global sysHkCEnterReg := false
        DebugLog("系统热键注销 Ctrl+Enter")
    }
    ; Esc：输入条可见
    if barVisible && !sysHkEscReg {
        ok := DllCall("RegisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4845, "UInt", 0, "UInt", 0x1B)
        global sysHkEscReg := ok != 0
        DebugLog("系统热键注册 Esc ok=" sysHkEscReg (ok ? "" : " err=" A_LastError))
    } else if !barVisible && sysHkEscReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4845)
        global sysHkEscReg := false
        DebugLog("系统热键注销 Esc")
    }
}
; 注销全部系统热键（退出时调用）
UnregisterAllSysHotkeys() {
    if sysHkEnterReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
        global sysHkEnterReg := false
    }
    if sysHkEscReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4845)
        global sysHkEscReg := false
    }
    if sysHkCEnterReg {
        DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4843)
        global sysHkCEnterReg := false
    }
}
; 更新输入条热键：输入条显示时注册，隐藏时注销
; v1.10.5：↑/↓ 历史切换与 Ctrl+Y 重发已按用户要求屏蔽，仅保留 Esc/F9
; 注意：本机 AHK v2.0.26 环境下 Hotkey 只接受 lambda/BoundFunc 回调
; （直接传函数对象会报 Invalid callback function），统一用 lambda 包装
UpdateBarHotkeys() {
    if barVisible && !barKeysRegistered {
        try {
            Hotkey("~Esc Up", (*) => BarEsc(), "On")
            Hotkey("F9", (*) => CycleSendMethod(), "On")
            global barKeysRegistered := true
            DebugLog("热键注册：输入条按键")
        } catch as e {
            DebugLog("热键注册失败(输入条)：" e.Message)
        }
    } else if !barVisible && barKeysRegistered {
        try {
            Hotkey("~Esc Up", "Off")
            Hotkey("F9", "Off")
            global barKeysRegistered := false
            DebugLog("热键注销：输入条按键")
        } catch as e {
            DebugLog("热键注销失败(输入条)：" e.Message)
        }
    }
}
; 注销输入条热键（退出时调用；Enter 常驻不注销）
UnregisterAllHotkeys() {
    if barKeysRegistered {
        Hotkey("~Esc Up", "Off")
        Hotkey("F9", "Off")
        global barKeysRegistered := false
    }
    if chatKeyRegistered {
        Hotkey("~*" chatKeyRegistered, "Off")
        global chatKeyRegistered := ""
    }
}

; ============================================================================
; 游戏监测 —— HD2-CNChat 新增（常驻状态刷新 + 系统热键维护，原版为单定时器监测）
; ============================================================================
; 注册“开始输入键”热键（非 Enter 时动态注册；lambda 包装，见 UpdateBarHotkeys 注释）
RegisterChatKey() {
    if chatKeyRegistered
        Hotkey("~*" chatKeyRegistered, "Off")
    global chatKeyRegistered := ""
    if cfgInputKey != "Enter" {
        Hotkey("~*" cfgInputKey, (*) => OpenInputBar(), "On")
        global chatKeyRegistered := cfgInputKey
    }
}
; 启动监听
Arm() {
    if armed
        return
    if !cfgExe && !cfgTitle {
        MsgBox("请先在“设置”中填写游戏进程名（如 helldivers2.exe）或窗口标题！", AppName, "Icon!")
        return
    }
    global armed := true
    RegisterChatKey()
    DebugLog("Arm 启动监听，匹配=" GameMatchDesc())
    SetTimer(MonitorGame, 250)
    SetTimer(MonitorGame, -10)
    armBtn.Text := "停止监听"
    armBtn.SetFont("bold s12 cRed")
    UpdatePanelStatus()                         ; 立即刷新面板状态（不依赖定时器）
    DebugLog("Arm 完成 armed=" armed " status=[" statusText.Text "] exists=" gameExistsNow " active=" gameActiveNow)
    UpdateTrayTip()
}
; 停止监听
Disarm() {
    if !armed
        return
    global armed := false
    UnregisterAllHotkeys()
    SetTimer(MonitorGame, 0)
    HideBar()
    ToolTip(,,, 2)
    global lastTipText := ""
    armBtn.Text := "启动监听"
    armBtn.SetFont("bold s12 cGreen")
    UpdatePanelStatus()
    DebugLog("Disarm 完成 armed=" armed)
    UpdateTrayTip()
}
; 常驻状态刷新（不依赖监听开关，启动即运行）：
; 更新游戏存在/前台状态，并维护系统热键注册（Enter 常驻，此处只维护 Esc/Ctrl+Enter）
; 整体异常保护：任何异常只记录日志，绝不让循环停摆
RefreshGameState() {
    try {
        newExists := GameExists()
        newActive := GameActive()
        if newExists != gameExistsNow || newActive != gameActiveNow
            DebugLog("状态变化: exists=" newExists " active=" newActive " " DiagForeground())
        global gameExistsNow := newExists
        global gameActiveNow := newActive
        UpdateSysHotkeys()
        DiagGameBackground()
        if armed
            UpdatePanelStatus()
    } catch as e {
        DebugLog("RefreshGameState 异常：" e.Message " @ " e.Line)
    }
}
; 诊断：游戏存在但不在前台时，周期性记录前台窗口信息（定位“游戏在前台却检测不到”）
DiagGameBackground() {
    static n := 0
    if gameExistsNow && !gameActiveNow {
        n++
        if Mod(n, 8) = 0        ; 每 8 次（约 2 秒）记一次
            DebugLog("游戏在后台(存在但未激活) " DiagForeground())
    } else {
        n := 0
    }
}
; 监测定时器：跟随窗口、更新面板（仅监听时）
MonitorGame() {
    if !armed {
        SetTimer(, 0)
        return
    }
    try {
        ; 监听期间同时刷新游戏状态缓存（即使 RefreshGameState 链路异常，
        ; 面板显示与窗口跟随也不会用过期数据——v1.10.6 修复“状态显示与实际不符”）
        global gameExistsNow := GameExists()
        global gameActiveNow := GameActive()
        MonitorGameInner()
        UpdatePanelStatus()
    } catch as e {
        DebugLog("MonitorGame 异常：" e.Message " @ " e.Line)
    }
}
MonitorGameInner() {
    global gameMinimized := false
    if gameExistsNow {
        hwnd := GameHwnd()
        if hwnd {
            try {
                gameMinimized := WinGetMinMax(hwnd) = -1
            }
        }
    }

    if gameExistsNow {
        hwnd := GameHwnd()
        if !hwnd {
            global lastGX := 0, lastGY := 0, lastGW := 0, lastGH := 0
            if barVisible
                HideBar()
            return
        }
        try {
            WinGetClientPos(&gx, &gy, &gw, &gh, hwnd)
        } catch {
            gx := lastGX, gy := lastGY, gw := lastGW, gh := lastGH
        }
        if gw != lastGW || gh != lastGH {
            ; 分辨率变化时重新读取锚点偏移
            global lastGX := gx, lastGY := gy, lastGW := gw, lastGH := gh
            if barVisible
                MoveBarToGame()
        } else if (gx != lastGX || gy != lastGY) && barVisible {
            global lastGX := gx, lastGY := gy
            MoveBarToGame()
        } else {
            global lastGX := gx, lastGY := gy, lastGW := gw, lastGH := gh
        }
        if gameMinimized && barVisible
            HideBar()
    } else {
        global lastGX := 0, lastGY := 0, lastGW := 0, lastGH := 0
        if barVisible
            HideBar()
    }
    ; 状态提示
    tip := ""
    if cfgShowStatusTip {
        if gameExistsNow && gameActiveNow && !barVisible
            tip := "● 中文输入已就绪，按 " cfgInputKey " 打开聊天"
        else if gameExistsNow && !gameActiveNow
            tip := "○ 游戏在后台，点击游戏窗口即可输入"
        else if !gameExistsNow
            tip := "✕ 未检测到游戏（" GameMatchDesc() "）"
    }
    if tip != lastTipText {
        global lastTipText := tip
        if tip
            ToolTip(tip, A_ScreenWidth // 2 - 150, 30, 2)
        else
            ToolTip(,,, 2)
    }
}
; 更新主面板状态显示
; v1.10.6：实时查询游戏窗口，不依赖轮询缓存（修复“游戏在运行却显示未检测到 /
; 游戏已退出仍显示已监听”的过期状态问题）
UpdatePanelStatus() {
    if !IsSet(statusText)
        return
    if !armed {
        statusText.Text := "未启动监听（游戏内按 Enter 仍可直接输入）"
        statusText.SetFont("s10 bold cGray")
        return
    }
    existsNow := GameExists()
    activeNow := GameActive()
    if !existsNow {
        statusText.Text := "监听中 · 未检测到游戏窗口"
        statusText.SetFont("s10 bold cRed")
    } else if !activeNow {
        statusText.Text := "监听中 · 游戏在后台"
        statusText.SetFont("s10 bold cBlue")
    } else {
        statusText.Text := "监听中 · 游戏在前台，按 " cfgInputKey " 打开聊天"
        statusText.SetFont("s10 bold cGreen")
    }
}
; 托盘提示文本
UpdateTrayTip() {
    A_IconTip := AppName " " AppVer (armed ? " · 监听中" : "")
}

; ============================================================================
; 发送历史 —— HD2-CNChat 新增（原版无此功能）
; ============================================================================
GetHistory() {
    arr := []
    i := 1
    loop {
        v := IniRead(cfgPath, "History", i, "")
        if v = ""
            break
        arr.Push(v)
        i++
    }
    return arr
}
PushHistory(text) {
    if Trim(text, " `t`r`n") = ""
        return
    arr := GetHistory()
    arr.InsertAt(1, text)
    while arr.Length > cfgMaxHistory
        arr.Pop()
    IniDelete(cfgPath, "History")
    for i, v in arr
        IniWrite(v, cfgPath, "History", i)
}
ClearHistory() {
    IniDelete(cfgPath, "History")
}

; ============================================================================
; 主面板 —— HD2-CNChat 重写（原版为多游戏列表式界面，本版简化为单游戏助手面板）
; ============================================================================
BuildPanel() {
    W := 330
    global myGui := Gui("-Resize -MinimizeBox", AppName " " AppVer)
    myGui.MarginX := 10
    myGui.MarginY := 8
    myGui.SetFont("s10", "Microsoft YaHei UI")

    ; —— 游戏状态 ——
    myGui.AddGroupBox("Section w" W " h58", "游戏状态")
    global statusText := myGui.AddText("xs+10 ys+20 w" (W - 20) " cGray", "未启动监听")
    global matchInfoText := myGui.AddText("xs+10 y+4 w" (W - 20) " cSilver", "")
    matchInfoText.SetFont("s9")

    ; —— 发送设置 ——
    myGui.AddGroupBox("Section xs y+8 w" W " h64", "发送设置")
    global methodDDL := myGui.AddDropDownList("xs+10 ys+20 w" (W - 140) " Choose" cfgSendMethod, ["Unicode直发（推荐）", "GBK Alt码", "剪贴板粘贴", "PostMessage", "ControlSendText"])
    global fixGBtn := myGui.AddCheckbox("x+6 yp w90", "修复乱码")
    fixGBtn.Value := cfgFixGarbled
    myGui.AddText("xs+10 y+4 w" (W - 20) " cSilver", "无效时可到“手动发送”里调试其它方式").SetFont("s9")

    ; —— 操作按钮 ——
    global armBtn := myGui.AddButton("xs w" ((W - 16) // 2) " h36", "启动监听")
    armBtn.SetFont("bold s12 cGreen")
    global manualBtn := myGui.AddButton("x+6 yp wp h36", "手动发送")
    manualBtn.SetFont("bold s11")
    global popBtn := myGui.AddButton("xs y+4 w" (W - 20) " h26", "弹出输入条（测试）")
    popBtn.SetFont("s10")
    bw4 := (W - 30) // 4
    global histBtn := myGui.AddButton("xs y+6 w" bw4 " h26", "历史记录")
    global dbgBtn := myGui.AddButton("x+6 yp wp h26", "排障日志")
    global setBtn := myGui.AddButton("x+6 yp wp h26", "设置")
    global aboutBtn := myGui.AddButton("x+6 yp wp h26", "关于")

    myGui.Show("AutoSize Center")

    ; —— 事件 ——
    methodDDL.OnEvent("Change", MethodDDL_Change)
    fixGBtn.OnEvent("Click", FixG_Click)
    armBtn.OnEvent("Click", (*) => (armed ? Disarm() : Arm()))
    manualBtn.OnEvent("Click", (*) => BuildManualSend())
    popBtn.OnEvent("Click", (*) => ShowBar())
    histBtn.OnEvent("Click", (*) => BuildHistoryGui())
    dbgBtn.OnEvent("Click", ToggleDebug)
    setBtn.OnEvent("Click", (*) => BuildSettings())
    aboutBtn.OnEvent("Click", (*) => ShowAbout())
    myGui.OnEvent("Close", PanelClose)
    myGui.OnEvent("Escape", PanelClose)

    ; 排障日志开关
    ToggleDebug(*) {
        global isDebug := !isDebug
        if isDebug {
            DebugLog("排障日志已开启")
            DebugLog("快照: ver=" AppVer " armed=" armed " exists=" gameExistsNow " active=" gameActiveNow " sysEnter=" sysHkEnterReg " sysEsc=" sysHkEscReg " sysCEnter=" sysHkCEnterReg " barVisible=" barVisible " " DiagForeground())
            Tip3s("排障日志已开启：日志写入脚本目录 hd2cnc_debug.log")
            dbgBtn.Text := "排障日志●"
        } else {
            Tip3s("排障日志已关闭")
            dbgBtn.Text := "排障日志"
        }
    }

    MethodDDL_Change(*) {
        global cfgSendMethod := methodDDL.Value
        WriteCfg("sendMethod", cfgSendMethod)
    }
    FixG_Click(*) {
        global cfgFixGarbled := fixGBtn.Value
        WriteCfg("fixGarbled", cfgFixGarbled)
    }
    PanelClose(*) {
        myGui.Hide()
        return true
    }

    matchInfoText.Text := "匹配：" (GameMatchDesc() = "未配置" ? "未配置（请在设置中填写）" : GameMatchDesc())
}


; ============================================================================
; 历史记录窗口
; ============================================================================
BuildHistoryGui() {
    hg := Gui("+Owner" myGui.Hwnd " +ToolWindow", "发送历史（双击重发）")
    myGui.Opt("+Disabled")
    hg.MarginX := 10
    hg.MarginY := 8
    hg.SetFont("s10", "Microsoft YaHei UI")
    hg.AddGroupBox("Section w380 h220", "最近发送")
    lv := hg.AddListView("xs+10 ys+20 r8 w360 -Multi", ["内容"])
    lv.ModifyCol(1, 350)
    resendBtn := hg.AddButton("xs w88 h26", "重发选中")
    delBtn := hg.AddButton("x+6 yp wp hp", "删除选中")
    clearBtn := hg.AddButton("x+6 yp wp hp", "清空历史")
    closeBtn := hg.AddButton("x+6 yp wp hp", "关闭")

    RefreshHist() {
        lv.Delete()
        for v in GetHistory()
            lv.Add("", v)
    }
    GetSelHist() {
        sel := lv.GetNext(0)
        return sel ? sel : 0
    }
    CloseHist(*) {
        myGui.Opt("-Disabled")
        hg.Destroy()
    }
    ResendHist(*) {
        sel := GetSelHist()
        if !sel
            return
        hist := GetHistory()
        myGui.Opt("-Disabled")
        hg.Destroy()
        SendTextToGame(hist[sel], true)
    }
    DelSelHist(*) {
        sel := GetSelHist()
        if !sel
            return
        hist := GetHistory()
        hist.RemoveAt(sel)
        IniDelete(cfgPath, "History")
        for i, v in hist
            IniWrite(v, cfgPath, "History", i)
        RefreshHist()
    }
    ClearAllHist(*) {
        ClearHistory()
        RefreshHist()
    }

    hg.OnEvent("Close", CloseHist)
    closeBtn.OnEvent("Click", CloseHist)
    resendBtn.OnEvent("Click", ResendHist)
    delBtn.OnEvent("Click", DelSelHist)
    clearBtn.OnEvent("Click", ClearAllHist)
    lv.OnEvent("DoubleClick", ResendHist)

    hg.Show("AutoSize")
    RefreshHist()
}

; ============================================================================
; 手动发送窗口
; ============================================================================
BuildManualSend() {
    ms := Gui("+Owner" myGui.Hwnd " +ToolWindow", "手动发送")
    myGui.Opt("+Disabled")
    ms.MarginX := 10
    ms.MarginY := 8
    ms.SetFont("s10", "Microsoft YaHei UI")
    ms.AddGroupBox("Section w340 h150", "输入文字")
    txt := ms.AddEdit("xs+10 ys+20 r4 w320")
    txt.SetFont("s11")
    s1Btn := ms.AddButton("xs w160 h28", "发送文本（不回车）")
    s2Btn := ms.AddButton("x+6 yp wp hp", "发送并回车提交")
    ms.AddText("xs+10 y+4 w320 cSilver", "使用主面板当前选中的发送方式；发送前请先打开游戏聊天框（按 " cfgInputKey "）。").SetFont("s9")

    CloseMS(*) {
        myGui.Opt("-Disabled")
        ms.Destroy()
    }
    SendMS(enter) {
        t := txt.Text
        if Trim(t, " `t`r`n") = ""
            return
        err := SendTextToGame(t, enter)
        if err
            MsgBox(err, AppName, "Icon!")
        else
            txt.Text := ""
    }

    ms.OnEvent("Close", CloseMS)
    s1Btn.OnEvent("Click", (*) => SendMS(false))
    s2Btn.OnEvent("Click", (*) => SendMS(true))
    ms.Show("AutoSize")
}

; ============================================================================
; 设置窗口
; ============================================================================
BuildSettings() {
    sg := Gui("+Owner" myGui.Hwnd " +ToolWindow", "设置")
    myGui.Opt("+Disabled")
    sg.MarginX := 10
    sg.MarginY := 8
    sg.SetFont("s10", "Microsoft YaHei UI")

    sg.AddGroupBox("Section w340 h232", "基础设置")
    sg.AddText("xs+10 ys+22 w150", "开始输入键（与游戏聊天键一致）：")
    kEdit := sg.AddHotkey("x+4 yp w70", cfgInputKey)
    sg.AddText("xs+10 y+8 w150", "发送前等待（毫秒）：")
    dEdit := sg.AddEdit("x+4 yp w70 Number Limit4", cfgPreSendDelay)
    sg.AddText("xs+10 y+8 w150", "输入条宽度（400-900）：")
    wEdit := sg.AddEdit("x+4 yp w70 Number Limit3", cfgBarWidth)
    sg.AddText("xs+10 y+8 w150", "输入条字体大小（10-24）：")
    fEdit := sg.AddEdit("x+4 yp w70 Number Limit2", cfgFontSize)
    sg.AddText("xs+10 y+8 w150", "输入框最大字符数（50-1000）：")
    lEdit := sg.AddEdit("x+4 yp w70 Number Limit4", cfgMaxLen)

    sg.AddGroupBox("Section xs y+10 w340 h118", "游戏窗口匹配")
    sg.AddText("xs+10 ys+22 w110", "游戏进程名：")
    eEdit := sg.AddEdit("x+4 yp w200", cfgExe)
    sg.AddText("xs+10 y+8 w110", "窗口标题：")
    tEdit := sg.AddEdit("x+4 yp w200", cfgTitle)
    sg.AddText("xs+10 y+4 w320 cSilver", "进程名与标题任一命中即识别（标题用包含匹配，如 HELLDIVERS 可命中“HELLDIVERS™ 2”）").SetFont("s9")

    c1 := sg.AddCheckbox("xs+10 y+6 w160 Checked" cfgAutoHideBar, "输入条失焦自动隐藏")
    c2 := sg.AddCheckbox("xp y+6 wp Checked" cfgShowStatusTip, "显示屏幕状态提示")
    c3 := sg.AddCheckbox("xp y+6 wp Checked" cfgArmAtStart, "启动时自动开始监听")
    c4 := sg.AddCheckbox("xp y+6 wp Checked" cfgCheckAdmin, "启动时提示以管理员运行")

    saveBtn := sg.AddButton("xs w100 h28", "保存")
    cancelBtn := sg.AddButton("x+6 yp wp hp", "取消")
    sg.AddText("xs+10 y+4 w320 cSilver", "修改输入条宽度/字号后，下次打开输入条时生效。").SetFont("s9")

    CloseSG(*) {
        myGui.Opt("-Disabled")
        sg.Destroy()
    }
    SaveSettings(*) {
        key := NormalizeHotkey(kEdit.Value, "Enter")
        delay := Min(Max(NumOrDef(dEdit.Text, cfgPreSendDelay), 0), 3000)
        bw := Min(Max(NumOrDef(wEdit.Text, cfgBarWidth), 400), 900)
        fs := Min(Max(NumOrDef(fEdit.Text, cfgFontSize), 10), 24)
        ml := Min(Max(NumOrDef(lEdit.Text, cfgMaxLen), 50), 1000)
        exe := Trim(eEdit.Text)
        if exe != "" && SubStr(exe, -4) != ".exe" {
            MsgBox("进程名必须以 .exe 结尾（如 helldivers2.exe）！", AppName, "Icon!")
            return
        }
        title := Trim(tEdit.Text)
        if exe = "" && title = "" {
            MsgBox("进程名与窗口标题不能同时为空！", AppName, "Icon!")
            return
        }
        oldFs := cfgFontSize
        WriteCfg("inputKey", key)
        WriteCfg("preSendDelay", delay)
        WriteCfg("barWidth", bw)
        WriteCfg("fontSize", fs)
        WriteCfg("maxLen", ml)
        WriteCfg("gameExe", exe)
        WriteCfg("gameTitle", title)
        WriteCfg("autoHideBar", c1.Value)
        WriteCfg("showStatusTip", c2.Value)
        WriteCfg("armAtStart", c3.Value)
        WriteCfg("checkAdmin", c4.Value)
        LoadCfg()
        if armed
            RegisterChatKey()
        ; 布局参数变化时重建输入条
        if barGui && (bw != barW || oldFs != cfgFontSize)
            DestroyBar()
        matchInfoText.Text := "匹配：" (GameMatchDesc() = "未配置" ? "未配置" : GameMatchDesc())
        myGui.Opt("-Disabled")
        sg.Destroy()
    }

    sg.OnEvent("Close", CloseSG)
    cancelBtn.OnEvent("Click", CloseSG)
    saveBtn.OnEvent("Click", SaveSettings)
    sg.Show("AutoSize")
}

; ============================================================================
; 关于
; ============================================================================
ShowAbout(*) {
    text := AppName " " AppVer "
(
—— 绝地潜兵2 中文输入助手 ——
作者：崔素妍

【致谢】
特别感谢原作者 GameXueRen 的开源项目 GRW-CNChat（游戏无缝输入中文），
本工具基于其优秀的设计优化改写，输入条 UI 亦借鉴自该作品。
项目主页：https://github.com/GameXueRen/GRW-CNChat

【版权与许可】
基于 GRW-CNChat（GameXueRen, © 2024-2025, GPL v3）优化改写；
本程序以 GNU GPL v3（GPL-3.0-or-later）授权，详见 LICENSE。

【原理】
游戏内按“开始输入键”（默认 Enter）打开聊天时，
工具在游戏窗口底部弹出输入条，可直接使用系统中文输入法，
按 Enter 把文本模拟按键注入游戏聊天框并发送。

【快捷键】
开始输入 : Enter / 小键盘Enter（与游戏聊天键一致）
发送      : Enter
取消      : Esc
切换方式  : F9

【常见问题】
1. 发送后游戏内显示 ??? 乱码
   → 保持“修复乱码”勾选；或在启动游戏前先切换到中文输入法。
2. 发送无反应
   → 在“手动发送”里切换其它发送方式调试；
     仍无效请以管理员身份运行本工具。
3. 按 Enter 输入条不弹出
   → 按 Enter 时会显示原因提示：确认“监听中 · 游戏在前台”；
     游戏请使用“无边框窗口”或“窗口化”模式；全屏独占无法显示覆盖层。
4. 进程匹配失败
   → 在“设置”中确认进程名 helldivers2.exe 与窗口标题。

【免责声明】
本工具不修改游戏文件与内存，仅模拟键盘输入。
使用后果由使用者自行承担。
)"
    MsgBox(text, AppName, "OK")
}

; ============================================================================
; 托盘菜单与启动
; ============================================================================
ExitTool(*) {
    Disarm()
    UnregisterAllSysHotkeys()
    ExitApp()
}

tray := A_TrayMenu
tray.Delete()
tray.Add("打开面板", (*) => myGui.Show())
tray.Add("启动监听", (*) => Arm())
tray.Add("停止监听", (*) => Disarm())
tray.Add()
tray.Add("重新加载", (*) => Reload())
tray.Add("退出", ExitTool)
tray.Default := "打开面板"
; 使用自带的程序图标（存在时）
if FileExist(A_ScriptDir "\HD2-CNChat.ico")
    TraySetIcon(A_ScriptDir "\HD2-CNChat.ico")
A_IconTip := AppName " " AppVer

; —— 自检模式（内部测试用：验证输入条与发送引擎后退出） ——
if A_Args.Length && A_Args[1] = "selftest"
    Selftest()

; —— 启动流程 ——
LoadCfg()
BuildPanel()
; 启动日志：仅当之前开过排障日志时追加一行（确认实机运行的版本）
if FileExist(A_ScriptDir "\hd2cnc_debug.log") {
    now := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    try
        FileAppend("=== 启动 " AppName " " AppVer " args=[" A_Args.Join(",") "] " now " ===`n", A_ScriptDir "\hd2cnc_debug.log")
}
; Enter 热键全局常驻注册（AHK 钩子通道：游戏前台按 Enter 即可打开输入条）
; Ctrl+Enter 为备用通道（只要游戏进程存在即弹出输入框）
; 注意：本机 AHK v2.0.26 的 Hotkey() 只接受 lambda/BoundFunc 回调（直接传函数对象报
; Invalid callback function，曾导致钩子通道整体静默失效），统一用 lambda 包装
try {
    Hotkey("~*Enter", (*) => EnterKeyHandler(), "On")
    Hotkey("~*NumpadEnter", (*) => EnterKeyHandler(), "On")
    Hotkey("^Enter", (*) => ForceOpenInputBar(), "On")
    Hotkey("^NumpadEnter", (*) => ForceOpenInputBar(), "On")
    DebugLog("Enter 热键全局注册完成")
} catch as e {
    DebugLog("Enter 热键全局注册失败：" e.Message)
}
; Enter 系统热键常驻注册（Windows 内核处理，不依赖 AHK 钩子与状态轮询；
; v1.10：启动即注册，非游戏场景由回调重新注入 Enter 放行）
RegisterSysEnter()
; 常驻状态刷新（系统热键通道：Windows 内核处理，不依赖 AHK 钩子）
SetTimer(RefreshGameState, 250)
SetTimer(RefreshGameState, -10)
if cfgCheckAdmin && !A_IsAdmin {
    r := MsgBox("建议以管理员身份运行，可确保按键注入稳定生效。`n`n点击“是”以管理员身份重启，点击“否”继续普通运行。", AppName, "YesNo Icon!")
    if r = "Yes" {
        try {
            if A_IsCompiled
                Run '*RunAs "' A_ScriptFullPath '"'
            else
                Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
        }
        ExitApp
    }
}
if cfgArmAtStart
    Arm()

; ============================================================================
; 自检（selftest 参数启动时执行，输出结果到 selftest_result.txt 后退出）
; ============================================================================
Selftest() {
    res := ""
    Log(v) {
        res .= v "`n"
    }
    Finish(code := 0) {
        try
            FileAppend(res, A_ScriptDir "\selftest_result.txt")
        WinClose("CNTestTarget")
        ExitApp(code)
    }
    try {
        LoadCfg()
        Log("cfg=" cfgExe "," cfgTitle "," cfgInputKey "," cfgSendMethod)
        ; —— 窗口匹配函数（无游戏时应为 false/0） ——
        Log("match-exists=" GameExists() " active=" GameActive() " hwnd=" GameHwnd())
        CreateBar()
        Log("barOk=" (barHwnd ? "yes" : "no") " barW=" barW " barH=" barH)
        ; —— 输入条热键逐个注册测试 ——
        hkOut := ""
        try {
            Hotkey("~Esc Up", BarEsc, "On")
            Hotkey("~Esc Up", "Off")
            hkOut .= "esc-ok "
        } catch as e {
            hkOut .= "esc-FAIL:" e.Message " "
        }
        try {
            Hotkey("F9", CycleSendMethod, "On")
            Hotkey("F9", "Off")
            hkOut .= "f9-obj-ok "
        } catch as e {
            hkOut .= "f9-obj-FAIL:" e.Message " "
        }
        try {
            Hotkey("F9", "CycleSendMethod", "On")
            Hotkey("F9", "Off")
            hkOut .= "f9-name-ok "
        } catch as e {
            hkOut .= "f9-name-FAIL:" e.Message " "
        }
        try {
            Hotkey("F9", (*) => CycleSendMethod(), "On")
            Hotkey("F9", "Off")
            hkOut .= "f9-lambda-ok "
        } catch as e {
            hkOut .= "f9-lambda-FAIL:" e.Message " "
        }
        Log("hotkey-reg " hkOut)
        ; 启动目标窗口
        if !WinExist("CNTestTarget") {
            targetPath := FileExist(A_ScriptDir "\内部测试\target.ahk") ? A_ScriptDir "\内部测试\target.ahk" : A_ScriptDir "\target.ahk"
            Run '"' A_AhkPath '" "' targetPath '"'
            if !WinWaitActive("CNTestTarget", , 5) {
                Log("FAIL: 目标窗口未启动")
                Finish(1)
            }
        }
        ; 目标为 CNTestTarget
        global cfgExe := ""
        global cfgTitle := "CNTestTarget"
        global cfgPreSendDelay := 60
        ; —— 方法1 Unicode（先切英文布局，关闭 IME 干扰） ——
        global cfgSendMethod := 1
        global cfgFixGarbled := 1
        SwitchGameIME(0x04090409)
        WinActivate("CNTestTarget")
        WinWaitActive("CNTestTarget", , 2)
        ControlFocus("Edit1", "CNTestTarget")
        ControlSetText("", "Edit1", "CNTestTarget")
        err := SendTextToGame("测试中文ABC", false)
        Sleep 250
        Log("m1-unicode err=" err " text=[" ControlGetText("Edit1", "CNTestTarget") "]")
        ; —— 方法2 GBK Alt码 ——
        global cfgSendMethod := 2
        SwitchGameIME(0x08040804)
        ControlSetText("", "Edit1", "CNTestTarget")
        err := SendTextToGame("测试中文ABC", false)
        Sleep 250
        Log("m2-gbk err=" err " text=[" ControlGetText("Edit1", "CNTestTarget") "]")
        ; —— 方法3 剪贴板粘贴 ——
        global cfgSendMethod := 3
        ControlSetText("", "Edit1", "CNTestTarget")
        err := SendTextToGame("测试中文ABC", false)
        Sleep 250
        Log("m3-clip err=" err " text=[" ControlGetText("Edit1", "CNTestTarget") "]")
        ; —— 方法4 PostMessage（不断言） ——
        global cfgSendMethod := 4
        ControlSetText("", "Edit1", "CNTestTarget")
        err := SendTextToGame("测试中文ABC", false)
        Sleep 250
        Log("m4-post err=" err " text=[" ControlGetText("Edit1", "CNTestTarget") "]")
        ; —— 方法5 ControlSendText ——
        global cfgSendMethod := 5
        ControlSetText("", "Edit1", "CNTestTarget")
        err := SendTextToGame("测试中文ABC", false)
        Sleep 250
        Log("m5-cst err=" err " text=[" ControlGetText("Edit1", "CNTestTarget") "]")
        ; —— Enter 延迟发送流程（文本稳定检测 + 自动隐藏） ——
        global cfgSendMethod := 1
        global cfgExe := ""
        global cfgTitle := "CNTestTarget"
        ControlSetText("", "Edit1", "CNTestTarget")
        global barVisible := true
        barGui.Show()
        barEdit.Text := "你好测试"
        BarEnter()
        Sleep 900
        Log("enter-flow sent=[" ControlGetText("Edit1", "CNTestTarget") "] barVisible=" barVisible " text=[" barEdit.Text "]")
        ; —— Esc 退出流程 ——
        global barVisible := true
        barGui.Show()
        barEdit.Text := "abc"
        BarEsc()
        Sleep 600
        Log("esc-flow barVisible=" barVisible " text=[" barEdit.Text "]")
        ; —— EnterKeyHandler 分发：目标窗口激活时 → 应打开输入条 ——
        ; （先暂停 Enter 系统热键，模拟“仅钩子通道”场景——即运行时输入条可见期间的状态）
        if sysHkEnterReg {
            DllCall("UnregisterHotKey", "Ptr", A_ScriptHwnd, "Int", 0x4844)
            global sysHkEnterReg := false
        }
        EnterKeyHandler()
        Sleep 300
        Log("enterHandler-open barVisible=" barVisible " (目标激活时应为 1)")
        ; —— 系统热键通道端到端测试（RegisterHotKey） ——
        global barVisible := false
        barGui.Hide()
        WinActivate("CNTestTarget")
        ; 激活可能被系统前台锁延迟或外部程序抢焦点，重试等待（避免时序抖动误报）
        loop 5 {
            if GameActive()
                break
            Sleep 400
            WinActivate("CNTestTarget")
        }
        Log("syshk-active GameActive=" GameActive())
        Sleep 300
        if !sysHkEnterReg
            RegisterSysEnter()      ; v1.10：Enter 系统热键常驻注册（启动流程不经过 selftest）
        RefreshGameState()          ; 常驻状态刷新：目标激活 → 注册系统热键
        Sleep 300
        Log("syshk enterReg=" sysHkEnterReg " ctrlEnterReg=" sysHkCEnterReg)
        ; 注入前再确认前台（外部程序可能刚抢走焦点），被抢则重激活
        if !GameActive() {
            WinActivate("CNTestTarget")
            Sleep 300
        }
        SendInput("{Enter}")        ; 模拟按下 Enter（触发 AHK 钩子 + 系统热键双通道）
        Sleep 600
        Log("syshk-after-enter barVisible=" barVisible " (应为 1)")
        ; 注销系统热键（避免影响后续）
        global barVisible := false
        barGui.Hide()
        RefreshGameState()
        Sleep 200
        ; —— 历史记录 ——
        h := GetHistory()
        Log("history=" (h.Length ? h[1] : "(空)"))
        ; —— IME 切换 ——
        oldLay := SwitchGameIME(0x08040804)
        Log("imeSwitch old=" oldLay)
        ; 恢复默认配置
        global cfgExe := "helldivers2.exe"
        global cfgTitle := "HELLDIVERS"
        global cfgSendMethod := 1
        global cfgFixGarbled := 1
        ; —— 主面板 + 监听启动/停止冒烟测试 ——
        BuildPanel()
        Arm()
        Sleep 1500
        Log("armed=" armed " gameExists=" gameExistsNow)
        Disarm()
        Log("armedAfterDisarm=" armed)
        Log("DONE")
    } catch as e {
        Log("EXCEPTION: " e.Message " @line " e.Line)
    }
    Finish(0)
}
