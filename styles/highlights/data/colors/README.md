# Highlights colour schemes

This directory contains flat YAML colour scheme files in the Highlights format.
**Do not hand-edit generated files** — they are the canonical output of the converter and will be overwritten on re-runs.

## File format (four declarative sections)

Authors may choose **any** names under `palette`; that map is referenced by **`terminal`**, **`document`**, and **`syntax`** (string values → palette keys, not raw hex unless you skip indirection elsewhere).

Each file defines one colour variant. Example skeleton:

```yaml
meta:
  name: Catppuccin Mocha
  origin: "https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/alacritty/Catppuccin%20Mocha.toml"
palette:
  background: "#1e1e2e"
  foreground: "#cdd6f4"
  black: "#45475a"
  # … normal + bright keys as needed
terminal:
  background: background
  foreground: foreground
  black: black
  bright-black: bright-black
  # … one entry per canonical terminal slot emitted by highlights-import
document:
  text:
    primary: foreground
    # …
syntax:
  variable: magenta
  keyword: red
```

- **`palette`**: arbitrary key → `#rrggbb` (or shorthand via comb’s string rules elsewhere).
- **`terminal`**: **stable terminal slot keys** mapping each slot to a **`palette`** key string. Wig resolves these to hex in `colors.resolveColorsData` like `document` / `syntax`.
- **`document`**, **`syntax`**: unchanged conventions (semantic roles → **`palette`** keys).

Bulk-generated themes also set **`meta.origin`** URL to the upstream Alacritty `.toml` blob (HTTPS, percent-encoded filename). Omit with `-` on the importer (see below); handcrafted themes may omit or set manually.

## Generated schemes (iTerm2-Color-Schemes)

Schemes are generated from the [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) repository (`alacritty/*.toml`). To regenerate:

```sh
git clone https://github.com/mbadolato/iTerm2-Color-Schemes /tmp/iterm2
cd wig-stand
zig build highlights -Dsource=/tmp/iterm2/alacritty
```

Build options affecting **`meta.origin`**:

| Flag | Meaning |
|------|---------|
| (default third arg when using `zig build`) | **`https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/alacritty/`** prefix |
| `-Dhighlight-origin=https://…/alacritty/` | Alternate blob prefix (still must end with `alacritty/`) |
| `-Domit-highlight-origin=true` | Passes `-` to the importer → omit `meta.origin` lines |

Running **`highlights-import`** directly:

```text
highlights-import <source-dir> <output-dir> [origin-prefix]
```

- Omit **`origin-prefix`** to use upstream default blob prefix above.
- Use **`-`** to omit **`meta.origin`**.

Re-runs are idempotent: unchanged files are not re-written; new files are added.

## Handcrafted schemes

- `highlights-light.yaml` — "Warm Light" (handcrafted default)
- `highlights-dark.yaml` — "Warm Dark" (handcrafted default)

These are not overwritten by the converter.

## Role mapping (Alacritty → importer)

The bulk importer derives **`palette`**, **`terminal`** (usually identity refs), **`document`**, **`syntax`** as follows:

| Highlights role | Alacritty source |
|---|---|
| `document.text.primary` | `colors.primary.foreground` |
| `document.text.secondary` | `colors.bright.black` |
| `document.text.emphasis` | `colors.bright.white` |
| `document.text.heading` | `colors.primary.foreground` |
| `document.text.link` | `colors.normal.blue` |
| `document.background.primary` | `colors.primary.background` |
| `document.background.secondary` | `colors.normal.black` |
| `document.background.embed` | `colors.bright.black` |
| `syntax.variable` | `colors.normal.magenta` |
| `syntax.constant` | `colors.bright.magenta` |
| `syntax.punctuation` | `colors.bright.black` |
| `syntax.operator` | `colors.normal.white` |
| `syntax.number` | `colors.normal.yellow` |
| `syntax.type` | `colors.normal.cyan` |
| `syntax.function` | `colors.normal.blue` |
| `syntax.string` | `colors.normal.green` |
| `syntax.comment` | `colors.bright.black` |
| `syntax.keyword` | `colors.normal.red` |

**`terminal`** keys mirror the importer’s **`palette`** names (`black`, `bright-black`, …, `foreground`, `background`).
