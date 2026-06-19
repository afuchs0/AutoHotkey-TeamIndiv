; Main.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 1. DEFINITIONEN LADEN
; ==============================================================================

; Core (Basis-Klassen)
#Include "Lib\Core\AppPaths.ahk"
#Include "Lib\Core\ConfigProvider.ahk"
#Include "Lib\Core\AppState.ahk"
#Include "Lib\Core\AppContext.ahk" 

; Utilities
#Include "Lib\Utils\ClipboardUtil.ahk"
#Include "Lib\Core\Logger.ahk" 

; Services (Logik-Module)
#Include "Lib\Services\ControlSpaceProcessor.ahk"
#Include "Lib\Services\GeneralHotkeys.ahk"

; UI (GUIs)
#Include "Lib\UI\ControlSpace.ahk"
#Include "Lib\UI\DynamicListView.ahk"


; ==============================================================================
; 2. BOOTSTRAPPING (App starten)
; ==============================================================================

; Wir erstellen die App-Instanz.
; Da alle Includes oben stehen, kennt AHK jetzt die Klassen "AppPaths", "ConfigProvider" usw.
global App := AppContext()

; ==============================================================================
; 3. HOTKEYS AKTIVIEREN
; ==============================================================================

; Die Hotkeys werden erst JETZT geladen, damit die Variable 'App' sicher existiert.
#Include "Hotkeys\1_IsTargetWindow.ahk"
#Include "Hotkeys\2_else.ahk"
