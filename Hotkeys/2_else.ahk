#Requires AutoHotkey v2.0

; --- GRUPPE 1: Allgemeines (Gilt überall, außer beim Tippen) ---
#HotIf !App.State.IsTyping 

    ; Esc hat eigene Fenster-Logik (muss auch bei Popups greifen, die nicht "TargetWindow" sind)
    $Esc:: App.Services.General.HandleEsc(WinGetTitle("A"))

    ; Command Palette (soll auch überall aufgehen, verhält sich aber im Editor anders)
    ^Space:: App.Services.General.HandleCtrlSpace(IsTargetWindow(), WinGetTitle("A"))

    ; Snippets GUI
    ^+b:: App.Services.General.HandleStrgShiftB()

#HotIf ; Reset
