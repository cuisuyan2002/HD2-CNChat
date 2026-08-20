; ============================================================================
; target.ahk —— HD2-CNChat 的 selftest 自检辅助脚本（目标窗口）
; Copyright (C) 2025-2026 崔素妍 及贡献者
; 本程序是自由软件，以 GNU GPL v3（GPL-3.0-or-later）授权，详见随附 LICENSE。
; ============================================================================
; 自检用目标窗口：提供一个可接收文本的编辑框
#Requires AutoHotkey v2.0
#SingleInstance Force
g := Gui("+AlwaysOnTop", "CNTestTarget")
g.AddText("w300", "自检目标窗口")
e := g.AddEdit("w300 r3 vTargetEdit")
; 关闭编辑框的 IME 合成上下文（模拟游戏聊天框无 IME 的状态）
hIMC := DllCall("Imm32.dll\ImmGetContext", "Ptr", e.Hwnd, "Ptr")
if hIMC {
    DllCall("Imm32.dll\ImmSetOpenStatus", "Ptr", hIMC, "Int", 0)
    DllCall("Imm32.dll\ImmReleaseContext", "Ptr", e.Hwnd, "Ptr", hIMC)
}
g.Show()
