# MyWinToolbox
MyWinToolbox is a collection of AHK scripts designed to automate everyday tasks on Windows. This project includes various tools that simplify work, such as text formatters and helper scripts to streamline and accelerate repetitive tasks.

### Screenshots
Here are some screenshots showcasing the functionalities of MyWinToolbox:

- **Format menu.**

 ![Screenshot 1](Docs/Images/FormatMenu.png)

- **Generate string menu.**

![Screenshot 2](Docs/Images/StringGeneratorMenu.png)

- **Text snippets menu.**

![Screenshot 2](Docs/Images/TextSnippets.png)
![Screenshot 2](Docs/Images/TextSnippets-GIT.png)

### Note
This project uses [AutoHotkey 2.0](https://www.autohotkey.com/). For detailed information about the language and its features, please refer to the [documentation](https://www.autohotkey.com/v2/).

### Dynamic hotstrings
You can customize the script's text expansions without touching the code. Define new hotstrings in **Hotstrings.json**. The file accepts a rich structure with:

- A `defaults` section for shared options (e.g. default hotstring `options` or the fallback `scopeMode`).
- Named scope aliases under `scopes.aliases`, where each alias can limit matches by process name, window class, or title regex.
- A `hotstrings` array in which every entry specifies a `trigger` (or explicit `pattern`), optional `options`, output `text`, and scope rules via `includeScopes` / `excludeScopes`. Hotstrings can be toggled with `enabled`, prioritised through `priority`, and the output supports `%{DateTime:...}` placeholders that resolve to formatted timestamps during registration.
