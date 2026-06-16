#Requires AutoHotkey v2.0

IsTargetWindow() {
    try {
        target := App.Config.Get("Settings", "allowWithoutAsking", "")
        return target != "" && InStr(target, WinGetTitle("A"))
    } catch {
        return false 
    }
}

IsFeatureEnabled(keyName) {
    try {
        return App.Config.Get("Settings", keyName, "off") == "on"
    } catch {
        return false
    }
}

F1:: App.Config.Get("Settings", "logMittelteil", "")
; ==============================================================================
; HOTKEY BINDINGS
; ==============================================================================


; --- GRUPPE 2: Editor-Spezifisch (Nur im Ziel-Fenster UND nicht beim Tippen) ---
; Hier sparen wir uns das "else Send {F1}", weil AHK das automatisch macht,
; wenn die Bedingung nicht zutrifft.

#HotIf !App.State.IsTyping && IsTargetWindow()

    F1:: App.Services.General.HandleF1()
    F2:: App.Services.General.HandleF2()
    F3:: App.Services.General.HandleF3()

    $F4::  App.Services.General.HandleF4(false)
    $+F4:: App.Services.General.HandleF4(true)

    F5::  App.Services.General.HandleF5()
    F6::  App.Services.General.HandleF6()
    F7::  App.Services.General.HandleF7()
    F8::  App.Services.General.HandleF8()
    F9::  App.Services.General.HandleF9()
    F10:: App.Services.General.HandleF10()
    F11:: App.Services.General.HandleF11()
    F12:: App.Services.General.HandleF12()

    ; Navigation & Editing
    ; Hier prüfen wir im #HotIf ZUSÄTZLICH die Config für das spezifische Feature.
    ; Wenn Config aus ist -> Standardverhalten.
    
    $Home:: {
        if IsFeatureEnabled("homekey") && !GetKeyState("Shift", "P")
            App.Services.General.HandleHome()
        else
            Send "{Home}"
    }

    $End:: {
        if IsFeatureEnabled("endkey") && !GetKeyState("Shift", "P")
            App.Services.General.HandleEnd()
        else
            Send "{End}"
    }

    $':: {
        if IsFeatureEnabled("singlequote")
            App.Services.General.HandleSingleQuote()
        else 
            Send "'"
    }

    $(:: {
        if IsFeatureEnabled("CloseBracket")
            App.Services.General.HandleBracket()
        else
            Send "("
    }

    ; String Concatenation
    ^$+:: App.Services.General.HandleCtrlPlus()

    ; Ctrl+Enter (meist global okay)
    ^Enter:: App.Services.General.HandleCtrlEnter()
#HotIf

