#Requires AutoHotkey v2.0

class AppPaths {
    ; Phase 1: Nur relative Pfade setzen
    __New() {
        this.Root   := A_ScriptDir
        this.Assets := this.Root "\Assets"

        this.SQL  := this.Assets "\SQL"
        this.Tabellenbeschreibung := this.SQL "\Tabellenbeschreibung"
        this.Fields := this.SQL "\Fields"
        this.Joins  := this.SQL "\Joins"
        this.Tables := this.SQL "\Tables"
        this.Scripts := this.SQL "\Scripts"
        
        this.Config := this.Assets "\Config"
        
        this.Lib    := this.Root "\Lib"

        this.Data   := this.Assets "\Data"

        this.SQL    := this.Assets "\SQL"

        this.Images := this.Assets "\Images"
        
        this.MacrosNetwork := ""
        this.Logs          := A_Temp "\AHK_Logs" 
        this.LogNetworkDir := "\\bmd.com\dfs\Docu\Support\ZentralerSupport\TeamIndiv\AutoHotkey\AHK_Log"
    }

    ; Phase 3: Externe Pfade aus der Config laden
    InitExternal(configProvider) {
        ; Netzwerkpfad laden (oder leer lassen)
        this.MacrosNetwork := configProvider.Get("Paths", "MacroShare", "")
        
        ; Log Pfad überschreiben, falls in Config definiert
        customLog := configProvider.Get("Paths", "LogDir", "")
        if (customLog != "")
            this.Logs := customLog

        ; Ordner erstellen, falls nötig
        if !DirExist(this.Logs)
            try DirCreate(this.Logs)
    }
}