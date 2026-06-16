#Requires AutoHotkey v2.0

class AppState {
    ; Global State Flags
    IsTyping := false
    OfflineMode := true ; Standardmäßig Offline
    
    ; Speichert den letzten Suchbegriff (ehemals global LastSearch)
    LastSearchTerm := ""
    
    ; Speichert Kontext-Daten
    CurrentTicketId := ""

    __New() {
        this.CheckConnectivity()
        ; Prüfe alle 60 Sekunden
        SetTimer(() => this.CheckConnectivity(), 60000) 
    }

    SetBusy(busy := true) {
        this.IsTyping := busy
    }

    /**
     * Prüft nur, ob der Server erreichbar ist.
     * Keine IP-Prüfung mehr.
     */
    CheckConnectivity() {
        try {
            if DirExist("\\bmd.com\dfs") {
                this.OfflineMode := false
            } else {
                this.OfflineMode := true
            }
        } catch {
            this.OfflineMode := true
        }
    }
}