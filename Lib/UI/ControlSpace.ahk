#Requires AutoHotkey v2.0
#Include ..\Utils\GuiUtil.ahk 

class ControlSpace {
    __New(state, configProvider, paths, ui) {
        this.State := state
        this.Config := configProvider
        this.Paths := paths
        this.ui := ui
        this.ControlSpaceProcessor := ControlSpaceProcessor(this.State, this.Config, this.Paths, this.ui)
        this.EditCtrl := ""
    }

    Show(prefilledText := "") {
        try title := WinGetTitle("A")
        catch
            title := "Unbekannt"

        g := Gui("+AlwaysOnTop +ToolWindow", "AutoHotkey Strg Space")
        g.SetFont("s12", "Calibri")
        g.BackColor := "White"

        ; --- Layout und Text ---
        g.Add("Text",, "AutoHotkey Suche in folgendem Fenster ausführen?")
        g.SetFont("cRed bold")
        g.Add("Text", "yp+25 w600", '"' title '"')
        g.SetFont("cDefault norm")
        g.Add("Text", "yp+30", "Hilfe: Strg+Shift+B -> F2")

        desc := this.Config.Get("Snippets", "Description", "Befehle: QueryPER, KeyPER, gvMCA..., spLNAME, Join...")
        g.SetFont("s9", "Consolas")
        g.Add("Text", "yp+30", desc)

        ; --- Edit & Button ---
        g.SetFont("s12", "Consolas")
        this.EditCtrl := g.Add("Edit", "y+20 w450 h30 vCommand", prefilledText)
        
        g.SetFont("s12", "Calibri")
        ; Button definieren
        btn := g.Add("Button", "x+10 yp w120 h30 Default", "Akzeptieren")
        
        ; --- Events ---
        btn.OnEvent("Click", (*) => this.Submit(g, title))
        g.OnEvent("Escape", (*) => g.Destroy())
        g.OnEvent("Close", (*) => g.Destroy())

        ; --- ANZEIGEN ---
        GuiUtil.ShowCentered(g)
        
        ; NEU: Cursor ans Ende setzen (hebt die Markierung auf)
        ControlSend("{End}", this.EditCtrl)

        ; 2. Auto-Close aktivieren (via GuiUtil)
        GuiUtil.EnableAutoClose(g)
    }

    Submit(gObj, originalTitle) {
        saved := gObj.Submit()
        cmd := saved.Command
        gObj.Destroy()
        
        if (cmd != "") {
            this.State.SetBusy(true)
            try {
                this.ControlSpaceProcessor.Process(cmd, originalTitle)
            } finally {
                this.State.SetBusy(false)
            }
        }
    }
}