#Requires AutoHotkey v2.0

class ConfigProvider {
    __New(appPaths) {
        configDir := appPaths.Config
        
        this.GlobalFile := configDir "\settings.global.ini"
        this.UserFile   := configDir "\settings.user.ini"
        
        if !FileExist(this.GlobalFile)
            throw Error("Globale Config fehlt: " this.GlobalFile)
    }

    /**
     * Set: Schreibt einen Wert in die User-INI
     * Wandelt Zeilenumbrüche für die INI um.
     */
    Set(section, key, value) {
        ; Konvertiere boolesche Werte zu 1/0, sonst String
        valToWrite := value
        if (Type(value) = "Integer" && (value = 0 || value = 1))
            valToWrite := value
        else
            valToWrite := String(value)

        ; Rückumwandlung von echten Zeilenumbrüchen in \n für die INI
        valToWrite := StrReplace(valToWrite, "`n", "\n")

        try {
            IniWrite(valToWrite, this.UserFile, section, key)
        } catch Error as e {
            MsgBox("Fehler beim Speichern der Config: " e.Message)
        }
    }

    /**
     * Get: Holt einen Wert, löst \n auf und ersetzt rekursiv {config "..."}
     * @param section Die INI Sektion
     * @param key Der INI Schlüssel
     * @param defaultVal Rückgabewert, falls Key nicht gefunden wird
     * @param recursionStack (Intern) Verhindert Endlosschleifen bei gegenseitigen Verweisen
     */
    Get(section, key, defaultVal := "", recursionStack := Map()) {
        ; --- SCHUTZ VOR ENDLOSSCHLEIFEN ---
        ; Wir erstellen eine eindeutige ID für diesen Aufruf (z.B. "Settings.logbegin")
        uniqueKeyID := StrLower(section "." key)
        
        if recursionStack.Has(uniqueKeyID) {
            ; Wenn wir diesen Key im aktuellen Durchlauf schon hatten, brechen wir ab.
            return "!CIRCULAR_REF!" 
        }
        recursionStack[uniqueKeyID] := true

        ; --- 1. ROHDATEN LESEN (User > Global) ---
        val := ""
        found := false

        ; Versuch: User Config (ohne Default-Parameter wirft IniRead Error bei "nicht gefunden")
        try {
            val := IniRead(this.UserFile, section, key)
            found := true
        } catch {
            ; Versuch: Globale Config
            try {
                val := IniRead(this.GlobalFile, section, key)
                found := true
            }
        }
        
        ; Wenn nirgends gefunden, Default zurückgeben (und Rekursion beenden)
        if (!found)
            return defaultVal

        ; --- 2. FORMATIERUNG (\n -> Zeilenumbruch) ---
        val := StrReplace(val, "\n", "`n")

        ; --- 3. REKURSIVE AUFLÖSUNG von {config "..."} ---
        ; Regex sucht nach {config "KeyName"} (Case Insensitive durch 'i)')
        while RegExMatch(val, 'i)\{config\s+"(.*?)"\}', &match) {
            placeholderFull := match[0]  ; Der ganze String: {config "Key"}
            lookupKey       := match[1]  ; Der Inhalt: Key
            
            ; Rekursiver Aufruf: Wir geben den recursionStack weiter!
            replacement := this.Get(section, lookupKey, "", recursionStack)
            
            ; Fallback: Wenn im aktuellen Bereich nicht gefunden, suche in [Settings]
            if (replacement = "" && section != "Settings") {
                replacement := this.Get("Settings", lookupKey, "", recursionStack)
            }
            
            ; Ersetzung durchführen
            val := StrReplace(val, placeholderFull, replacement)
        }

        return val
    }
}