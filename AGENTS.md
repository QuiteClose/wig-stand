# Wig Stand

Style showcase and demo site for **Wig**. Demonstrates Wig's style system, CUBE CSS patterns, and auto-generated pattern libraries across multiple styles. Each style gets a full preview with navigation, demo content, and its own pattern library.

**Wig Stand is a consumer of Wig, not part of it.** It is not a submodule of the wig repo. It serves as both a showcase and a real-world integration test for Wig's style system.

## Build and serve

```
wig build                  # build the site to zig-out/site/
wig serve                  # build, serve, watch, and live-reload
rm -rf zig-out && wig build   # clean build
```

If `wig` is not on your PATH, use `../wig/zig-out/bin/wig` (after building wig).

## Directory structure

```
wig-stand/
  data/               # site-level data (YAML)
  pages/              # content pages (Djot)
  styles/             # all styles (each with patterns, css, templates, demo content)
  assets/             # static files (images, fonts, demo stock photos)
  zig-out/site/       # build output (not checked in)
```

## Key data files

| File | Role |
|------|------|
| `data/site.yaml` | Site configuration (title, URL, feeds, taxonomies) |
| `data/document.yaml` | Default style and layout for all pages |
| `data/wigstand.yaml` | **Style registry** — the source of truth for which styles are showcased and their metadata (name, description, thumbnail, tags). See this file for the current list of styles |
| `data/demo.yaml` | Shared demo content (post excerpts, placeholder text) |
| `data/colors/` | Colour scheme data shared across styles |

## Styles

See `data/wigstand.yaml` for the current list of showcased styles. Each style owns its own directory under `styles/{name}/` containing:

- `style.yaml` — style manifest (name, imports, tokens, scheme)
- `patterns/` — CUBE CSS pattern files (HTML + YAML front-matter)
- `css/` — pattern CSS (organised by CUBE category)
- `templates/` — page layouts and block templates
- `demo/` — style-specific demo content and pattern library entry points

The `wig-stand` style itself is used for the shell site (homepage, style grid, filters) and is not one of the showcased styles. The `cube` and `highlights` styles provide foundational patterns and colour schemes that other styles import via `imports:` in their `style.yaml`.

## Demo architecture

Each style's demo is a self-contained preview accessible at `/demo/{name}/`:

1. **Entry point:** `pages/demo/{name}/_index.dj` sets `document.style` and `site.path` overrides via the data cascade, so the demo renders with the correct style and relative navigation paths.
2. **Demo content:** Style-owned content lives in `styles/{name}/demo/` — typically pages like `about.dj`, `posts/`, and `patterns/`.
3. **Preview iframe:** The wig-stand shell loads each style's demo in an iframe with viewport controls (Mobile / Tablet / Desktop / Full), allowing authors to see how the style responds at different breakpoints.

## Pattern library

Each style provides a pattern library at `/demo/{name}/patterns/`:

- **Entry point:** `styles/{name}/demo/patterns/_index.dj` uses `paginate.layout` to generate both the shell page (sidebar navigation, viewport controls) and individual per-pattern sub-pages.
- **Shell template:** `cube:layouts/patterns.html` — shared across all styles via template imports. Renders a sidebar grouped by CUBE category with a "Library" overview link at the top.
- **Pattern template:** `cube:layouts/pattern.html` — renders each pattern's metadata, configuration, live example, source view, and variants in an iframe.
- **Library overview:** The body content of `patterns/_index.dj` serves as the default view, providing each style's introduction to its patterns and design language.

## Adding a new style

1. Create `styles/{name}/style.yaml` with the style manifest (name, imports, tokens, scheme).
2. Add patterns under `styles/{name}/patterns/{category}/` (HTML files with YAML front-matter).
3. Add CSS under `styles/{name}/css/{category}/` matching the pattern IDs.
4. Add templates under `styles/{name}/templates/layouts/` (at minimum a page layout).
5. Add demo content under `styles/{name}/demo/` (pages, pattern library `_index.dj`).
6. Add a preview page at `pages/demo/{name}/_index.dj` that sets `document.style` and `site.path`.
7. Register the style in `data/wigstand.yaml` with name, description, and tags.
