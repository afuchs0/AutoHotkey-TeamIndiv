#Requires AutoHotkey v2.0

class Logger {
    __New(paths, config, state) {
        this.Paths := paths
        this.Config := config
        this.State := state
        this.UserName := A_UserName

        if !DirExist(this.Paths.Logs)
            try DirCreate(this.Paths.Logs)

        interval := 60000 * 60 ; Standard: 60 Minuten
        if (interval > 0 && this.Paths.LogNetworkDir != "")
            SetTimer(() => this.ExportLogs(), interval)
    }

    Log(text) {
        try {
            timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            
            ; Clean Newlines
            cleanText := StrReplace(text, "`r`n", "\n")
            cleanText := StrReplace(cleanText, "`n", "\n")
            cleanText := StrReplace(cleanText, "`r", "\n")

            logEntry := timestamp ";" this.UserName ";" cleanText "`n"
            
            ; Schreiben lokal (immer schnell)
            currentYear := FormatTime(, "yyyy")
            FileAppend(logEntry, this.Paths.Logs "\AHK_Log" currentYear ".txt", "UTF-8")
        } catch as err {
            OutputDebug("LOGGER FAILED: " err.Message)
        }
    }

    /**
     * ASYNCHRONE Export-Funktion
     * Nutzt CMD, um das Kopieren in einen Hintergrundprozess auszulagern.
     * Blockiert das Hauptskript NICHT.
     */
    ExportLogs() {
        ; 1. Check: OfflineMode (verhindert unnötige CMD-Starts)
        if (this.State.OfflineMode)
            return

        Loop Files, this.Paths.Logs "\*.txt" {
            if (InStr(A_LoopFileName, "AHK_Log") == 1) {
                
                ; Wir benennen die Datei um, damit sie nicht doppelt bearbeitet wird,
                ; während der Hintergrundprozess noch läuft.
                processingName := StrReplace(A_LoopFileName, ".txt", "_uploading.tmp")
                sourcePath := A_LoopFileDir "\" processingName
                
                try {
                    FileMove(A_LoopFileFullPath, sourcePath, 1)
                } catch {
                    continue ; Datei ist wohl gerade in Benutzung
                }

                targetPath := this.Paths.LogNetworkDir A_LoopFileName

                ; 2. Der Magic Trick: CMD ausführen
                ; /c = Führe Befehl aus und schließe
                ; chcp 65001 = Setze Codepage auf UTF-8 (wichtig für Umlaute!)
                ; type A >> B = Hänge Inhalt von A an B an
                ; && del A = Wenn erfolgreich, lösche A
                
                cmd := Format('{} /c chcp 65001 & type "{}" >> "{}" && del "{}"', A_ComSpec, sourcePath, targetPath, sourcePath)
                
                try {
                    ; "Hide" sorgt dafür, dass kein schwarzes Fenster aufpoppt
                    Run(cmd, , "Hide")
                } catch as err {
                    ; Falls der Start fehlschlägt, benennen wir zurück (Fallback)
                    try FileMove(sourcePath, A_LoopFileFullPath)
                }
            }
        }
    }
}