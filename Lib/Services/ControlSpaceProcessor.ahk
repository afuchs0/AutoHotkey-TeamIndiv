#Requires AutoHotkey v2.0

class ControlSpaceProcessor {
    __New(appState, configProvider, paths, ui) {
        this.State := appState
        this.Config := configProvider
        this.Paths := paths
        this.UI := ui
    }

    ; ==============================================================================
    ; HAUPTEINSTIEGSPUNKT
    ; ==============================================================================
    Process(clip, originalTitle, skip := "") {
        
        ; 1. Sicherheitscheck: Fokus sicherstellen
        if !this.EnsureWindowFocus(originalTitle)
            return

        if (InStr(clip, "`n") || InStr(clip, "`r"))
            return

        ; 2. Befehl parsen (Sonderzeichen trennen)
        parsed := this.ParseCommandPrefix(clip)
        prefix := parsed.Prefix
        cmd    := parsed.Cmd

        ; 3. Aliases auflösen (q -> query)
        if (cmd = "q")
            cmd := "query"

        ; 4. Logik-Verteiler
        if (SubStr(cmd, 1, 5) = "query") {
            this.HandleSQLCommand(cmd, prefix, "query", originalTitle)
        }
        else if (SubStr(cmd, 1, 6) = "update") {
            this.HandleSQLCommand(cmd, prefix, "update", originalTitle)
        }
        else if (this.Config.Get("Snippets", cmd, "") != "") {
            this.SendConfig(cmd, prefix)
        }
        else if (InStr(cmd, "sp") = 1 && StrLen(cmd) != 3) ; SETPARAMASSTRING
        {
            SendInput "{Raw}" prefix
            textVal := SubStr(cmd, 3)
            ; In v2 müssen Variablen in Strings mit Punkten verbunden werden
            SendInput "lQuery.setParamAsString('" textVal "'," textVal ");"
        }
        else if (InStr(cmd, "key") = 1 && cmd != "key") ; GIBT ALLE KEYS EINER TABELLE AUS
        {
            SendInput "{Raw}" prefix
            this.Print("key" cmd, 0, "%ConstName%", "keys")
        }
        else if (InStr(cmd, "andkey") = 1) ; GIBT ALLE KEY EINER TABELLE AUS MIT AND
        {
            SendInput "{Raw}" prefix
            
            ; Variable neu zuweisen
            cmd := SubStr(cmd, 4)
            
            ; Hinweis: {+} in v1 wird in v2 normal als + gesendet, wenn nicht im Raw-Modus
            this.Print("key" cmd, 0, " %ConstName% = ' +`n'", "keyw")
        }
        else if (InStr(cmd, "gv") = 1 && StrLen(cmd) != 3) ; GET VALUE
        {
            SendInput "{Raw}" prefix
            this.Print(cmd, 1, "%varname% := lModel.getValue('%ConstName%');`n", "gv")
        }
        else if (InStr(cmd, "gov") = 1 && StrLen(cmd) != 3) ; GET OLD VALUE
        {
            SendInput "{Raw}" prefix
            this.Print(cmd, 1, "%varname% := lModel.GetOldDataValue('%ConstName%');`n", "gov")
        }
        else if (InStr(cmd, "sv") = 1 && StrLen(cmd) != 3) ; SET VALUE
        {
            SendInput "{Raw}" prefix
            this.Print(cmd, 1, "lModel.setValue('%ConstName%', %varname%);`n", "sv")
        }
        else if (InStr(cmd, "gas") = 1) ; GetAsString
        {
            SendInput "{Raw}" prefix
            ; getConfig("QueryVar") wird hier direkt im Funktionsaufruf ausgewertet
            this.Print(cmd, 0, "%varname% := " this.Config.Get("Snippets","QueryVar") ".getAsString('%ConstName%');`n", "gas")
        }
        ; --- Komplexe Suchen (Joins, Felder, etc.) ---
        else if (this.IsJoinSearch(cmd)) {
            this.HandleJoinSearch(cmd, prefix)
        }
        else if (this.IsMCASearch(cmd)) {
            this.HandleMCASearch(cmd, prefix)
        }
        else if (this.IsFieldSearch(cmd)) {
            this.HandleFieldSearch(cmd, prefix)
        }
        else if (this.IsViewSearch(cmd)) {
            this.HandleViewSearch(cmd, prefix)
        }
        else if (this.IsTableSearch(cmd)) {
            this.HandleTableSearch(cmd, prefix)
        }
        ; --- Fallback ---
        else {
            Loop StrLen(prefix . cmd) {
                SendInput "{Right}"
            }
            
        }

    }

; =================================================================
    ; ENTSCHEIDUNGS-METHODEN (Is...)
    ; =================================================================
    IsViewSearch(cmd) {
        ; Logic: "view" am Anfang, länger als 4 Zeichen
        if (SubStr(cmd, 1, 4) != "view" || StrLen(cmd) <= 4)
            return false

        viewName := SubStr(cmd, 5)
        
        ; Prüfen, ob Daten über die Datei-Funktion gefunden werden
        data := this.GetViewDataFromFile(viewName)
        return (data.Length > 0)
    }

    IsTableSearch(cmd) {
        ; Logic: Länge 3
        if (StrLen(cmd) != 3)
            return false

        ; A) Interne Suche hat Treffer
        if (this.SearchTable(cmd) != "")
            return true

        ; B) ODER: Externe Datei hat Treffer (z.B. .BIL_)
        ; Hinweis: In V1 hast du "." cmd "_" übergeben
        data := this.GetViewDataFromFile("." . cmd . "_")
        return (data.Length > 0)
    }

    GetViewDataFromFile(filterText := "") {
        filterArray := StrSplit(filterText, "$")
        arrayData := []

        viewFile := this.Paths.Tables "\Views.csv"

        
        if (!FileExist(viewFile))
            return []

        try {
            viewCSV := FileRead(viewFile)
        } catch {
            return []
        }

        i := 0
        Loop Parse, viewCSV, "`n", "`r" 
        {
            ; V1 Logic: if(i>1) -> Überspringt die ersten ZWEI Zeilen (Header?)
            ; i startet bei 0. 
            ; Loop 1: i=0 (skip) -> i=1
            ; Loop 2: i=1 (skip) -> i=2
            ; Loop 3: i=2 (process)
            if (i > 1) {
                match := true
                
                ; Filter Logik
                if (filterArray.Length > 0) {
                    for _, elementFilter in filterArray {
                        ; Wenn ein Filter NICHT gefunden wird, Zeile verwerfen
                        if (InStr(A_LoopField, elementFilter) = 0) {
                            match := false
                            break
                        }
                    }
                }

                if (match) {
                    cols := StrSplit(A_LoopField, ";")
                    ; V1 Logic: if(Zeile.MaxIndex()=3) -> Nur Zeilen mit exakt 3 Spalten
                    if (cols.Length = 3) {
                        arrayData.Push(cols)
                    }
                }
            }
            i += 1
        }
        return arrayData
    }

    SendResult(prefix, text) {
        if (prefix != "")
            SendInput "{Raw}" prefix
        
        SendInput "{Raw}" text
    }

    ShowFeedback(msg) {
        ToolTip "Info: " msg
        SetTimer () => ToolTip(), -2000
    }

    SearchTable(searchValue) {
        ; Keine Suche unter 3 Zeichen
        if (StrLen(searchValue) < 3)
            return ""

        ; Datei cachen (Performance)
        CsvContent:= ""
        csvPath := this.Paths.Tables "\exp_column_and_tables.csv"
        if (FileExist(csvPath))
            this.CsvContent := FileRead(csvPath)
        else
            return "" ; Datei nicht gefunden

        separator := "$"
        multipleSearchValues := false
        arraySearchValues := []

        ; Prüfen auf Separator
        if (InStr(searchValue, separator)) {
            multipleSearchValues := true
            arraySearchValues := StrSplit(searchValue, separator)
            ; temp := arraySearchValues[1] ; MsgBox entfernt für v2 Flow
        }

        counterMultipleFound := 0
        multipleFound := ""

        ; Loop durch den Dateiinhalt
        Loop Parse, this.CsvContent, "`n", "`r" 
        {
            line := A_LoopField
            if (line = "")
                continue

            ; Zeile ohne Unterstriche für Vergleiche
            lineNoUnder := StrReplace(line, "_", "")

            ; --- Logik A: Einfache Suche ---
            if (!multipleSearchValues) {
                ; Beginnt die Zeile (oder Zeile ohne _) mit dem Suchbegriff?
                if (InStr(line, searchValue) = 1 || InStr(lineNoUnder, searchValue) = 1) {
                    cols := StrSplit(line, ";")
                    if (cols.Length >= 2)
                        return cols[2]
                }
            }
            ; --- Logik B: Mehrfachsuche ($) ---
            else {
                firstTerm := arraySearchValues[1]
                ; Prüfen ob der erste Begriff matcht
                if (InStr(line, firstTerm) = 1 || InStr(lineNoUnder, firstTerm) = 1) {
                    counter := 0
                    for index, element in arraySearchValues {
                        if (InStr(line, element)) {
                            counter++
                        }
                    }
                    
                    if (counter > counterMultipleFound) {
                        counterMultipleFound := counter
                        cols := StrSplit(line, ";")
                        if (cols.Length >= 2)
                            multipleFound := cols[2]
                    }
                }
            }
        }

        if (counterMultipleFound > 0) {
            return multipleFound
        }

        ; --- Logik C: Fallback (Suche in den ersten 3 Zeichen) ---
        if (!multipleSearchValues) {
            Loop Parse, this.CsvContent, "`n", "`r" 
            {
                line := A_LoopField
                if (line = "")
                    continue
                
                ; V1: StringLeft, searchField, A_LoopField, 3
                searchField := SubStr(line, 1, 3) 

                ; Prüfen ob Suchbegriff in den ersten 3 Zeichen enthalten ist (aber nicht an Pos 1, das wäre oben schon gefunden worden)
                if (InStr(searchField, searchValue) > 1) {
                    cols := StrSplit(line, ";")
                    if (cols.Length >= 2)
                        return cols[2]
                }
            }
        }

        return ""
    }

    Print(text, mc, function, type)
    {
        typeSingle := type
        if (type = "keys" || type = "keyw")
        {
            typeSingle := "key"
        }
        
        ; Prüfen, ob der Text mit "KEY" endet (basierend auf typeSingle)
        if (InStr(text, typeSingle "KEY") = 1)
        {
            ; SubStr berechnen: Länge von typeSingle + "KEY" (3 Zeichen) + 1 für Startposition
            table := SubStr(text, StrLen(typeSingle) + 4)
            
            ; Externe Funktion searchKeys muss existieren
            keys := this.searchKeys(table)
            
            maxIndex := 0
            Loop Parse, keys, "~"
            {
                maxIndex := A_Index
            }
            
            if (maxIndex < 15)
            {
                Loop Parse, keys, "~"
                {
                    if (Trim(A_LoopField) != "")
                    {
                        functionSingle := function
                        
                        ; --- Anmerkung: Im Originalcode wird typeSingle hier zurückgesetzt ---
                        if (type = "keys" || type = "keyw")
                        {
                            typeSingle := "key"
                        }
                        typeSingle := type ; Dies überschreibt die obige Zuweisung (wie im v1 Code)
                        ; -------------------------------------------------------------------

                        textLoop := typeSingle Trim(A_LoopField)
                        
                        if (A_Index > 1 && type = "keyw")
                        {
                            functionSingle := StrReplace(function, "%ConstName%", "AND %ConstName%")
                        }
                        if (A_Index > 1 && type = "keys")
                        {
                            functionSingle := StrReplace(function, "%ConstName%", ", %ConstName%")
                        }
                        
                        this.PrintSingle(textLoop, mc, functionSingle, typeSingle)
                    }
                }
            }
        }
        else if (InStr(text, type "ALL") = 1)
        {
            clip := A_Clipboard
            
            sql := this.convertMakroToSql(clip)
            
            sql := StrReplace(sql, "SELECT ", "")
            sql := StrReplace(sql, "DISTINCT ", "")
            sql := StrReplace(sql, "TOP ", "")
            sql := StrReplace(sql, "`n", "")
            
            if (InStr(sql, "FROM"))
            {
                sql := SubStr(sql, 1, InStr(sql, "FROM") - 1)
            }
            
            Loop Parse, sql, ","
            {
                text2 := A_LoopField
                if (InStr(text2, " AS "))
                {
                    text2 := SubStr(text2, InStr(text2, " AS ") + 4)
                }
            
                text2 := "gas" Trim(text2)
                this.PrintSingle(text2, mc, function, type, , false)
            }
        }
        else
        {
            this.PrintSingle(text, mc, function, type)
        }
    }

    PrintSingle(text, usemc, function, type, shouldSend := true, shouldSearch := true)
    {
        sendValue := "" ; Initialisierung

        ; Wenn Text ungleich Type, dann verarbeiten
        if (text != type)
        {
            ; Text ohne den Typ-Prefix extrahieren
            valText := SubStr(text, StrLen(type) + 1)
            
            if (!InStr(valText, "MC") && usemc)
            {
                valText := "MCA_" valText
            }
            
            textOld := valText
            
            mcVal := SubStr(valText, 1, 4)
            dbName := SubStr(valText, 5)
            
            if (!usemc)
            {
                mcVal := ""
                dbName := valText
            }
            
            if (shouldSearch)
            {
                ; Externe Funktion search muss existieren
                dbName := this.searchTable(dbName)
            }
            
            if (dbName = "")
            {
                if (InStr(textOld, "_") = 0)
                {
                    valText := textOld
                }
                else 
                {
                    valText := textOld
                }
                
                dbName := StrReplace(valText, mcVal, "")
            }
            else
            {
                valText := mcVal dbName
            }
            
            if (InStr(dbName, "_"))
            {
                varName := SubStr(dbName, 5)
            }
            else
            {
                varName := dbName
            }
            
            varName := StrLower(varName)
            
            ; Ersten Buchstaben groß schreiben (CamelCase Logic)
            varFirst := SubStr(varName, 1, 1)
            varFirst := StrUpper(varFirst)
            varName := SubStr(varName, 2)
            varName := "l" varFirst varName
            
            ; Externe Funktion replaceUnderscore muss existieren
            varName := this.replaceUnderscore(varName)
            
            constName := StrUpper(valText)
            
            sendValue := function
            sendValue := StrReplace(sendValue, "%varname%", varName)
            sendValue := StrReplace(sendValue, "%ConstName%", constName)
            
            if (shouldSend)
            {   
                SendInput(sendValue)
            }
        }
        else
        {
            sendValue := function
            sendValue := StrReplace(sendValue, "%varname%", "l")
            sendValue := StrReplace(sendValue, "%ConstName%", "")
            
            if (shouldSend)
            {
                SendInput(sendValue)
            }
        }
        
        return sendValue
    }

    ReplaceUnderscore(text)
    {
        currentChar := ""
        wholeString := ""
        
        Loop Parse, text
        {
            lastChar := currentChar
            currentChar := A_LoopField
            
            appendChar := currentChar
            
            ; Wenn das vorherige Zeichen ein Unterstrich war -> Großbuchstabe
            if (lastChar = "_")
            {
                appendChar := StrUpper(currentChar)
            }
            
            ; Wenn das aktuelle Zeichen ein Unterstrich ist -> überspringen (leer lassen)
            if (currentChar = "_")
            {
                appendChar := ""
            }
        
            ; String zusammenbauen (.= ist der Operator für Anhängen in v2)
            wholeString .= appendChar
        }
        
        return wholeString
    }

    ConvertMakroToSql(text)
    {
        resultLines := ""

        Loop Parse, text, "`n", "`r"
        {
            line := A_LoopField
            
            ; 1. Escaped Quotes schützen ('' zu $§$)
            line := StrReplace(line, "''", "$§$")
            
            ; 2. Zeile trimmen (Leerzeichen am Anfang/Ende weg)
            ; Hinweis: Dies macht die Indent-Berechnung des Originals überflüssig.
            line := Trim(line)
            
            ; 3. Code-Syntax entfernen
            line := StrReplace(line, ".setSQLText('", "")
            line := StrReplace(line, "('SELECT", "SELECT")
            line := StrReplace(line, "'SELECT", "SELECT")
            line := StrReplace(line, "');", "")
            line := StrReplace(line, "' +", "")
            line := StrReplace(line, "'+", "")
            
            ; Einzelne Hochkommas entfernen (aber nicht die geschützten)
            line := StrReplace(line, "'", "")
            
            ; 4. Geschützte Quotes wiederherstellen
            line := StrReplace(line, "$§$", "'")
            
            ; 5. Zeile zum Ergebnis hinzufügen
            resultLines .= line "`n"
        }

        ; Den allerletzten Zeilenumbruch entfernen
        resultLines := RTrim(resultLines, "`n")

        return resultLines
    }

    HandleTableSearch(cmd, prefix) {
        this.State.SetBusy(true)
        try {
            searchReturn := this.SearchTable(cmd)

            if (searchReturn == "") {
                dataArray := this.GetViewDataFromFile("." . cmd . "_")

                if(dataArray.Length > 0){
                    for index, element in dataArray {
                        if (element.Length >= 2 && InStr(element[2], cmd . "_") == 1) {
                            searchReturn := element[1] . "." . element[2]
                        }
                    }
                }
            }

            ; 4. Ausgabe
            ; SendRaw, %SonderzeichenVorSearch%
            ; SendInput, %searchReturn%
            
            ; Wir senden nur, wenn wir auch wirklich was gefunden haben (searchReturn ist nicht leer),
            ; sonst würde nur das Prefix getippt werden, was meist nicht gewollt ist.
            if (searchReturn != "") {
                SendInput "{Raw}" prefix
                SendInput "{Raw}" searchReturn
            }
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleViewSearch(cmd, prefix) {
        viewName := SubStr(cmd, 5)
        path := this.Config.Get("Paths", "OtherFiles", "") . "\" . viewName . ".txt"
        
        this.State.SetBusy(true)
        try {
            if (FileExist(path)) {
                content := FileRead(path)
                data := []
                Loop Parse, content, "`n", "`r" {
                    if (A_LoopField)
                        data.Push(StrSplit(A_LoopField, "|"))
                }
                
                if (data.Length > 0) {
                    selection := this.UI.ShowSelectionWindow("View: " viewName, "Auswählen|Kopieren", "Schema|Name|Definition", data)
                    if (selection)
                        SendInput "{Raw}" prefix selection[1] "." selection[2]
                }
            }
        } finally {
            this.State.SetBusy(false)
        }
    }

    HandleSQLCommand(cmd, prefix, mode, originalTitle) {
        isQuery := (mode = "query")
        offset  := isQuery ? 6 : 7
        stringAfterCmd := SubStr(cmd, offset)
        
        ; ExtractTableAndVar prüft bereits auf das "$"-Zeichen und trennt Suffix ab
        info := this.ExtractTableAndVar(stringAfterCmd)
        tableName := info.Table
        varSuffix := info.VarSuffix

        isSpecialWindow := false
        if (isQuery) {
            cls := WinGetClass("A")
            isSpecialWindow := (cls = "cExpertAttendeeView" || cls = "Transparent Windows Client" || InStr(cls, "WindowsForms10"))
        }

        ; --- HIER IST DIE INTEGRIERTE LOGIK FÜR VARIABLE MIT $ ---
        baseVarName := isQuery ? "lQuery" : "lQueryUpdate"
        
        if (varSuffix != "") {
            ; Wenn ein $ im String war (z.B. queryAdr$Test -> varSuffix="Test")
            this.SetOrResetMakroVar("Snippets", baseVarName . varSuffix, true)
        } else {
            ; Standardfall ohne $
            this.SetOrResetMakroVar("Snippets", baseVarName, true)
        }
        ; ---------------------------------------------------------

        queryText := this.GetQuery(tableName, mode)
        
        spaces := ""
        if (!isSpecialWindow) {
            Sleep(100)
            spaces := this.GetSpacesFromActualPlace(cmd)
            Sleep(100)
        }

        fullOutput := spaces . queryText
        
        if (isQuery && !isSpecialWindow) {
            this.PasteTextAutoformatedNew(queryText, cmd, -1)
        } else {
            this.SendTextAutoformated(fullOutput, spaces)
        }

        qVarLen := StrLen(this.Config.Get("Config", "QueryVar", "lQuery"))
        loopCount := qVarLen - 6
        if (loopCount > 0)
            SendInput "{Left " loopCount "}"
    }

    ; --- AUTOFORMATTER LOGIK ---

    PasteTextAutoformatedNew(aText, markedText := "", SpacesToMake := -1) {
        textAutoformated := this.GetAutoformattedText(aText)
        FirstLine := ""
        spaces := ""

        if (SpacesToMake != -1) {
            Loop SpacesToMake {
                spaces .= " "
            }
            FirstLine := spaces
        } 
        else {
            SendInput "+{Home}"
            MarkedTextAndSpace := ClipboardUtil.CopyAndRestore() 
            
            if (InStr(MarkedTextAndSpace, "setSQLText(")) {
                Pos := InStr(MarkedTextAndSpace, "setSQLText(")
                FirstLine := SubStr(MarkedTextAndSpace, 1, Pos + 9)
                SpacesToMake := StrLen(FirstLine)
            } 
            else {
                SendInput "+{Home}"
                MarkedTextAndSpace := ClipboardUtil.CopyAndRestore()
                Pos := InStr(MarkedTextAndSpace, markedText)
                if Pos {
                    FirstLine := SubStr(MarkedTextAndSpace, 1, StrLen(MarkedTextAndSpace) - StrLen(markedText))
                    SpacesToMake := StrLen(FirstLine)
                } else {
                    SpacesToMake := 0
                }
            }
            Loop SpacesToMake {
                spaces .= " "
            }
        }
        
        SendInput "{Text}" textAutoformated
    }

    GetAutoformattedText(text, replaceMovement := 1) {
        configText := text
        if replaceMovement {
            configText := StrReplace(configText, "{Left}", "")
            configText := StrReplace(configText, "{Right}", "")
            configText := StrReplace(configText, "{Up}", "")
        }
        configText := StrReplace(configText, "{Tab}", "")
        configText := StrReplace(configText, "{Shift Up}", "")
        configText := StrReplace(configText, "{Shift Down}", "")
        
        return this.Autoformatter(configText)
    }

    Autoformatter(makro) {
        data := {}
        data.OpenCommentBracketArray := []
        data.CloseCommentBracketArray := []
        data.beginArray := []
        data.caseArray := []
        data.endArray := []
        data.caseEndArray := []
        data.apostrophOpenArray := []
        data.apostrophCloseArray := []
        data.commentArray := []
        data.openBracketArray := []
        data.closeBracketArray := []
        data.semicolonArray := []
        data.carriageReturnArray := []
        data.setSQLTextArray := []
        data.codestartArray := []
        data.exitArray := []
        data.TabsAfterCarriageReturnArray := []
        
        TabCounter := 0
        
        makro := StrReplace(makro, "`r`n", "`n")
        makro := StrReplace(makro, "`r", "`n")
        makro := StrReplace(makro, "`n", "`r`n")
        
        this.GetPositionOfKeyStrings(makro, data)
        
        x := 1
        i := 1
        j := 1
        g := 1
        z := 1
        
        if (data.carriageReturnArray.Length > 0) {
            Loop data.carriageReturnArray.Length {
                while (i <= data.beginArray.Length && data.beginArray[i] < data.carriageReturnArray[x]) {
                    TabCounter++
                    i++
                }
                while (g <= data.caseArray.Length && data.caseArray[g] < data.carriageReturnArray[x]) {
                    TabCounter++
                    g++
                }
                
                isLastCR := (x >= data.carriageReturnArray.Length)
                nextCR := isLastCR ? 999999999 : data.carriageReturnArray[x+1]

                while (j <= data.endArray.Length && (data.endArray[j] < nextCR || isLastCR)) {
                    TabCounter--
                    j++
                }
                while (z <= data.caseEndArray.Length && (data.caseEndArray[z] < nextCR || isLastCR)) {
                    TabCounter--
                    z++
                }
                
                x++
                data.TabsAfterCarriageReturnArray.Push(TabCounter)
            }
        }
        
        line := 1
        EmptyLine := 0
        AnzLoop := (data.carriageReturnArray.Length == 0) ? 1 : data.carriageReturnArray.Length + 1
        formattedMakro := ""
        
        Loop AnzLoop {
            if (line = 1) {
                if (data.carriageReturnArray.Length > 0 && data.carriageReturnArray[1] != "")
                    formattedMakro := SubStr(makro, 1, data.carriageReturnArray[1] + 1)
                else
                    formattedMakro := makro
                
                formattedMakro := Trim(formattedMakro, " `r`n")
                formattedMakro .= "`r`n"
            } 
            else {
                nextCR := (line+1 <= data.carriageReturnArray.Length) ? data.carriageReturnArray[line+1] : 0
                
                if (line <= data.codestartArray.Length && nextCR > 0 && (data.codestartArray[line] + 2) == nextCR)
                    EmptyLine++
                else
                    EmptyLine := 0
                
                if (EmptyLine <= 3) {
                    makroLineToAppend := ""
                    startPos := (line-1 <= data.codestartArray.Length) ? data.codestartArray[line-1] + 2 : 0
                    
                    if (A_Index != AnzLoop && startPos > 0) {
                        len := data.carriageReturnArray[line] - startPos
                        makroLineToAppend := SubStr(makro, startPos, len)
                    }
                    else if (data.codestartArray.Length > 0) {
                         startPosLast := data.codestartArray[data.codestartArray.Length] + 2
                         makroLineToAppend := SubStr(makro, startPosLast)
                    }
                    
                    makroLineToAppend := RTrim(makroLineToAppend, " `r`n")
                    
                    if (line <= data.codestartArray.Length)
                        makroLineToAppend .= "`r`n"
                    
                    SpacesToMakeStr := ""
                    if (line-1 <= data.TabsAfterCarriageReturnArray.Length) {
                        Loop data.TabsAfterCarriageReturnArray[line-1]
                            SpacesToMakeStr .= "    "
                    }
                    
                    formattedMakro .= SpacesToMakeStr . makroLineToAppend
                }
            }
            line++
        }
        
        return formattedMakro
    }

    GetPositionOfKeyStrings(makro, data) {
        Pos := 1
        f := {OpenC: 1, CloseC: 1, begin: 1, case: 1, end: 1, apo: 1, com: 1, openB: 1, closeB: 1, semi: 1, cr: 1, sql: 1, code: 1, exit: 1}
        
        OpenApostroph := 1
        isItCaseEnd := [0]
        carriageMustResetRegex := 0
        
        matchObj := ""
        matchLen := 0

        while (Pos != 0) {
            pat := ""
            if f.OpenC  { 
                pat .= "\{|" 
            }
            if f.CloseC { 
                pat .= "\}|" 
            }
            if f.begin  { 
                pat .= "\bbegin\b|" 
            }
            if f.end    { 
                pat .= "\bend\b|" 
            }
            if f.apo    { 
                pat .= "'|" 
            }
            if f.com    { 
                pat .= "\/\/|" 
            }
            if f.openB  { 
                pat .= "\(|" 
            }
            if f.closeB { 
                pat .= "\)|" 
            }
            if f.semi   { 
                pat .= ";|" 
            }
            if f.cr     { 
                pat .= "[\r]|" 
            }
            if f.sql    { 
                pat .= "\bSetSQLText\b|" 
            }
            if f.code   { 
                pat .= "\n([ ]*)|" 
            }
            if f.exit   { 
                pat .= "\bexit\b|" 
            }
            if f.case   { 
                pat .= "\bcase\b|" 
            }
            
            if (pat = "")
                break
                
            pat := SubStr(pat, 1, StrLen(pat) - 1)
            
            StartPos := Pos + matchLen
            Pos := RegExMatch(makro, "i)" pat, &matchObj, StartPos)
            
            if (Pos > 0) {
                match := matchObj[0]
                matchLen := matchObj.Len
                
                if (match = "{") {
                    data.OpenCommentBracketArray.Push(Pos)
                    f.OpenC:=0, f.CloseC:=1, f.begin:=0, f.case:=0, f.end:=0, f.apo:=0, f.com:=0, f.openB:=0, f.closeB:=0, f.semi:=0, f.exit:=0, f.cr:=1, f.sql:=0, f.code:=1
                }
                else if (match = "}") {
                    data.CloseCommentBracketArray.Push(Pos)
                    f.OpenC:=1, f.CloseC:=1, f.begin:=1, f.case:=1, f.end:=1, f.apo:=1, f.com:=1, f.openB:=1, f.closeB:=1, f.semi:=1, f.exit:=1, f.cr:=1, f.sql:=1, f.code:=1
                }
                else if (match = "begin") {
                    if isItCaseEnd.Length > 0
                        isItCaseEnd[isItCaseEnd.Length]--
                    data.beginArray.Push(Pos)
                }
                else if (match = "case") {
                    isItCaseEnd.Push(0)
                    data.caseArray.Push(Pos)
                }
                else if (match = "end") {
                    if isItCaseEnd.Length > 0 {
                        isItCaseEnd[isItCaseEnd.Length]++
                        if (isItCaseEnd[isItCaseEnd.Length] = 1) {
                            data.endArray.Push(Pos)
                            data.caseEndArray.Push(Pos)
                            data.endArray.RemoveAt(data.endArray.Length)
                            isItCaseEnd.RemoveAt(isItCaseEnd.Length)
                        } else {
                            data.endArray.Push(Pos)
                        }
                    } else {
                        data.endArray.Push(Pos)
                    }
                }
                else if (match = "exit") {
                    data.exitArray.Push(Pos)
                }
                else if (match = "'") {
                    if (OpenApostroph = 1) {
                        data.apostrophOpenArray.Push(Pos)
                        f.OpenC:=0, f.CloseC:=0, f.begin:=0, f.case:=0, f.end:=0, f.apo:=1, f.com:=0, f.openB:=0, f.closeB:=0, f.semi:=0, f.sql:=0, f.exit:=0, f.cr:=1, f.code:=1
                        OpenApostroph--
                    } else {
                        data.apostrophCloseArray.Push(Pos)
                        f.OpenC:=1, f.CloseC:=1, f.begin:=1, f.case:=1, f.end:=1, f.apo:=1, f.com:=1, f.openB:=1, f.closeB:=1, f.semi:=1, f.sql:=1, f.exit:=1, f.cr:=1, f.code:=1
                        OpenApostroph++
                    }
                }
                else if (match = "//") {
                    data.commentArray.Push(Pos)
                    carriageMustResetRegex := 1
                    f.OpenC:=0, f.CloseC:=0, f.begin:=0, f.case:=0, f.end:=0, f.apo:=0, f.com:=0, f.openB:=0, f.closeB:=0, f.semi:=0, f.sql:=0, f.exit:=0, f.cr:=1, f.code:=1
                }
                else if (match = "(")
                    data.openBracketArray.Push(Pos)
                else if (match = ")")
                    data.closeBracketArray.Push(Pos)
                else if (match = ";")
                    data.semicolonArray.Push(Pos)
                else if (match = "setSQLText")
                    data.setSQLTextArray.Push(Pos)
                else if (match = "`r") {
                    data.carriageReturnArray.Push(Pos)
                    if (carriageMustResetRegex = 1) {
                        f.OpenC:=1, f.CloseC:=1, f.begin:=1, f.case:=1, f.end:=1, f.apo:=1, f.com:=1, f.openB:=1, f.closeB:=1, f.semi:=1, f.cr:=1, f.sql:=1, f.exit:=1, f.code:=1
                        carriageMustResetRegex := 0
                    }
                }
                else if (InStr(match, "`n")) {
                    if (data.carriageReturnArray.Length > 0)
                        data.codestartArray.Push(data.carriageReturnArray[data.carriageReturnArray.Length] + matchLen - 1)
                }
            }
        }
    }

    ; ==============================================================================
    ; WEITERE KERN-LOGIK
    ; ==============================================================================

    HandleJoinSearch(cmd, prefix) {
        SendInput "{Raw}" prefix
        if (SubStr(prefix, -1) = "'")
            SendInput "{Space}"
        
        tableShort := SubStr(cmd, 4, 3)
        DataArray := this.getDataFromFile(SubStr(cmd, 1, 3), "Join", tableShort)
        DataArray := this.BearbeiteDataArrayFuerAnzeige(DataArray, tableShort)

        this.ListViewFromDataArray(DataArray, "Auswählen (Enter)", "From|To|From Columns|To Columns|Manuell", "AusgabeJoinSubroutine", "100|100|500|500|100", "Verfügbare Joins", cmd, "", "JoinsEdit")
    }

    HandleFieldSearch(cmd, prefix) {
        this.PerformFieldSearch(cmd, prefix, false)
    }

    HandleMCASearch(cmd, prefix) {
        this.PerformFieldSearch(cmd, prefix, true)
    }

    /**
     * Ermittelt Felder, baut das GUI und bindet den Tabellennamen.
     */
    PerformFieldSearch(cmd, prefix, isMCA) {
        SendInput "{Raw}" prefix
        
        cleanCmd := isMCA ? SubStr(cmd, 5) : cmd
        underscorePos := InStr(cleanCmd, "_")
        
        ; 1. Tabellenkürzel und Feldrest ermitteln (z.B. "KUN" aus "KUN_NAME")
        tableShort := SubStr(cleanCmd, underscorePos - 3, 3)
        fieldName  := SubStr(cleanCmd, underscorePos + 1)
        
        ; 2. Daten laden (Mockup-Aufruf deiner Datei-Logik)
        DataArray := this.getDataFromFile(tableShort, "Field", fieldName)
        
        if (DataArray.Length = 0)
            return

        ; 3. DAS BINDING
        ; Wir erstellen ein Callback-Objekt.
        ; Param 1: 'this' (die Instanz dieser Klasse)
        ; Param 2: Der Name der Methode, die aufgerufen werden soll
        ; Param 3: Der erste Parameter, der IMMER übergeben wird (hier: tableShort / "KUN")
        callback := ObjBindMethod(this, "HandleFieldSelection", tableShort)

        ; 4. GUI Aufruf über den Wrapper
        this.ListViewFromDataArray(
            DataArray, 
            "Beistrich|GetValue|SetValue|GetAsString|SetParamAsString", 
            "Code|Comment|Description Text|Data Type|PK|FK", 
            callback,               ; <--- Das fertige Paket übergeben
            "300|300|300|200|30|30", 
            "Felder", 
            cmd, 
            "Checked"
        )
    }


    HandleSetParam(cmd, prefix) {
        SendInput "{Raw}" prefix
        text := SubStr(cmd, 3)
        SendInput "{Text}lQuery.setParamAsString('" text "'," text ");"
    }
    ; ==============================================================================
    ; HILFSMETHODEN
    ; ==============================================================================

    GetQuery(table := "", configVar := "query") {
        varQueryTableFrom := "%QUERY_FROM_TABLE%"
        varQueryWhere     := "%QUERY_WHERE%"
        varQueryParams    := "%QUERY_PARAMS%"
        
        query := this.Config.Get("Snippets", configVar, "")
        
        if (table == "") {
            query := StrReplace(query, " " varQueryTableFrom, "")
            query := StrReplace(query, " " varQueryWhere, "")
            query := StrReplace(query, varQueryParams, "")
        } 
        else {
            tableName := this.SearchTable(table)
            query := StrReplace(query, varQueryTableFrom, tableName)
            
            keys := this.SearchKeys(table)
            whereText := ""
            
            Loop Parse, keys, "~" {
                if (Trim(A_LoopField) != "") {
                    if (whereText != "")
                        whereText .= "' + `n' AND "
                    
                    DB_ConstName := Trim(A_LoopField)
                    variableName := this.GetVariableName(DB_ConstName)
                    whereLine := DB_ConstName . " = :" . variableName
                    whereText .= whereLine
                }
            }
            
            query := StrReplace(query, varQueryWhere, whereText)
            
            params := this.GetSetParamAsString(whereText) . "`n"
            query := StrReplace(query, varQueryParams, params)
        }
        
        return query
    }

    EnsureWindowFocus(originalTitle) {
        while (WinGetTitle("A") != originalTitle) {
            res := MsgBox('Ihr Fenster Fokus hat gewechselt!`nVorher: "' originalTitle '"`nJetzt: "' WinGetTitle("A") '"`n`nWechseln Sie zurück!', "Warnung", 1)
            
            if (res = "Cancel")
                return false
            Sleep 500
        }
        return true
    }

    ParseCommandPrefix(clip) {
        special := ""
        clean := clip
        if RegExMatch(clip, "^(.*?)(?=[a-zA-Z])", &match) {
            special := match[1]
            if (special != "")
                clean := SubStr(clip, 1 + StrLen(special))
        }
        return {Prefix: special, Cmd: clean}
    }

    ExtractTableAndVar(str) {
        posDollar := InStr(str, "$")
        tableName := ""
        varSuffix := ""

        if (posDollar) {
            varSuffix := SubStr(str, posDollar + 1)
            candidate := SubStr(str, 1, posDollar - 1)
            if (StrLen(candidate) = 3)
                tableName := candidate
        } else {
            if (StrLen(str) = 3)
                tableName := str
        }
        return {Table: tableName, VarSuffix: varSuffix}
    }

    IsJoinSearch(cmd) {
        ; Prüfe: Länge 6, nur Buchstaben, und es gibt Daten für diesen Join
        return (StrLen(cmd) = 6 
             && RegExMatch(cmd, "^[a-zA-Z]+$") = 1
             && IsObject(this.GetDataFromFile(SubStr(cmd, 1, 3), "Join", SubStr(cmd, 4, 3))))
    }

    IsFieldSearch(cmd) {
        ; 1. "Billige" Syntax-Prüfungen zuerst (Performance: Dateizugriff vermeiden, wenn Syntax schon falsch ist)
        if !(InStr(cmd, "_") && StrLen(cmd) > 3)
        {
            return false
        }

        ; 2. Parsen von Table und Field (ähnlich wie in PerformFieldSearch)
        underscorePos := InStr(cmd, "_")
        
        ; Extrahiere Tabellenkürzel (alles vor dem Unterstrich)
        tableShort := SubStr(cmd, 1, underscorePos - 1)
        
        ; Extrahiere Feldname (alles nach dem Unterstrich)
        fieldName := SubStr(cmd, underscorePos + 1)

        ; Prüfen, ob das Tabellenkürzel genau 3 Zeichen lang ist (deine ursprüngliche Bedingung)
        if (StrLen(tableShort) != 3)
            return false

        ; 3. Tatsächliche Datenabfrage ("Gibt es dieses Feld?")
        ; Hier rufen wir deine Funktion auf. 
        ; Dank des Fixes vorhin liefert sie [] zurück, wenn nichts gefunden wird.
        DataArray := this.getDataFromFile(tableShort, "Field", fieldName)

        ; 4. True zurückgeben, wenn das Array Elemente enthält
        return (DataArray.Length > 0)
    }

    IsMCASearch(cmd) {
        return (InStr(cmd, "MCA_") && this.IsFieldSearch(SubStr(cmd, 5)))
    }

    ; ==============================================================================
    ; EXTERNE PLATZHALTER (Libraries)
    ; ==============================================================================
    SearchKeys(tableShort)
    {
        searchResult := ""
        notPassed := ""
        searchValue := tableShort
        separator2 := "~"
        
        ; Datei lesen (mit Error-Handling, falls Datei fehlt)
        filePath := this.Paths.Tables "\exp_column_and_tables_pks.csv"
        if !FileExist(filePath)
            return "" ; Oder Fehler werfen/loggen
            
        try {
            data := FileRead(filePath)
        } catch {
            return ""
        }

        separator := "$"
        multipleSearchValues := false
        
        if (InStr(searchValue, separator))
        {
            multipleSearchValues := true
            ; Hinweis: Im Originalcode wurde arraySearchValues erstellt aber im Loop nicht genutzt.
            ; Wenn multipleSearchValues true ist, macht der Loop unten gar nichts (wegen !multipleSearchValues).
            ; Ich habe diese Logik 1:1 übernommen.
        }

        Loop Parse, data, "`n", "`r"
        {
            currentLine := A_LoopField
            
            if (currentLine = "")
                continue

            ; Die Bedingung aus v1:
            ; 1. Zeile fängt mit searchValue an ODER Zeile (ohne Unterstriche) fängt damit an
            ; 2. UND es ist KEINE Mehrfachsuche ($)
            if (((InStr(currentLine, searchValue) = 1) || (InStr(StrReplace(currentLine, "_", ""), searchValue) = 1)) && !multipleSearchValues)
            {
                rowArray := StrSplit(currentLine, ";")
                
                ; Sicherstellen, dass das Array genug Spalten hat
                if (rowArray.Length >= 2)
                {
                    colName := rowArray[2] ; Spalte 2 ist wohl der Feldname
                    
                    ; Prüfung: Startet "KUN_NAME" mit "KUN_"? (Case Insensitive durch StrUpper)
                    if (InStr(StrUpper(colName), StrUpper(tableShort) "_") = 1)
                    {
                        searchResult .= colName separator2
                    }
                    else
                    {
                        ; Ich gehe davon aus, dass getConfig eine Methode der Klasse ist.
                        ; Falls es eine globale Funktion ist, entferne "this."
                        if (this.HasMethod("GetConfig") && this.GetConfig("DeveloperMode") = "on")
                        {
                            notPassed .= colName ";"
                        }
                    }
                }
            }
        }
        
        ; Debugging Meldung aus dem Original (auskommentiert gelassen)
        /*
        if (this.GetConfig("DeveloperMode") = "on" && notPassed != "")
        {
            MsgBox("Aufgrund Keyänderung nicht enthalten: " notPassed)
        }
        */

        return searchResult
    }
    GetVariableName(c) => c 
    GetSetParamAsString(w) => "lQuery.setParam..." 

    SetOrResetMakroVar(cat, name, stat, silent := false) {
        ; 1. Wert über ConfigProvider speichern
        this.Config.Set(cat, name, stat)

        ; 2. Benachrichtigung (nur wenn nicht silent)
        if (silent == false) {
            ; Fall 1: Reset (stat ist 0, false oder leer)
            if (stat == 0 || stat == false || stat == "") {
                TrayTip "Die " cat " Variable wurde zurückgesetzt (" name ").", "Makro Variable"
            }
            ; Fall 2: Setzen (stat ist true oder ein Wert)
            else {
                TrayTip "Als " cat " Variable wurde nun '" name "' festgelegt.", "Makro Variable"
            }
            
        }
    }
    
; ==============================================================================
    ; FUNKTIONIERENDE STRX METHODE (AHK v2)
    ; ==============================================================================
    ; Moderne RegEx-basierte HTML-Parsing
    ; Ersetzt die fragile StrX-Methode mit strukturiertem Regex
    ExtractHTMLTables(html, sectionTitle, maxColumns) {
        tables := []
        
        ; Pattern: <p align="center">TITLE</p> ... </table>
        ; Das .*? ist non-greedy matching (stoppt beim ersten </table>)
        pattern := "i)<p align=""center"">" . RegExEscape(sectionTitle) . ".*?</table>"
        
        startPos := 1
        while (RegExMatch(html, pattern, &tableMatch, startPos)) {
            tableHtml := tableMatch[0]
            tableData := []
            
            ; Jetzt alle <p align="left">...</p> aus dieser Tabelle extrahieren
            colPattern := "i)<p align=""left"">(.*?)</p>"
            colStartPos := 1
            colCount := 0
            
            while (RegExMatch(tableHtml, colPattern, &colMatch, colStartPos)) {
                colContent := colMatch[1]
                
                ; HTML-Entities und Tags entfernen
                colContent := StrReplace(colContent, "&nbsp;", "")
                colContent := RegExReplace(colContent, "i)<[^>]+>", " ")
                colContent := Trim(colContent)
                
                ; "_" signalisiert Ende der Daten
                if (colContent = "_") {
                    break
                }
                
                tableData.Push(colContent)
                colCount++
                colStartPos := colMatch.Pos + colMatch.Len
                
                ; Maximal maxColumns Spalten pro Tabelle
                if (colCount >= maxColumns) {
                    break
                }
            }
            
            if (tableData.Length > 0) {
                tables.Push(tableData)
            }
            
            startPos := tableMatch.Pos + tableMatch.Len
        }
        
        return tables
    }
    
    GetDataFromFile(TableShort, JoinOrField, Filter:="", RecursiveJoin:=true){
        Path := this.Paths.Tabellenbeschreibung
        
        ; Externe Funktion getInfoFromTable muss v2 kompatibel sein
        SearchFilename := this.getInfoFromTable(TableShort, "File")
        ; Initialisiere SearchFile leer, falls Datei nicht geöffnet werden kann
        SearchFile := ""
        if (FileExist(Path "\Tabellenbeschreibung_files\" SearchFilename) && SearchFilename != "")
        {
            fileobject := FileOpen(Path "\Tabellenbeschreibung_files\" SearchFilename, "r", "UTF-8")
            SearchFile := fileobject.Read()
            fileobject.Close()
        }

        ArrayFile := []
        ArrayFilterZeilenBeginn := []
        ArrayData := [] ; <--- Direkt als Array initialisieren!
        Zeile := []
        FilterArray := StrSplit(Filter, "$")
        i := 0
        
        if (JoinOrField = "Join")
        {
            for index, elementfilter in FilterArray
            {
                if (elementfilter = "DKZ")
                {
                    FilterArray.Push("DKQ")
                }
            }
            
            ; Joins von Anderer Seite
            if (RecursiveJoin = true)
            {
                for index, elementfilter in FilterArray
                {
                    ArrayReverseJoins := this.GetDataFromFile(elementfilter, "Join", TableShort, false)
                    if (IsObject(ArrayReverseJoins) = true)
                    {
                        for indexReverseJoins, elementReverseJoins in ArrayReverseJoins
                        {
                            ArrayData.Push(ArrayReverseJoins[indexReverseJoins])
                        }
                    }
                }
            }
            
            ; ManuelleJoins:
            if (FilterArray.Length = 1) ; v2 nutzt .Length statt .MaxIndex()
            {
                ManuelleJoinsFile := this.Paths.Joins "\Joins.csv"
                if FileExist(ManuelleJoinsFile)
                {
                    ManuelleJoins := FileRead(ManuelleJoinsFile)
                    
                    Loop Parse, ManuelleJoins, "`n", "`r"
                    {
                        lLineOhneErsterZahl := RegExReplace(A_LoopField, "m)^\d")
                        
                        if (InStr(lLineOhneErsterZahl, TableShort "_" Filter) = 1)
                        {
                            
                            Zeile := StrSplit(A_LoopField, ",")
                            Zeile.InsertAt(2, Zeile[1])
                            Zeile.InsertAt(3, "")
                            Zeile.Push("X")
                            
                            for indexZeile, elementZeile in Zeile
                            {
                                Zeile[indexZeile] := Trim(Zeile[indexZeile])
                            }
                            
                            ArrayData.InsertAt(1, Zeile)
                            Zeile := []
                        }
                    }
                }
            }    
        }
        
        if (JoinOrField = "Join")
        {
            HTMLTablesInFile := StrSplit(SearchFile, "</table>")
            SeitenHTMLTableIndex := 1
            
            for index, elementhtmltables in HTMLTablesInFile
            {
                SeitenHTMLTableIndex := index
                if (InStr(elementhtmltables, ">Next<"))
                {
                    break
                }
            }
            
            if (SeitenHTMLTableIndex <= HTMLTablesInFile.Length && InStr(HTMLTablesInFile[SeitenHTMLTableIndex], ' href="Tabe') != 0)
            {
                ; Hinweis: StrX muss v2 kompatibel sein. Parameter 1:1 übernommen.
                FileNameForJoins := this.StrX(SearchFile, ' href="Tabe', 0, 7, '"', 1, 1)
                
                if (FileExist(Path "\Tabellenbeschreibung_files\" FileNameForJoins) && FileNameForJoins != "")
                {
                    fileobject := FileOpen(Path "\Tabellenbeschreibung_files\" FileNameForJoins, "r", "UTF-8")
                    SearchFile := fileobject.Read()
                    fileobject.Close()
                }
            }
        }        

        ArrayFile.Push(SearchFile)
        
        HTMLTablesInFile := StrSplit(SearchFile, "</table>")
        SeitenHTMLTableIndex := 1
        
        for index, elementhtmltables in HTMLTablesInFile
        {
            SeitenHTMLTableIndex := index
            if (InStr(elementhtmltables, ">Next<"))
            {
                break
            }
        }

        t := 1
        while (true)
        {
            ; Bounds-Check: Stelle sicher, dass der Index gültig ist
            if (SeitenHTMLTableIndex > HTMLTablesInFile.Length)
            {
                break
            }
            
            ; StrX Aufruf: &t wird verwendet, falls StrX den Offset per Referenz updated
            ; Ändern Sie 'htm"' zu '"'
            ; Ändern Sie 'htm"' zu '"'
            SeitenFilename := this.StrX(HTMLTablesInFile[SeitenHTMLTableIndex], ' href="Tabe', t, 7, '"', 1, 1, &t)
        
            
            ; v2 InStr: StartPos -1 sucht von rechts (entspricht v1 StartPos 0)
            if ((SeitenFilename = "") OR ((InStr(SeitenFilename, '"', , -1) != 0) AND (JoinOrField != "Join")))
            {
                break
            }
            else
            {
                if (InStr(SeitenFilename, '"', , -1) != 0)
                {
                    SeitenFilename := SubStr(SeitenFilename, InStr(SeitenFilename, '"', , -1) + 1)
                }
            
                if (FileExist(Path "\Tabellenbeschreibung_files\" SeitenFilename) && SeitenFilename != "")
                {
                    fileobject := FileOpen(Path "\Tabellenbeschreibung_files\" SeitenFilename, "r", "UTF-8")
                    FoundFile := fileobject.Read()
                    fileobject.Close()
                    ArrayFile.Push(FoundFile)
                }
            } 
        }
        
        for index, element in ArrayFile
        {
            if (JoinOrField = "Join")
            {
               maxSpalte := 4
               tables := this.ExtractHTMLTables(element, "Foreign Key Columns", maxSpalte)
            }
            else
            {
               maxSpalte := 6
               tables := this.ExtractHTMLTables(element, "Description Text", maxSpalte)
            }
            
            for index2, Zeile in tables
            {
               if (JoinOrField = "Join")
               {
                   IsMatch := false
               }
               else
               {
                   IsMatch := true
               }
                
               for asdf, elementfilter in FilterArray
               {
                   if ((JoinOrField = "Join") AND (elementfilter = TableShort) AND ((InStr(Zeile[1], "_" elementfilter) != 0) AND (InStr(Zeile[1], elementfilter) = 1)))
                   {
                       IsMatch := true
                   } 
                   else if ((JoinOrField = "Join") AND (elementfilter != TableShort) AND (InStr(Zeile[1], elementfilter) != 0))
                   {
                       IsMatch := true
                   }
                   else if ((JoinOrField != "Join") AND (InStr(Zeile[1], elementfilter) = 0))
                   {
                       IsMatch := false
                   }
               }
                
               if (IsMatch = true)
               {
                   if (JoinOrField = "Join")
                       Zeile.InsertAt(2, "")
                        
                   ArrayData.Push(Zeile)
               }
           }
        }
        
        ; ManuelleFelder
        if (JoinOrField != "Join")
        {
            ManuelleFelderFile := this.Paths.Fields "\Felder.csv"
            
            if FileExist(ManuelleFelderFile)
            {
                ManuelleFelder := FileRead(ManuelleFelderFile)
                
                Loop Parse, ManuelleFelder, "`n", "`r"
                {
                    if (InStr(A_LoopField, TableShort "_") = 1)
                    {
                        Zeile := StrSplit(A_LoopField, ",")
                        Zeile[1] := SubStr(Zeile[1], 5)
                        AlreadyInArray := false
                        
                        for i, elementDate in ArrayData
                        {
                            if (elementDate[1] = Zeile[1])
                            {
                                AlreadyInArray := true
                            }
                        }
                        
                        if (AlreadyInArray = false)
                        {
                            IsMatch := true
                            for asdf, elementfilter in FilterArray
                            {
                                if (InStr(Zeile[1], elementfilter) = 0)
                                {
                                    IsMatch := false
                                }
                            }
                            
                            if (IsMatch = true)
                            {
                                ArrayData.Push(Zeile)
                            }
                        }
                    }
                }
            }
        }

        return ArrayData
    }


    getInfoFromTable(TableShort, FullnameOrFile := "Fullname"){
        TocFile := this.Paths.Tabellenbeschreibung "\Tabellenbeschreibung_files\Tabellenbeschreibung_toc.htm"
        
        ; In v2 wirft FileRead einen Fehler, wenn die Datei fehlt. Daher Try/Catch oder FileExist nutzen.
        if FileExist(TocFile)
            FileString := FileRead(TocFile)
        else
            return "" 

        TableShort := StrUpper(TableShort)
        
        ; In v2 ist 'match' ein Objekt. Das & Zeichen ist notwendig für die Ausgabe-Var.
        Pos := RegExMatch(FileString, "m).*\." TableShort "\_.*", &match, 1)

        ReturnString := ""
        
        ; Prüfen, ob ein Match gefunden wurde (Pos > 0)
        if (Pos > 0)
        {
            ; match[0] enthält den gesamten gefundenen Text (in v1 war 'match' direkt der Text)
            matchText := match[0]

            if (FullnameOrFile = "Fullname")
            {
                ; Hinweis: Einfache Anführungszeichen ' erleichtern in v2 das Schreiben von Strings mit "
                ReturnString := this.StrX(matchText, 'title="', 1, 7, " src", 1, 5)
            }
            else if (FullnameOrFile = "File")
            {
                ReturnString := this.StrX(matchText, "<a href=", 1, 9, '"', 1, 3)
                if InStr(ReturnString, "#")
                    ReturnString := StrSplit(ReturnString, "#")[1]
            }
        }
        
        return ReturnString
    }

    BearbeiteDataArrayFuerAnzeige(DataArray, TableShort){
        TableShort := StrUpper(TableShort)
        
        ; Arrays initialisieren
        IndexToRemove := []
        ArrayFirst := []
        ArrayManuell := []
        ArrayTabBesch := []
        
        ; --- 1. Aufteilung in Unter-Arrays ---
        For i, v in DataArray
        {
            match := ""
            ; v2: Output-Variable ist ein Objekt (&matchObj), Zugriff über [0]
            if RegExMatch(v[1], "m)^[0-9]+", &matchObj)
                match := matchObj[0]
            
            if (match != "")
            {
                ; v2 InsertAt erlaubt keine Lücken (Sparse Arrays). 
                ; Wir simulieren das Verhalten von v1, indem wir Arrays auffüllen, falls der Index zu groß ist.
                idx := Integer(match)
                if (idx > ArrayFirst.Length + 1) {
                    Loop (idx - ArrayFirst.Length - 1)
                        ArrayFirst.Push("") ; Lückenfüller, falls nötig
                }
                
                ; Falls idx innerhalb der Länge ist oder genau Length+1, funktioniert InsertAt
                try {
                    ArrayFirst.InsertAt(idx, v)
                } catch {
                    ; Fallback, falls irgendwas mit dem Index schiefgeht
                    ArrayFirst.Push(v)
                }
            }
            else if (v.Has(6) && v[6] = "X") ; v.Has(6) prüft, ob Index 6 existiert
            {
                ArrayManuell.Push(v)
            }
            else
            {
                ArrayTabBesch.Push(v)
            }
        }
        
        ; --- 2. Arrays wieder zusammenfügen ---
        DataArray := [] ; Array leeren
        
        ; Leere Elemente aus ArrayFirst überspringen (durch das Auffüllen oben könnten welche entstanden sein)
        For i, v in ArrayFirst
        {
            if IsObject(v) ; Nur echte Objekte (die Zeilen) übernehmen, keine Lückenfüller
                DataArray.Push(v)
        }
        
        For i, v in ArrayTabBesch
            DataArray.Push(v)
        
        For i, v in ArrayManuell
            DataArray.Push(v)
        
        ; --- 3. Duplikate finden und markieren ---
        for index, element in DataArray
        {
            ThisObject := DataArray[index]
            ToRemove := false
            
            ; Innere Schleife
            for indexcheck, elementcheck in DataArray
            {
                ; Abbruchbedingung wie im Original
                if (indexcheck >= index) ; Original war indexcheck >= (index-1), aber wir prüfen unten break
                    break

                ; Strings bereinigen
                ParentThisObject := StrReplace(ThisObject[4], " ")
                ChildThisObject := StrReplace(ThisObject[5], " ")
                ParentAlreadyinArray := StrReplace(DataArray[indexcheck][3], " ")
                ChildAlreadyinArray := StrReplace(DataArray[indexcheck][4], " ")
                
                ; Sortieren (v2 Sort ist eine Funktion)
                ParentThisObject := Sort(ParentThisObject, "D;")
                ChildThisObject := Sort(ChildThisObject, "D;")
                ParentAlreadyinArray := Sort(ParentAlreadyinArray, "D;")
                ChildAlreadyinArray := Sort(ChildAlreadyinArray, "D;")
                
                ParentThisObjectArray := StrSplit(ParentThisObject, ";")
                ChildThisObjectArray := StrSplit(ChildThisObject, ";")
                
                ; Logik-Prüfung
                if ( ((ParentThisObject = ParentAlreadyinArray) && (ChildThisObject = ChildAlreadyinArray)) 
                || ((ParentThisObject = ChildAlreadyinArray) && (ChildThisObject = ParentAlreadyinArray)) 
                || (ParentThisObjectArray.Length != ChildThisObjectArray.Length) )
                {
                    ToRemove := true
                }
                
                ; Original Logik war etwas seltsam mit index-1, aber hier setzen wir das break effektiv um
                if (indexcheck >= (index - 1))
                {
                    break
                }
            }
            
            CodeOfObject := Trim(ThisObject[1])
            
            if ((ToRemove = false) && (ThisObject[1] != ""))
            {
                if (InStr(ThisObject[1], "_") != 0)
                {
                    ; SubStr in v2 funktioniert gleich
                    ThisObject[2] := SubStr(ThisObject[1], InStr(ThisObject[1], "_") + 1, 3)
                    
                    if RegExMatch(ThisObject[1], "m)[a-zA-Z]+", &CodeOnlyBuchstaben)
                        ThisObject[1] := SubStr(CodeOnlyBuchstaben[0], 1, 3)
                }
                
                ; Element an Index 3 entfernen
                if ThisObject.Length >= 3
                    ThisObject.RemoveAt(3)
            }
            else
            {
                IndexToRemove.Push(index)
            }
        }
        
        ; --- 4. Markierte Elemente entfernen ---
        ; Wir iterieren rückwärts durch IndexToRemove, um Index-Verschiebungen zu vermeiden.
        ; Das Original hat dies manuell berechnet, hier ist der saubere Weg.
        Loop IndexToRemove.Length
        {
            ; Wir holen den Index von hinten nach vorne (wie im Original)
            idxToRemove := IndexToRemove[IndexToRemove.Length - A_Index + 1]
            DataArray.RemoveAt(idxToRemove)
        }
        
        ; --- 5. Spalten tauschen falls nötig ---
        for index, element in DataArray
        { 
            ; Sicherheitsprüfung, ob Indizes existieren
            val1 := (DataArray[index].Has(1)) ? DataArray[index][1] : ""
            val2 := (DataArray[index].Has(2)) ? DataArray[index][2] : ""

            if ( (Trim(TableShort, " ") = Trim(val1, " ")) && (Trim(TableShort, " ") != Trim(val2, " ")) || (val1 = val2) )
            {
                TempTable := DataArray[index][1]
                TempFeld := DataArray[index][3] ; War im Original [3], durch removeAt(3) oben ist alles eins nach links gerutscht? 
                ; ACHTUNG: Im Original wurde oben 'ThisObject.RemoveAt(3)' ausgeführt. 
                ; Das heißt, der alte Index 4 ist jetzt Index 3.
                ; Die Logik unten greift auf [3] und [4] zu. Da wir in v2 Referenzen nutzen, 
                ; wirkt sich RemoveAt(3) direkt auf DataArray[index] aus.
                
                ; Falls das Array nach RemoveAt(3) kürzer ist, müssen wir sicherstellen, dass [4] existiert.
                if DataArray[index].Length >= 4 {
                    DataArray[index][1] := DataArray[index][2]
                    DataArray[index][3] := DataArray[index][4]
                    
                    DataArray[index][2] := TempTable
                    DataArray[index][4] := TempFeld
                }
            }
        }
        
        Return DataArray
    }
    
    ; Diese Methode in ControlSpaceProcessor anpassen:
    ListViewFromDataArray(dataArray, buttonNames, header, callbackObj, colWidths, title, clipToSearch, lvOptions:="", sonderfunktion:="") {
        
        finalCallback := ""
        
        if IsObject(callbackObj) {
            finalCallback := callbackObj
        } 
        else if (callbackObj = "AusgabeJoinSubroutine") {
            ; WICHTIG: Hier binden wir auf die Methode HandleJoinSelection
            finalCallback := ObjBindMethod(this, "HandleJoinSelection")
        }
        else if (callbackObj = "AusgabeFeldSubroutine") {
            finalCallback := ObjBindMethod(this, "HandleFieldSelection") 
        }

        useJoinsEdit := (sonderfunktion = "JoinsEdit")
        ViewClass := this.UI.DynamicListView
        
        view := ViewClass(title, header, dataArray, finalCallback, lvOptions)
        view.Show(buttonNames, colWidths, useJoinsEdit)
    }

HandleJoinSelection(result) {
        ; 1. Entpacken des Result-Objekts
        btnName      := result.ButtonName
        selectedRows := result.Rows
        alias1       := result.Alias1
        alias2       := result.Alias2

        ; 2. Abbruchbedingungen
        if (btnName = "Cancel" || btnName = "Abbrechen" || !selectedRows || selectedRows.Length = 0)
            return

        this.State.SetBusy(true)
        try {
            ; DataArray Structure: [1]From(Short)|[2]To(Short)|[3]FromCol|[4]ToCol|[5]Manuell
            row := selectedRows[1] 

            shortFrom  := row[1]  ; z.B. PER
            shortTo    := row[2]  ; z.B. MIT
            
            colRawFrom := row[3]  ; "PERSONENID; FIRMENNR"
            colRawTo   := row[4]  ; "LIEF_PERSONENID; LIEF_FIRMENNR"
            manuell    := row[5] 

            ; --- VIEW CHECK & PREFIX LOGIK ---
            
            ; Check für Alias 1 (Linke Seite)
            prefix1 := ""
            if (alias1 != "") {
                sep1 := "." ; Standard-Trenner
                try {
                    ; Prüfen ob View Datei existiert/Daten hat
                    dataView1 := this.GetViewDataFromFile("." . alias1 . "_")
                    if (dataView1.Length > 0)
                        sep1 := "_"
                }
                prefix1 := alias1 . sep1
            }

            ; Check für Alias 2 (Rechte Seite)
            prefix2 := ""
            if (alias2 != "") {
                sep2 := "." ; Standard-Trenner
                try {
                    ; Prüfen ob View Datei existiert/Daten hat
                    dataView2 := this.GetViewDataFromFile("." . alias2 . "_")
                    if (dataView2.Length > 0)
                        sep2 := "_"
                }
                prefix2 := alias2 . sep2
            }

            ; --- JOIN LOGIK ---
            arrFrom := StrSplit(colRawFrom, ";")
            arrTo   := StrSplit(colRawTo, ";")
            
            conditions := []
            
            ; Über die Elemente loopen (z.B. PersonenID und FirmenNr)
            Loop Min(arrFrom.Length, arrTo.Length) {
                valFrom := Trim(arrFrom[A_Index])
                valTo   := Trim(arrTo[A_Index])
                
                ; Aufbau: Alias1.PER_PERSONENID = Alias2.MIT_LIEF_PERSONENID
                ; (Oder Alias1_PER_PERSONENID falls View)
                leftSide  := prefix1 . shortFrom . "_" . valFrom
                rightSide := prefix2 . shortTo   . "_" . valTo
                
                conditions.Push(leftSide " = " rightSide)
            }
            
            ; Mit " AND " verknüpfen
            conditionString := ""
            for index, cond in conditions {
                if (index > 1)
                    conditionString .= " AND "
                conditionString .= cond
            }

            ; --- TABELLEN NAME ---
            ; Versuchen den vollen Namen zu holen (SearchTable), sonst Fallback auf Kürzel
            tablePart := shortTo
            try {
                fullTableName := this.SearchTable(shortTo)
                if (fullTableName != "")
                    tablePart := fullTableName
            }
            
            if (alias2 != "")
                tablePart .= " " alias2

            ; --- AUSGABE ---
            output := "LEFT JOIN " tablePart " ON " conditionString
            
            ; Override falls Manuell gesetzt
            if (manuell != "" && colRawFrom == "") {
                 output := manuell
            }

            SendInput "{Text}" StrUpper(output)

        } catch as err {
            MsgBox("Fehler beim Erstellen des Joins: " err.Message)
        } finally {
            this.State.SetBusy(false)
        }
    }

    ; -------------------------------------------------------------------------
    ; FIELD SELECTION HANDLER
    ; Wird aufgerufen via: ObjBindMethod(this, "HandleFieldSelection", tableName)
    ; Parameter:
    ;   tableName - Kommt aus dem Bind (wurde beim Erstellen des Callbacks fixiert)
    ;   result    - Kommt aus DynamicListView {ButtonName, Rows, ...}
    ; -------------------------------------------------------------------------
    HandleFieldSelection(tableName, result) {
        ; 1. Entpacken des Result-Objekts
        btnName      := result.ButtonName
        selectedRows := result.Rows
        ; alias1/2 werden hier ignoriert

        ; 2. Abbruchbedingungen
        if (btnName = "Cancel" || btnName = "Abbrechen" || !selectedRows || selectedRows.Length = 0)
            return

        this.State.SetBusy(true)
        try {
            commaList := ""
            
            ; Loop durch alle ausgewählten Felder
            for index, rowData in selectedRows {
                fieldName := rowData[1]
                
                ; Tabellenname + Feldname (z.B. KUN_NAME)
                fullField := StrUpper(tableName "_" fieldName) 
                
                switch btnName {
                    case "Beistrich":
                        ; Bei Beistrich sammeln wir erst alles
                        commaList .= (commaList = "" ? "" : ", ") . fullField

                    case "GetValue":
                        SendInput "{Text}lModel.getValue(MCA_'" fullField "');`n"

                    case "SetValue":
                        ; Wir schreiben es einfach hintereinander weg
                        SendInput "{Text}lModel.setValue(MCA_'" fullField "', );`n"

                    case "GetAsString":
                        SendInput "{Text}lModel.getAsString('" fullField "');`n"
                    
                    case "SetParamAsString":
                        SendInput "{Text}lModel.setParamAsString('" fullField "', );`n"
                    
                    ; Fallback für Enter/Doppelklick ohne spezifischen Button (Standard)
                    case "Auswählen (Enter)":
                         SendInput "{Text}" fullField
                }
            }

            ; Nach dem Loop: Ausgabe für gesammelte Listen (Beistrich)
            if (btnName = "Beistrich" && commaList != "") {
                SendInput "{Text}" commaList
            }
            
            ; Cursor-Korrektur: Wenn nur EINE Zeile und SetValue/SetParam gewählt wurde
            ; bewegen wir den Cursor in die Klammer (Schönheitskorrektur)
            if (selectedRows.Length = 1 && (btnName = "SetValue" || btnName = "SetParamAsString")) {
                ; Das ;`n löschen und Cursor in die Klammer bewegen
                ; {Backspace 2} löscht `n und ;
                ; {Left 2} geht in die Klammer -> 'Field', | )
                SendInput "{Backspace 2}{Left 2}" 
            }

        } catch as err {
        } finally {
            this.State.SetBusy(false)
        }
    }
    
    SendConfig(key, prefix){
        value := this.Config.Get("Snippets", key, "")
        if (prefix != "")
            SendInput "{Raw}" prefix

        SendInput value
    }
}