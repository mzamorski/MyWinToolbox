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
| `Win + Ctrl + E` | Open **Emoji** menu. |
| `Win + Ctrl + D` | Paste the current local date/time. |
| `Ctrl + Tab` | Insert the configured number of spaces (`SpacesPerIndent`). |
| `Win + Space` | Copy the pixel color under the mouse pointer and briefly show a color swatch. |

### Windows and Explorer

| Shortcut | Action |
| --- | --- |
| `Win + Ctrl + Page Up` | Toggle **Always on Top** for the active window. |
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
| **Crypto.RC4 → Encrypt / Decrypt** | Encrypt/decrypt using the active profile's configured `Secret`. |
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

The menu is generated from `TextSnippets.json`.

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

Dynamic entries support enable/disable state, AutoHotkey options, send mode, tags, and include/exclude scopes by process, class, or title.

---

## 🏠 Home profile

Run `MyWinHome.ahk`.

| Shortcut / hotstring | Action |
| --- | --- |
| `@a=` | Paste configured shipping address. |
| `Win + Ctrl + P` | Paste a decrypted password. Automatically picks **KeePass** when KeePass is active and **XTB** when the current browser URL contains XTB; otherwise opens the password menu. |

Password values come from the profile's `[Passwords]` section and are decrypted with the configured `Secret`.

---

## 💼 Work profile

Run `MyWinWork.ahk`.

### General work tools

| Shortcut / hotstring | Action |
| --- | --- |
| `@k=` | Paste configured work email. |
| `Ctrl + Win + A` | Toggle **NoSleep**. Keeps system/display execution state active and periodically nudges the pointer while idle. |
| `Ctrl + Win + T` | Open **Task Runner** menu. |

### Task Runner

| Menu item | Action |
| --- | --- |
| **NoSleep** | Toggle the same NoSleep state as `Ctrl + Win + A`. |
| **Shutdown → 1h** | Schedule shutdown using the menu's 1-hour preset. |
| **Shutdown → 2h** | Schedule shutdown using the menu's 2-hour preset. |
| **Shutdown → Cancel** | Cancel the pending shutdown timer created by Task Runner. |
| **Clipboard → Trim** | Continuously trim leading/trailing spaces, tabs, CR, and LF from clipboard updates. |

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

`AutoPastes.json` defines automatic paste actions triggered when a matching window appears. Matching can use executable, window class, and title. A window handle is processed only once.

Current repository examples:

| Rule | Match | Action |
| --- | --- | --- |
| **Notepad** | `notepad.exe` | Paste `Hello World!`. |
| **Notepad++** | `notepad++.exe` | Paste `Hello World++!`. |
| **Cisco Secure Client** | executable + class + title | Decrypt the configured `CiscoSecurityPassword` and paste it. |

For secrets, use `passwordKey` and keep only the encrypted value in the profile configuration.

---

## Configuration-driven features

These parts of the cheat sheet can change without editing the AHK code:

- `MyWinShared.ahk.config` — indent width and dummy text.
- `MyWinHome.ahk.config` / `MyWinWork.ahk.config` — email, secret, signatures, audio devices, passwords, and profile-specific values.
- `HotStrings.json` — dynamic hotstrings and scopes.
- `TextSnippets.json` — snippet categories and content.
- `AutoPastes.json` — automatic window-matching paste rules.

---

## Implementation notes

Two timer-related details are worth checking in the current code:

1. **Task Runner shutdown presets** pass `HOUR_IN_MILLISECONDS` into a function that multiplies the value by `SECOND_IN_MILLISECONDS` again. The labels say 1h/2h, but the actual timer value appears to be 1000× larger than intended.
2. **NoSleep pointer nudge** checks `A_TimeIdle > 10 * SECOND_IN_MILLISECONDS` and the handler itself runs every 60 seconds. That differs from the README wording that mentions 10 minutes.

These notes describe the current implementation and are separate from the intended UI labels above.
