#Requires AutoHotkey v2.0

class GeneralHotkeys {
    /**
     * @param {AppState} state
     * @param {ConfigProvider} config
     * @param {Object} ui
     * @param {AppPaths} appPaths
     * @param {ControlSpaceProcessor} csProcessor
     * @param {Logger} logger
     */
    __New(state, config, ui, appPaths, csProcessor, logger) {
        this.State       := state
        this.Config      := config
        this.UI          := ui
        this.AppPaths    := appPaths
        this.CsProcessor := csProcessor
        this.Logger      := logger
    }

    ; ==============================================================================
    ; LOGIK-METHODEN (Aufgerufen von den Hotkeys unten)
    ; ==============================================================================

    HandleF1() {
        KeyWait "F1"
        ; TODO: Inhalt von f1()
        logFiles := this.Config.Get("Settings", "F1Logdateien")
        this.Logger.Log("F1;F1Logdateien: " logFiles)
    }

    ; Wird nur aufgerufen, wenn Hotkey-Check für Editor erfolgreich war
    HandleF2() {
        this.Logger.Log("F2 (Editor Logic)")
        ; TODO: Inhalt von f2()
    }

    HandleF3() {
        KeyWait "F3"
        ; TODO: Inhalt von f3()
        this.Logger.Log("F3")
    }

    HandleF4(shift := false) {
        KeyWait "F4"
        if (shift) {
            this.Logger.Log("ShiftF4")
            ; TODO: Shiftf4()
        } else {
            this.Logger.Log("F4")
            ; TODO: f4()
        }
    }

    HandleF5() {
        KeyWait "F5"
        this.Logger.Log("F5")
    }

    HandleF6() {
        KeyWait "F6"
        this.Logger.Log("F6")
    }

    HandleF7() {
        KeyWait "F7"
        this.Logger.Log("F7")
    }

    HandleF8() {
        KeyWait "F8"
        this.Logger.Log("F8")
    }

    HandleF9() {
        this.State.SetBusy(true)
        try {
            configArchiv := this.Config.Get("Settings", "F9Archivierung", "off")
            clip := ""

            if (configArchiv != "off") {
                SendInput "^a"
                Sleep 50
                clip := ClipboardUtil.CopyAndRestore()
                SendInput "{Right}{Left}"
            }

            SendInput "^s"
            Sleep 50
            SendInput "{F9}"

            if (configArchiv != "off") {
                ; TODO: Archivierung logic
            }
            this.Logger.Log("F9;Archivierung: " configArchiv)
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleF10() {
        KeyWait "F10"
        this.Logger.Log("F10")
    }

    HandleF11() {
        KeyWait "F11"
        this.Logger.Log("F11")
    }

    HandleF12() {
        KeyWait "F12"
        this.Logger.Log("F12")
    }

    HandleHome() {
        this.State.SetBusy(true)
        try {
            SendInput "+{Home}"
            Sleep 20
            line := ClipboardUtil.CopyAndRestore()
            
            lenGesamt := StrLen(line)
            lenToMoveRight := lenGesamt - StrLen(LTrim(line, " `t")) 

            if (lenToMoveRight == lenGesamt || lenToMoveRight == 0) {
                SendInput "{Home}"
            } else {
                SendInput "^{Right}"
            }
            this.Logger.Log("Home")
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleEnd() {
        this.State.SetBusy(true)
        try {
            SendInput "+{End}"
            Sleep 20
            line := ClipboardUtil.CopyAndRestore()

            lenGesamt := StrLen(line)
            lenToMoveLeft := lenGesamt - StrLen(RTrim(line, " `t"))

            if (lenToMoveLeft == 0) {
                SendInput "{Left}{Right}"
            } else if (lenToMoveLeft == lenGesamt) {
                SendInput "{End}"
            } else {
                SendInput "{Right}"
                loop lenToMoveLeft + 1 {
                    SendInput "{Backspace}"
                }
                Sleep 50
            }
            this.Logger.Log("End")
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleSingleQuote() {
        SendInput "'"
        SendInput "'{Left}"
        this.Logger.Log("Quote")
    }

    HandleBracket() {
        SendInput "("
        SendInput "){Left}"
        this.Logger.Log("Bracket")
    }

    HandleCtrlPlus() {
        this.State.SetBusy(true)
        try {
            KeyWait "Control"
            SendInput '"' " {+}  {+} " '"'
            SendInput "{Left 5}"
            this.Logger.Log("Ctrl Plus")
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleCtrlEnter() {
        this.Logger.Log("SpecialEnter")
        SendInput "^{Enter}" 
    }

    HandleEsc(title) {
        ; Schließ-Logik für spezifische Fenster
        titlesToClose := ["Fill", "Verfügbare Joins", "Verfügbare Views", "Felder", "Lösche Terminvorschläge"]
        
        for t in titlesToClose {
            if (title = t) {
                WinClose("A") 
                SendInput "^{Right}"
                this.Logger.Log("ESC;" title)
                return
            }
        }

        if (title = "AutoHotkey SQL Formatter") {
            SendInput "!{F4}"
            this.Logger.Log("ESC;" title)
        }
        else if (InStr(title, "AHK Hilfe") || (InStr(title, "Autohotkey") == 1 && !InStr(title, "TicketPool"))) {
             this.Logger.Log("ESC;" title)
             WinClose("A")
        }
        else {
            SendInput "{Esc}"
        }
    }

    HandleStrgShiftB() {
        if (this.UI.HasProp("EditorGui")) {
            this.UI.EditorGui.Show()
        }
    }

    HandleCtrlSpace(isSafeWindow, winTitle) {
        this.State.SetBusy(true)
        try {
            GeneralHotkeys.WaitAllModifiersUp()         ; ← alle Modifier abwarten
            SendInput "^+{Left}"
            selectedText := ClipboardUtil.CopyAndRestore()
            KeyWait "Shift"          ; warten bis Shift losgelassen = Selektion abgeschlossen
            selectedText := ClipboardUtil.CopyAndRestore()

            if (isSafeWindow) {
                this.CsProcessor.Process(selectedText, winTitle)
            } else {
                this.UI.ControlSpace.Show(selectedText)
            }
        } finally {
            this.State.SetBusy(false)
            this.Logger.Log("CtrlSpace")
        }
    }


    static WaitAllModifiersUp() {
        modifiers := ["LControl", "RControl", "LShift", "RShift", "LAlt", "RAlt", "LWin", "RWin"]
        for key in modifiers {
            KeyWait(key)  ; blockiert pro Taste bis sie oben ist, kein Polling
        }
    }
}