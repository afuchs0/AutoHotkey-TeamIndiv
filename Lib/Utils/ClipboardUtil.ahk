#Requires AutoHotkey v2.0

class ClipboardUtil {
    
    ; --------------------------------------------------------------------------------
    ; 1. COPY
    ; Kopiert die aktuelle Auswahl in die Zwischenablage und gibt den Text zurück.
    ; Überschreibt die aktuelle Zwischenablage.
    ; --------------------------------------------------------------------------------
    static Copy(timeout := 0.5) {
        A_Clipboard := ""             ; Clipboard leeren für ClipWait
        SendInput "^c"                ; STRG+C senden
        if !ClipWait(timeout)         ; Warten bis Text verfügbar ist
            return ""                 ; Nichts markiert oder Timeout
        return A_Clipboard
    }

    ; --------------------------------------------------------------------------------
    ; 2. PASTE
    ; Fügt den übergebenen Text über die Zwischenablage ein.
    ; Überschreibt die aktuelle Zwischenablage dauerhaft mit 'text'.
    ; --------------------------------------------------------------------------------
    static Paste(text) {
        A_Clipboard := text
        SendInput "^v"
        Sleep 100                    ; Warten, damit Windows den Paste-Befehl verarbeitet
    }

    ; --------------------------------------------------------------------------------
    ; 3. RESTORE
    ; Stellt einen zuvor gespeicherten Zwischenablagen-Inhalt wieder her.
    ; 'savedData' muss das Ergebnis eines früheren `ClipboardAll()` Aufrufs sein.
    ; --------------------------------------------------------------------------------
    static Restore(savedData) {
        if (savedData != "") {
            A_Clipboard := savedData
        }
    }

    ; --------------------------------------------------------------------------------
    ; 4. PASTE AND RESTORE
    ; Fügt Text ein, ohne den ursprünglichen Inhalt der Zwischenablage zu verlieren.
    ; (Backup -> Einfügen -> Restore)
    ; --------------------------------------------------------------------------------
    static PasteAndRestore(text) {
        savedClip := ClipboardAll()   ; 1. Backup erstellen
        
        A_Clipboard := text           ; 2. Text in Clipboard
        SendInput "^v"                ; 3. Einfügen
        Sleep 150                     ; Wichtig: Zeit geben, bevor wir den Inhalt wieder ändern!
        
        A_Clipboard := savedClip      ; 4. Backup wiederherstellen
    }

    ; --------------------------------------------------------------------------------
    ; 5. COPY AND RESTORE (Safe Copy)
    ; Kopiert den markierten Text und gibt ihn zurück, aber setzt danach
    ; die Zwischenablage wieder auf den Zustand vor dem Kopieren zurück.
    ; (Ideal, um Text zu lesen, ohne den User-Clipboard-Flow zu stören)
    ; --------------------------------------------------------------------------------
    static CopyAndRestore(timeout := 0.5, retries := 3) {
        savedClip := ClipboardAll()
        
        loop retries {
            A_Clipboard := ""
            SendInput "^c"
            if ClipWait(timeout) {
                capturedText := A_Clipboard
                A_Clipboard := savedClip
                return capturedText
            }
        }
        
        A_Clipboard := savedClip
        return ""
    }
}