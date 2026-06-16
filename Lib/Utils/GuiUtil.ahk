#Requires AutoHotkey v2.0

class GuiUtil {
    /**
     * Shows a GUI object centered on the monitor containing the Active Window.
     */
    static ShowCentered(gObj, options := "") {
        try {
            ; Calculate dimensions without showing
            gObj.Opt("+LastFound")
            gObj.Show("Hide " . options)
            gObj.GetPos(,, &GuiW, &GuiH)

            monIndex := this.GetActiveMonitor()
            MonitorGetWorkArea(monIndex, &MonLeft, &MonTop, &MonRight, &MonBottom)

            monWidth := MonRight - MonLeft
            monHeight := MonBottom - MonTop

            x := MonLeft + (monWidth - GuiW) / 2
            y := MonTop + (monHeight - GuiH) / 2

            gObj.Show(options . " x" . x . " y" . y)
        } catch as e {
            ; Fallback if monitor detection fails
            gObj.Show(options . " Center")
        }
    }

    /**
     * Aktiviert das automatische Schließen des Fensters, 
     * sobald es den Fokus verliert (in den Hintergrund gerät).
     * @param {Gui} gObj - Das GUI-Objekt
     */
    static EnableAutoClose(gObj) {
        ; Define a closure function (Standard v2.0 Syntax)
        CheckFocus() {
            try {
                ; Prüfen, ob das GUI-Objekt noch existiert und ob es NICHT mehr aktiv ist
                if (WinExist(gObj.Hwnd) && !WinActive(gObj.Hwnd)) {
                    gObj.Destroy()
                    SetTimer(CheckFocus, 0) ; Timer ausschalten
                }
            } catch {
                SetTimer(CheckFocus, 0) ; Falls GUI schon weg ist, Timer stoppen
            }
        }
        
        ; Prüfung alle 100ms starten
        SetTimer(CheckFocus, 100)
    }

    static GetActiveMonitor() {
        try {
            hwnd := WinExist("A")
            if (hwnd) {
                WinGetPos(&winX, &winY, &winW, &winH, hwnd)
                centerX := winX + (winW / 2)
                centerY := winY + (winH / 2)
                
                loop MonitorGetCount() {
                    MonitorGet(A_Index, &mL, &mT, &mR, &mB)
                    if (centerX >= mL && centerX <= mR && centerY >= mT && centerY <= mB)
                        return A_Index
                }
            }
        }
        return MonitorGetPrimary()
    }
}