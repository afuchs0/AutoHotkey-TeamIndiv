#Requires AutoHotkey v2.0
#Include ..\Utils\GuiUtil.ahk

class DynamicListView {
    guiObj := ""
    lvObj := ""
    callback := ""
    dataArray := []
    lvOptions := ""
    defaultButtonName := ""
    keyDownHandler := "" 

    __New(title, headers, dataArray, callback, lvOptions:="") {
        this.title := title
        this.headers := StrSplit(headers, "|")
        this.dataArray := dataArray
        this.callback := callback
        this.lvOptions := lvOptions
        
        this.guiObj := Gui("+AlwaysOnTop +OwnDialogs", title)
        this.guiObj.SetFont("s9", "Segoe UI")
        
        this.guiObj.OnEvent("Escape", (*) => this.CleanupAndDestroy())
        this.guiObj.OnEvent("Close", (*) => this.CleanupAndDestroy())
    }

    Show(buttonNames, colWidths, useJoinsEdit := false) {
        widthArray := StrSplit(colWidths, "|")
        itemCount := this.dataArray.Length
        
        ; --- HÖHE BERECHNEN ---
        maxRowsOnScreen := Floor((A_ScreenHeight * 0.75) / 25)
        rowsToShow := (itemCount > maxRowsOnScreen) ? maxRowsOnScreen : itemCount
        
        if (rowsToShow < 1) {
            rowsToShow := 1
        }
        
        ; Grid = Gitter, Checked = Checkboxen, -Multi = Nur eine Zeile Fokusrahmen
        lvOpts := "Grid Checked -Multi r" . rowsToShow . " " . this.lvOptions
        
        this.lvObj := this.guiObj.Add("ListView", lvOpts, this.headers)
        this.lvObj.OnEvent("DoubleClick", (*) => this.HandleClick("DoubleClick"))

        if (useJoinsEdit) {
            this.guiObj.Add("Edit", "w200 vEdit1 Section") 
            this.guiObj.Add("Edit", "w200 ys vEdit2")      
        }

        btns := StrSplit(buttonNames, "|")
        
        for index, name in btns {
            opts := ""
            if (index = 1) {
                this.defaultButtonName := name
                ; WICHTIG: Kein "Default" hier, damit Space nicht geklaut wird.
                opts := (useJoinsEdit) ? "ys" : "Section"
            } else {
                opts := "ys"
            }
            
            ; Optik: Buttons etwas breiter machen
            opts .= " w100"

            btn := this.guiObj.Add("Button", opts, name)
            btn.OnEvent("Click", this.HandleClick.Bind(this, name))
        }

        this.lvObj.Opt("-Redraw") 
        for rowData in this.dataArray {
            if (rowData is Array) {
                this.lvObj.Add("", rowData*)
            } else {
                this.lvObj.Add("", rowData)
            }
        }
        this.lvObj.Opt("+Redraw")

        ; --- BREITE BERECHNEN ---
        totalWidth := 0
        loop this.lvObj.GetCount("Col") {
            this.lvObj.ModifyCol(A_Index, "AutoHdr")
            actualW := SendMessage(0x101D, A_Index - 1, 0, this.lvObj.Hwnd)
            
            maxW := (widthArray.Has(A_Index) && IsNumber(widthArray[A_Index])) ? widthArray[A_Index] : 9999
            
            if (actualW > maxW) {
                this.lvObj.ModifyCol(A_Index, maxW)
                actualW := maxW
            }
            totalWidth += actualW
        }
        
        ; Platz für Scrollbalken addieren
        if (itemCount > rowsToShow) {
            totalWidth += 30 
        } else {
            totalWidth += 10 
        }
        
        ; --- FIX FENSTERGRÖSSE: MINDESTBREITE ---
        ; Wenn die Spalten sehr schmal sind, wird das Fenster zu klein für die Buttons.
        ; Wir erzwingen mindestens 500 Pixel Breite.
        if (totalWidth < 500) {
            totalWidth := 500
        }

        ; ListView auf die berechnete Breite setzen
        this.lvObj.Move(,, totalWidth)
        
        ; Fenster anzeigen
        this.guiObj.Show("AutoSize Center")
        
        ; --- FIX FOKUS ---
        ; Wir nutzen wieder den Timer, da dies die einzig sichere Methode ist,
        ; um nach dem Rendern den Fokus auf die erste Zeile zu zwingen.
        SetTimer(this.ForceFocusAndSelect.Bind(this), -50)

        ; Enter-Hook aktivieren
        this.keyDownHandler := this.OnKeyDown.Bind(this)
        OnMessage(0x100, this.keyDownHandler)

        GuiUtil.EnableAutoClose(this.guiObj)
    }

    ; Diese Methode wird vom Timer aufgerufen (verzögert)
    ForceFocusAndSelect() {
        if (this.guiObj && this.lvObj) {
            try {
                WinActivate(this.guiObj.Hwnd)
                ControlFocus(this.lvObj.Hwnd)
                
                ; Erste Zeile markieren (Blau), falls vorhanden
                if (this.lvObj.GetCount() > 0) {
                    this.lvObj.Modify(1, "Select Focus") 
                }
            }
        }
    }

    OnKeyDown(wParam, lParam, msg, hwnd) {
        if (!this.guiObj || !WinActive(this.guiObj.Hwnd)) {
            return
        }

        ; ENTER (0x0D) -> Button auslösen
        if (wParam = 0x0D) {
            focusedHwnd := 0
            try {
                focusedHwnd := ControlGetFocus("A")
            }
            
            ; Wenn Fokus auf ListView -> Button auslösen
            if (focusedHwnd == this.lvObj.Hwnd) {
                this.HandleClick(this.defaultButtonName)
                return true ; Enter verschlucken
            }
        }
        
        ; LEERTASTE (0x20)
        ; Da der Timer den Fokus auf die ListView zwingt, 
        ; funktioniert Space hier automatisch korrekt (Checkbox umschalten).
        ; Wir müssen hier nichts tun.
    }

    HandleClick(btnName, *) {
        this.UnregisterMessage()
        selectedRows := []
        
        ; 1. Alle angehakten Zeilen
        RowNumber := 0
        Loop {
            RowNumber := this.lvObj.GetNext(RowNumber, "Checked")
            if (!RowNumber) {
                break 
            }
            if (RowNumber <= this.dataArray.Length) {
                selectedRows.Push(this.dataArray[RowNumber])
            }
        }

        ; 2. Fallback: Nur die markierte (blaue) Zeile, wenn keine Checkbox aktiv
        if (selectedRows.Length = 0) {
            focusedRow := this.lvObj.GetNext(0, "Focused") 
            if (focusedRow > 0 && focusedRow <= this.dataArray.Length) {
                selectedRows.Push(this.dataArray[focusedRow])
            }
        }

        valAlias1 := "", valAlias2 := ""
        try {
             valAlias1 := this.guiObj["Edit1"].Value
        }
        try {
             valAlias2 := this.guiObj["Edit2"].Value
        }

        this.guiObj.Destroy()
        this.guiObj := "" 
        
        result := {}
        if (btnName = "DoubleClick") {
            result.ButtonName := this.defaultButtonName
        } else {
            result.ButtonName := btnName
        }
            
        result.Rows   := selectedRows
        result.Alias1 := valAlias1
        result.Alias2 := valAlias2

        if (this.callback) {
            this.callback.Call(result)
        }
    }

    CleanupAndDestroy() {
        this.UnregisterMessage()
        if (this.guiObj) {
            this.guiObj.Destroy()
        }
    }

    UnregisterMessage() {
        if (this.keyDownHandler) {
            OnMessage(0x100, this.keyDownHandler, 0)
            this.keyDownHandler := ""
        }
    }
}