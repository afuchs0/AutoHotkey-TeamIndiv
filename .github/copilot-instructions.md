# AI Coding Instructions for AutoHotkey Team Indiv

## Project Overview
This is an **AutoHotkey v2.0 productivity automation framework** for enterprise macro editing (BMD system). It provides context-aware hotkey processing, configuration management, and snippet/command execution with a decoupled service architecture.

## Architecture & Key Components

### Core Layer (`Lib/Core/`)
- **AppContext** ([Lib/Core/AppContext.ahk](Lib/Core/AppContext.ahk)): Central dependency injection container. Bootstraps `Paths`, `Config`, `State`, `Services`, and `UI` in strict order (Paths → Config → Logger → State → Services → UI)
- **AppPaths** ([Lib/Core/AppPaths.ahk](Lib/Core/AppPaths.ahk)): Manages all file paths (config, data, SQL, logs)
- **ConfigProvider** ([Lib/Core/ConfigProvider.ahk](Lib/Core/ConfigProvider.ahk)): Reads `.ini` files with recursive placeholder resolution. Syntax: `{config "Key"}` resolves recursively; missing keys return empty string (not error)
- **AppState** ([Lib/Core/AppState.ahk](Lib/Core/AppState.ahk)): Global flags (`IsTyping` prevents hotkey recursion, `LastSearchTerm`, `CurrentTicketId`)

**Critical Detail**: Hotkeys load AFTER `App` is instantiated ([main.ahk#L43](main.ahk#L43)). The `#HotIf !App.State.IsTyping` guard blocks all hotkeys during automation to prevent re-entrance.

### Services Layer (`Lib/Services/`)
- **ControlSpaceProcessor** ([Lib/Services/ControlSpaceProcessor.ahk](Lib/Services/ControlSpaceProcessor.ahk)): Command dispatcher (Ctrl+Space). Prefix-based routing: `query` → HandleQuery, `update` → HandleUpdate, 6-letter + alpha → Join, contains `_` → Field search, `gv`/`sp` → Getter/Setter
- **GeneralHotkeys** ([Lib/Services/GeneralHotkeys.ahk](Lib/Services/GeneralHotkeys.ahk)): Handles F1–F12, Ctrl+Space, Ctrl+Plus, Ctrl+Shift+B. Receives 6 dependencies: state, config, ui, appPaths, csProcessor, logger
- Each service receives dependencies in constructor for testability

### Utilities
- **ClipboardUtil** ([Lib/Utils/ClipboardUtil.ahk](Lib/Utils/ClipboardUtil.ahk)): `Copy()` (sends Ctrl+C, waits), `Paste()`, `PasteAndRestore()` (preserves clipboard), `Restore(savedData)`
- **Logger** ([Lib/Utils/Logger.ahk](Lib/Utils/Logger.ahk)): Writes to `%TEMP%\AHK_Logs\Usage.log` (configurable via `LogDir`)

### Configuration
- **settings.global.ini**: Bundled defaults (snippets, window titles, SQL templates, UI settings)
- **settings.user.ini**: Per-user overrides (reads first in `Get()` fallback chain)
- Sections: `[Snippets]`, `[WindowTitles]`, `[Settings]`, `[Database]`
- Config values support nested references: `Config.Get("Snippets", "query")` with `{config "OtherKey"}` resolution

## Critical Patterns & Conventions

### Hotkey Safety & Re-entrance Prevention
**All hotkeys use this guard** ([Hotkeys/Global.ahk](Hotkeys/Global.ahk#L1)):
```ahk
#HotIf !App.State.IsTyping
F1:: App.Services.General.HandleF1()
#HotIf
```
Wrap SendInput/clipboard in try/finally with `SetBusy()`:
```ahk
this.State.SetBusy(true)
try {
    SendInput "{Raw}text"
} finally {
    this.State.SetBusy(false)
}
```
Without this pattern, SendInput can trigger the same hotkey again, causing infinite loops.

### Command Routing in ControlSpaceProcessor
`Process()` dispatcher uses prefix-matching order ([ControlSpaceProcessor.ahk#L39-L80](Lib/Services/ControlSpaceProcessor.ahk#L39-L80)):
1. Alias resolution: `q` → `query`
2. Prefix `query` → `HandleQuery()`
3. Prefix `update` → `HandleUpdate()`
4. Snippet lookup in `[Snippets]` section → `SendSnippet()`
5. Length=6 + all alphabetic → Join lookup
6. Contains `_` → `HandleFieldSearch()`
7. Prefix `gv` → `HandleGetter()`
8. Prefix `sp` → Setter template
9. Else → send Right arrow (no-op)

**Important**: Special characters are extracted before command matching: `+query` → prefix=`+`, command=`query`

### Configuration with Recursive Resolution
`Get(section, key, defaultVal)` replaces `{config "Key"}` recursively:
```ini
[Snippets]
QueryVar=lQuery
query=... {config "QueryVar"} ...  ; Becomes "... lQuery ..."
```
If key missing: returns `defaultVal` (empty string default), does NOT throw error. This enables safe templates.

### Clipboard Operations
- `Copy()`: Sends Ctrl+C, waits 0.5s, returns clipboard text (empty if nothing selected)
- `Paste(text)`: Sets clipboard, sends Ctrl+V, sleeps 100ms
- `PasteAndRestore(text)`: Backup clipboard → paste → restore original (for non-destructive inserts)

Example: Extract word without losing clipboard:
```ahk
originalClip := ClipboardAll()
selectedText := ClipboardUtil.Copy()
ClipboardUtil.Restore(originalClip)
```

## Adding New Features

### New Hotkey (F-key or Ctrl+X)
1. Add handler in [GeneralHotkeys.ahk](Lib/Services/GeneralHotkeys.ahk): `HandleF5()` or `HandleMyFeature()`
2. Add binding in [Hotkeys/Global.ahk](Hotkeys/Global.ahk) with `#HotIf !App.State.IsTyping` guard
3. Inside handler: wrap SendInput in `this.State.SetBusy(true)` try/finally block
4. Use `this.Logger.Log("FeatureName")` for debugging

### New Command Type for Ctrl+Space
1. Add detection logic to [ControlSpaceProcessor.Process()](Lib/Services/ControlSpaceProcessor.ahk#L39) (prefix matching, specific character check, etc.)
2. Create handler method (e.g., `HandleMyCommand()`)
3. Add config/snippets to [settings.global.ini](Assets/Config/settings.global.ini) `[Snippets]` section
4. Test routing order—earlier conditions block later ones

### New Configuration Section
1. Add to [settings.global.ini](Assets/Config/settings.global.ini): `[MySection]` with `key=value` pairs
2. Access via `App.Config.Get("MySection", "key", "defaultValue")`
3. To use in INI strings: `{config "key"}` resolves recursively; missing keys → empty string

## Data Sources & SQL
- **SQL templates**: [Assets/SQL/Scripts/](Assets/SQL/Scripts/) (Ampel.sql, FelderVonSqlServer.sql, etc.)
- **Table metadata**: [Assets/SQL/Tables/exp_column_and_tables.csv](Assets/SQL/Tables/exp_column_and_tables.csv) and join files in `Manuelle Erweiterungen`
- **BMD system**: Macro editor window title in `[WindowTitles]` section; `allowWithoutAsking` setting gates Ctrl+Space usage

## Debugging & Logging
- Logs go to `%TEMP%\AHK_Logs\Usage.log` (set `LogDir` in [settings.global.ini](Assets/Config/settings.global.ini) to override)
- Use `this.Logger.Log("message")` in services (passed from [GeneralHotkeys](Lib/Services/GeneralHotkeys.ahk#L15))
- Check `App.State.IsTyping` flag in debugger when hotkeys don't fire (indicates active automation)
- F2 in macro editor checks window title against config; mismatch shows alert

## File Organization
```
main.ahk                 → Bootstrap: includes all classes, creates App, loads hotkeys
Hotkeys/Global.ahk       → All hotkey bindings (#HotIf guard, dispatch to services)
Lib/Core/                → Dependency injection (AppContext, Paths, Config, State)
Lib/Services/            → Business logic (ControlSpaceProcessor, GeneralHotkeys)
Lib/Utils/               → Reusable utilities (ClipboardUtil, Logger)
Assets/Config/           → .ini files (global defaults + user overrides)
Assets/SQL/Scripts/      → Query templates for database integration
```

## Common Tasks
- **Send a code snippet**: `this.Config.Get("Snippets", "templateName")` → `this.SendSnippet(template)`
- **Extract selected text non-destructively**: `savedClip := ClipboardAll()` → `ClipboardUtil.Copy()` → `ClipboardUtil.Restore(savedClip)`
- **Validate window focus before action**: `WinGetTitle("A")` vs. `App.Config.Get("WindowTitles", "MacroEditor")`
- **Prevent hotkey re-entrance**: Always wrap SendInput in try/finally with `SetBusy(true/false)`
- **Add a debug log**: `this.Logger.Log("context: " variable)` → check `%TEMP%\AHK_Logs\Usage.log`

## Include Order (Critical)
[main.ahk](main.ahk) order is intentional:
1. AppPaths (no dependencies)
2. ConfigProvider (needs Paths)
3. Logger (needs Paths)
4. AppState (independent)
5. AppContext (orchestrates all above)
6. Hotkeys (use global `App` variable)

Changing this order causes bootstrap failures.
