# MyWinToolbox — Shortcut Sheet

> A compact reference for the user-facing shortcuts, hotstrings, menus, automations, and profile-specific tools currently wired into **MyWinToolbox**.

MyWinToolbox has two mutually exclusive profiles:

- **Home** — `MyWinHome.ahk`
- **Work** — `MyWinWork.ahk`

Both profiles include everything from `MyWinShared.ahk`.

## Key legend

| Symbol / key | Meaning |
| --- | --- |
| `Win` | Windows key |
| `Ctrl` | Control |
| `Alt` | Alt |
| `RButton` | Right mouse button |
| `Volume Mute` | Keyboard media mute key |

---

## ⭐ Shared shortcuts

### Menus and text tools

| Shortcut | Action |
| --- | --- |
| `Ctrl + Win + F1` | Open the bundled **PDF Shortcut Sheet** (`Docs/SHORTCUTS.pdf`). |
| `Win + Ctrl + F` | Open **Format** menu. |
| `Win + Ctrl + I` | Open **String Generator** menu. |
| `Win + Ctrl + S` | Open **Text Snippets** menu. |
| `Win + Ctrl + Shift + S` | Open the tabbed **MyWinToolbox Configurator** for Text Snippets, HotStrings/scopes, AutoPaste, and Settings. |
| `Win + Ctrl + E` | Open **Emoji** menu. |
| `Win + Ctrl + D` | Paste the current local date/time. |
| `Ctrl + Tab` | Insert the configured number of spaces (`SpacesPerIndent`). |
| `Win + Space` | Copy the pixel color under the mouse pointer and briefly show a color swatch. |
| `Ctrl + Win + A` | Toggle **NoSleep**. Keeps system/display execution state active and periodically nudges the pointer while idle. |
| `Ctrl + Win + T` | Open **Task Runner** menu. |

### Task Runner

| Menu item | Action |
| --- | --- |
| **NoSleep** | Toggle the same NoSleep state as `Ctrl + Win + A`. |
| **AutoPaste** | Enable or disable automatic paste rules loaded from `AutoPastes.json`. AutoPaste starts **disabled** after every script start/reload. |
| **Shutdown → 1h** | Schedule shutdown using the menu's 1-hour preset. |
| **Shutdown → 2h** | Schedule shutdown using the menu's 2-hour preset. |
| **Shutdown → Cancel** | Cancel the pending shutdown timer created by Task Runner. |
| **Clipboard → Trim** | Continuously trim leading/trailing spaces, tabs, CR, and LF from clipboard updates. |

### Windows and Explorer

| Shortcut | Action |
| --- | --- |
| `Win + Ctrl + Page Up` | Toggle **Always on Top** for the active window. |
| `Win + Ctrl + K` | Toggle **KeepAlive** for the active window. Every 5 minutes MyWinToolbox briefly restores/activates the target, sends a tiny foreground mouse movement, restores the previous cursor/focus, and re-minimizes the target if needed. Each HWND is tracked independently. |
| `Win + Ctrl + W` | Open **Window Toolbox** for the active window: always-on-top, KeepAlive, process mute, center/thirds, monitor move, copy info, close similar windows, and create an AutoPaste rule draft. |
| `Win + Alt + F4` | Close windows matching the active window's **class + exact title**. |
| `Ctrl + Win + F4` | Close all windows matching the active window's **class**. |
| `Ctrl + Win + M` | In Explorer, move selected files/folders into a newly created subfolder. Default folder name is a timestamp. |
| `Win + Alt + C` | Copy active-window diagnostics to the clipboard: title, class, PID, EXE, HWND, position, size, monitor, DPI, and Explorer path when available. |

### Window grid

| Shortcut | Action |
| --- | --- |
| `Win + Ctrl + 1` | Move the active window to the **left third** of its current monitor. |
| `Win + Ctrl + 2` | Move the active window to the **middle third**. |
| `Win + Ctrl + 3` | Move the active window to the **right third**. |

### Minimize to tray

| Shortcut / action | Action |
| --- | --- |
| `Win + Right Click` on a window caption | Hide that window and create a dedicated tray icon for it. |
| Left-click the generated tray icon | Restore the hidden window and remove its temporary tray icon. |
| Tray menu → **Restore all windows** | Restore every window hidden by MyWinToolbox. |
| `Ctrl + Alt + H` | Diagnostic helper: show the current `WM_NCHITTEST` value under the pointer. |

> The minimize-to-tray hotkey is currently scoped to the **window caption** area.

### Audio

| Shortcut | Action |
| --- | --- |
| `Ctrl + Numpad 4` / `Ctrl + Numpad Left` | Switch default audio output to configured **Headphones**. |
| `Ctrl + Numpad 8` / `Ctrl + Numpad Up` | Switch default audio output to configured **Monitor**. |
| `Ctrl + Numpad 6` / `Ctrl + Numpad Right` | Switch default audio output to configured **Laptop** speakers/device. |
| `Win + Ctrl + Volume Mute` | Toggle mute for the **active application's audio sessions** on the default output device. |

The exact audio endpoints come from the active profile configuration.

### Script control

| Shortcut | Action |
| --- | --- |
| `Ctrl + Win + Home` | Reload the active MyWinToolbox profile. |
| `Ctrl + Win + End` | Exit the active MyWinToolbox profile. |

---

## 🧰 Format menu — `Win + Ctrl + F`

The Format menu copies the current selection through the clipboard, transforms it, and pastes the result.

| Menu item | Function |
| --- | --- |
| **ToUpper** | Convert text to uppercase. |
| **ToLower** | Convert text to lowercase. |
| **Sort → Ascending** | Sort lines ascending. |
| **Sort → Descending** | Sort lines descending. |
| **ToSingleLine** | Collapse text into a single line. |
| **ToQuoted.Single** | Wrap content in single quotes. |
| **ToQuoted.Double** | Wrap content in double quotes. |
| **BreakLines → 80 / 120** | Wrap text to the selected line width. |
| **Char.Replicate → 80 / 120** | Repeat the selected character to the requested length. |
| **Path.ToSingleBackslash** | Normalize path separators to single backslashes. |
| **Path.ToDoubleBackslash** | Escape path separators as double backslashes. |
| **Path.ToBackslash** | Convert path separators back to ordinary backslashes. |
| **SQL.AddBraket** | Add SQL-style square brackets. |
| **SQL.RemoveBraket** | Remove SQL-style square brackets. |
| **SQL.ToQuotedList** | Convert non-empty lines into a comma-separated list of single-quoted SQL values. |
| **SQL.ToValuesTable** | Convert lines into a `SELECT * FROM (VALUES ...)` table expression. |
| **Number.AddThousandsSeparators** | Add thousands separators to a number. |
| **Crypto.RC4 → Encrypt / Decrypt** | Legacy RC4 clipboard helper using the active profile's configured `Secret`. Password storage now uses Windows DPAPI. |
| **Crypto.BASE64 → Encrypt / Decrypt** | Base64 encode/decode. |
| **AHK.ToSpecialKeys** | Convert line breaks/tabs to AutoHotkey key sequences such as `{Enter}` and `{Tab}`. |

---

## 🎲 String Generator — `Win + Ctrl + I`

| Menu item | Function |
| --- | --- |
| **Random.Guid** | Generate a GUID without braces. |
| **Random.String → 16** | Generate a 16-character random string. |
| **Random.String → 32** | Generate a 32-character random string. |
| **Random.String → Dummy** | Paste configured dummy text. |
| **Date.Current** | Paste current local date. |
| **DateTime.Current → Local** | Paste current local date/time. |
| **DateTime.Current → UTC ISO-8601** | Paste current date/time in ISO-8601 UTC form. |
| **Separator → 50 / 80 / 120** | Paste a dash separator of the selected length. |
| **UserSignatures → ...** | Paste a configured signature from the active profile. |

---

## 📝 Text Snippets — `Win + Ctrl + S`

The menu is generated from `TextSnippets.json`. Use `Win + Ctrl + Shift + S` to open the shared **MyWinToolbox Configurator** instead of modifying JSON manually. The **Text Snippets** tab supports categories, snippets, descriptions, separators, duplication, deletion, reordering, validation, and automatic `.bak` backups.

### T-SQL

- **TRY**
- **BREAK**
- **SELECT**
- **DELETE.Duplicates**
- **DIFF <mine-table> <their-table>**
- **SCHEMA.Change**

### GIT

- **Revert.WorkingTree**
- **Revert.Working.All**
- **Revert.Staged.All**
- **Revert.Hard**
- **Reset.ToRemote**
- **Clean.Untracked**
- **Clear.Credentials**
- **Commit.Edit**
- **Branch.Push**
- **Branch.Create**
- **Log.Graph**
- **Log.OneLine**
- **Log.Search.ByAuthor**
- `git reset --hard HEAD~1`
- `git reset --soft HEAD~1`
- `git restore .`

### Markdown

- **Link**
- **Link.Image**
- **Heading.Level-1**
- **Bold**
- **Quotes.Block**
- **Quotes.Block.Nested**
- **Code**
- **Code.Block**

Some snippets also position/select placeholders after insertion so they can be overwritten immediately.

---

## 😀 Emoji menu — `Win + Ctrl + E`

Current built-in entries:

| Emoji | Meaning |
| --- | --- |
| 🤑 | Money-Mouth Face |
| 👍 | Thumbs Up |
| 👎 | Thumbs Down |
| ☠️ | Skull and Crossbones |
| 💨 | Dashing Away |

---

## ⌨️ Shared hotstrings

### General

| Type this | Result |
| --- | --- |
| `@=` | Configured email address. |
| `@me` | Configured email address. |
| `--=` | 120-character dash separator. |
| `123k=` | `123000` — works for any digits followed by `k=`. |
| `@--` | — |
| `@->` | → |
| `@v` | ✓ |
| `@..` | • |
| `@.o` | ○ |
| `@.k` | ▪ |
| `@.>` | ‣ |
| `@cb` | ☐ |
| `@x` | ✗ |
| `@!!` | ⚠ |
| `@pp` | § |
| `@oo` | ° |
| `@...` | … |

### Command Prompt / Windows Terminal only

| Type this | Inserts |
| --- | --- |
| `s30m=` | `shutdown -s -t 1800` |
| `s1h=` | `shutdown -s -t 3600` |
| `s2h=` | `shutdown -s -t 7200` |

### TortoiseGit only

| Type this | Result |
| --- | --- |
| `r=` | `Refactoring.` |

---

## ⚡ Dynamic hotstrings

Loaded from `HotStrings.json`. Current repository examples:

| Trigger | Replacement | Scope |
| --- | --- | --- |
| `sig` | Multi-line signature | Notepad only |
| `addr` | Multi-line work address | Everywhere |
| `btw` | `By the way` | Notepad / Notepad++ text-editor scope |

Dynamic entries support enable/disable state, AutoHotkey options, send mode, tags, and include/exclude scopes by process, class, or title. Use `Win + Ctrl + Shift + S` → **HotStrings** to edit entries and **HotString Scopes** to manage reusable scope aliases. `Save + Reload` applies HotString changes immediately after saving.

---

## 🏠 Home profile

Run `MyWinHome.ahk`.

| Shortcut / hotstring | Action |
| --- | --- |
| `@a=` | Paste configured shipping address. |
| `Win + Ctrl + P` | Paste a decrypted password. Automatically picks **KeePass** when KeePass is active and **XTB** when the current browser URL contains XTB; otherwise opens the password menu. |

Password values come from the profile's `[Passwords]` section. New entries use Windows DPAPI (`dpapi:v1:`); legacy RC4 entries are still decrypted with the configured `Secret` until migrated.

---

## 💼 Work profile

Run `MyWinWork.ahk`.

### General work tools

| Shortcut / hotstring | Action |
| --- | --- |
| `@k=` | Paste configured work email. |

### SQL Server Management Studio hotstrings

These are active only when `ssms.exe` is the foreground application.

| Type this | Result |
| --- | --- |
| `try=` | Insert a `BEGIN TRY / END TRY / BEGIN CATCH / END CATCH` template. |
| `break=` | Insert a `THROW 50000...` guard for step-by-step scripts. |
| `nl=` | Insert `WITH (NOLOCK)`. |
| `dt=` | Insert `DROP TABLE IF EXISTS `. |
| `sel=` | Build a `SELECT TOP 100 ... FROM <clipboard> AS t WITH (NOLOCK)` query using the clipboard as the table name. |
| `dirty` | Insert `SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;`. |

---

## 🤖 AutoPaste

`AutoPastes.json` defines automatic paste actions triggered when a matching window appears. Rules are loaded and validated at startup, but AutoPaste itself starts **disabled**; enable it from `Ctrl + Win + T` → **AutoPaste**. Matching can use executable, window class, title, and—when a browser is active—the current tab URL. Title and URL criteria use containment by default and support exact matching with `titleMatchMode: "equals"` or `urlMatchMode: "equals"`.

Current repository examples:

| Rule | Match | Action |
| --- | --- | --- |
| **Notepad** | `notepad.exe` | Paste `Hello World!`. |
| **Notepad++** | `notepad++.exe` | Paste `Hello World++!`. |
| **Cisco Secure Client** | executable + class + title | Decrypt the configured `CiscoSecurityPassword` and paste it. |

Example browser rule:

```json
{
  "name": "Example login",
  "exe": "msedge.exe",
  "url": "https://example.com/login",
  "urlMatchMode": "contains",
  "text": "Hello from AutoPaste"
}
```

Browser URLs are read non-interactively through Windows UI Automation. AutoPaste does **not** use the `Ctrl+L` / `Ctrl+C` address-bar fallback: if UIA cannot expose the URL, the URL rule simply does not match, so browsing focus and clipboard contents are left untouched. URL lookup only runs for rules that declare `url` and after their other window filters match. The default trigger mode is `oncePerWindow`; URL rules can opt into `oncePerUrl`, while `always` disables processed-state suppression and repeats on each 500 ms timer match.

Set `"notifyOnMatch": true` on a rule to show a Windows notification after all match criteria succeed and before the paste is attempted. The notification includes the matched rule, executable, title, and URL when applicable, which is useful for diagnosing whether a failure is in matching or in the later focus/paste step.

Use an ordered `actions` list for keyboard focus/navigation and multi-field forms. Each action has exactly one operation: `keys`, `delay`, `text`, or `passwordKey`.

```json
{
  "name": "Example credentials",
  "exe": "msedge.exe",
  "url": "https://example.com/login",
  "actions": [
    { "keys": "{Tab 2}" },
    { "delay": 150 },
    { "passwordKey": "ExampleLogin" },
    { "keys": "{Tab}" },
    { "passwordKey": "ExamplePassword" },
    { "keys": "{Enter}" }
  ]
}
```

Simple top-level `text` and `passwordKey` rules remain supported. Legacy `focus` / `focusDelay` are accepted only for backward compatibility and are normalized into leading actions; new rules should use `actions` only. The action list is validated before execution, so an invalid item prevents the entire sequence from starting.

The entire `AutoPastes.json` file is validated at startup. Configuration errors identify the affected rule and action before any AutoPaste timer starts. The same rules can be edited from `Win + Ctrl + Shift + S` → **AutoPaste**, including matchers, match modes, trigger mode, notifications, delay and ordered actions. Use **Capture window...** to hide the Configurator and click a target window; EXE, class, title and browser URL (when UIA exposes it) are filled automatically. Use **Test match...** to click a target and see `✓` / `✗` results for every configured matcher without running any AutoPaste action. Saving refreshes AutoPaste immediately and preserves whether it was enabled.

---

## Configuration-driven features

The **Settings** tab in `Win + Ctrl + Shift + S` edits known shared/profile INI fields, audio devices, signatures and encrypted passwords. New passwords use Windows DPAPI and are marked `[DPAPI]`; legacy entries are marked `[RC4]` and can be converted with **Migrate RC4 -> DPAPI**. JSON/INI saves create `.bak` backups; use **Save + Reload** when changing HotStrings or Settings.

These parts of the cheat sheet can change without editing the AHK code:

- `MyWinShared.ahk.config` — indent width and dummy text.
- `MyWinHome.ahk.config` / `MyWinWork.ahk.config` — email, signatures, audio devices, DPAPI-protected passwords, profile-specific values, and an optional legacy RC4 `Secret` while unmigrated values remain.
- `HotStrings.json` — dynamic hotstrings and scopes.
- `TextSnippets.json` — snippet categories and content.
- `AutoPastes.json` — automatic window-matching paste rules.

