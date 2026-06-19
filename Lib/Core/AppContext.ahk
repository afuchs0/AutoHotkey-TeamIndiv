#Requires AutoHotkey v2.0
class AppContext {
    Paths := ""
    Config := ""
    State := ""
    Services := {}
    UI := {}

    ; Der Konstruktor baut die App zusammen
    __New() {
        ; --- Core Components ---
        this.Paths  := AppPaths()
        
        ; Config braucht Paths
        this.Config := ConfigProvider(this.Paths)
        
        
        ; State (Datenhaltung)
        this.State  := AppState()

        this.Logger := Logger(this.Paths, this.Config, this.State)

        ; --- UI / Mockups ---
        this.UI := {}
        this.UI.ControlSpace := ControlSpace(this.State, this.Config, this.Paths, this.UI)
        this.UI.DynamicListView := DynamicListView

        ; --- Services ---
        this.Services := {}
        this.Services.ControlSpaceProcessor := ControlSpaceProcessor(this.State, this.Config, this.Paths, this.UI)
        
        ; GeneralHotkeys brauchen fast alles
        this.Services.General := GeneralHotkeys(
            this.State, 
            this.Config, 
            this.UI, 
            this.Paths,
            this.Services.ControlSpaceProcessor,
            this.Logger ; <--- Hier wird der Logger injiziert
        )
        
    }
}