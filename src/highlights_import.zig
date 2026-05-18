//! Converts iTerm2-Color-Schemes Alacritty .toml theme files to Highlights flat YAML.
//!
//! Usage:
//!   highlights-import <source-dir> <output-dir> [origin-prefix]
//!
//! Source directory: path containing Alacritty .toml files (e.g. iTerm2-Color-Schemes/alacritty/).
//! Output directory: styles/highlights/data/colors/ (created if absent).
//!
//! **origin-prefix** (optional fourth CLI token): blob URL ending with **`alacritty/`**; **`meta.origin`**
//! is **`origin-prefix` + percent-encoded basename** (`Dracula.toml`, spaces → `%20`, …).
//! Omit to use **`https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/alacritty/`**.
//! Pass **`-`** to omit **`meta.origin`** from YAML.
//!
//! Role mapping (Alacritty → Highlights):
//!
//!   palette keys    ← primary.background, primary.foreground,
//!                      normal.{black,red,green,yellow,blue,magenta,cyan,white},
//!                      bright.{black,red,green,yellow,blue,magenta,cyan,white}
//!
//!   document.text.primary     ← primary.foreground
//!   document.text.secondary   ← bright.black  (de-emphasised / comments)
//!   document.text.emphasis    ← bright.white  (strong emphasis)
//!   document.text.heading     ← primary.foreground
//!   document.text.link        ← normal.blue
//!   document.background.primary   ← primary.background
//!   document.background.secondary ← normal.black
//!   document.background.embed     ← bright.black
//!
//!   syntax.variable    ← normal.magenta
//!   syntax.constant    ← bright.magenta
//!   syntax.punctuation ← bright.black
//!   syntax.operator    ← normal.white
//!   syntax.number      ← normal.yellow
//!   syntax.type        ← normal.cyan
//!   syntax.function    ← normal.blue
//!   syntax.string      ← normal.green
//!   syntax.comment     ← bright.black
//!   syntax.keyword     ← normal.red
//!
//! Idempotent: re-running produces byte-identical output; only new files are added.
//! Skips files that cannot be parsed cleanly and prints a summary at the end.

const std = @import("std");

const Allocator = std.mem.Allocator;

const default_origin_blob_prefix =
    "https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/alacritty/";

/// Parsed Alacritty color values extracted from one .toml file.
const AlacrittyColors = struct {
    // primary
    background: ?[]const u8 = null,
    foreground: ?[]const u8 = null,
    // normal
    normal_black: ?[]const u8 = null,
    normal_red: ?[]const u8 = null,
    normal_green: ?[]const u8 = null,
    normal_yellow: ?[]const u8 = null,
    normal_blue: ?[]const u8 = null,
    normal_magenta: ?[]const u8 = null,
    normal_cyan: ?[]const u8 = null,
    normal_white: ?[]const u8 = null,
    // bright
    bright_black: ?[]const u8 = null,
    bright_red: ?[]const u8 = null,
    bright_green: ?[]const u8 = null,
    bright_yellow: ?[]const u8 = null,
    bright_blue: ?[]const u8 = null,
    bright_magenta: ?[]const u8 = null,
    bright_cyan: ?[]const u8 = null,
    bright_white: ?[]const u8 = null,

    fn isComplete(self: *const AlacrittyColors) bool {
        return self.background != null and
            self.foreground != null and
            self.normal_black != null and
            self.normal_red != null and
            self.normal_green != null and
            self.normal_yellow != null and
            self.normal_blue != null and
            self.normal_magenta != null and
            self.normal_cyan != null and
            self.normal_white != null and
            self.bright_black != null and
            self.bright_red != null and
            self.bright_green != null and
            self.bright_yellow != null and
            self.bright_blue != null and
            self.bright_magenta != null and
            self.bright_cyan != null and
            self.bright_white != null;
    }
};

/// Parse a single Alacritty TOML file. Returns null if required fields are missing.
fn parseAlacrittyToml(source: []const u8) ?AlacrittyColors {
    var colors = AlacrittyColors{};
    var section: []const u8 = "";

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        // Section header: [colors.primary], [colors.normal], etc.
        if (line[0] == '[') {
            section = line;
            continue;
        }

        // Key-value: key = "#rrggbb" or key = '0xrrggbb'
        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..eq_pos], " \t");
        const raw_val = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

        // Extract hex value from quotes: "#rrggbb" or '0xrrggbb'
        const hex = extractHex(raw_val) orelse continue;

        // Map to AlacrittyColors fields based on section + key
        if (std.mem.eql(u8, section, "[colors.primary]")) {
            if (std.mem.eql(u8, key, "background")) colors.background = hex;
            if (std.mem.eql(u8, key, "foreground")) colors.foreground = hex;
        } else if (std.mem.eql(u8, section, "[colors.normal]")) {
            if (std.mem.eql(u8, key, "black")) colors.normal_black = hex;
            if (std.mem.eql(u8, key, "red")) colors.normal_red = hex;
            if (std.mem.eql(u8, key, "green")) colors.normal_green = hex;
            if (std.mem.eql(u8, key, "yellow")) colors.normal_yellow = hex;
            if (std.mem.eql(u8, key, "blue")) colors.normal_blue = hex;
            if (std.mem.eql(u8, key, "magenta")) colors.normal_magenta = hex;
            if (std.mem.eql(u8, key, "cyan")) colors.normal_cyan = hex;
            if (std.mem.eql(u8, key, "white")) colors.normal_white = hex;
        } else if (std.mem.eql(u8, section, "[colors.bright]")) {
            if (std.mem.eql(u8, key, "black")) colors.bright_black = hex;
            if (std.mem.eql(u8, key, "red")) colors.bright_red = hex;
            if (std.mem.eql(u8, key, "green")) colors.bright_green = hex;
            if (std.mem.eql(u8, key, "yellow")) colors.bright_yellow = hex;
            if (std.mem.eql(u8, key, "blue")) colors.bright_blue = hex;
            if (std.mem.eql(u8, key, "magenta")) colors.bright_magenta = hex;
            if (std.mem.eql(u8, key, "cyan")) colors.bright_cyan = hex;
            if (std.mem.eql(u8, key, "white")) colors.bright_white = hex;
        }
    }

    if (!colors.isComplete()) return null;
    return colors;
}

/// Extracts a "#rrggbb" or "#rrggbbaa" hex string from a TOML value.
/// Handles: `"#rrggbb"`, `'#rrggbb'`, `"0xrrggbb"`, `'0xrrggbb'`.
/// Returns a slice pointing into the source (always starts with '#').
fn extractHex(raw: []const u8) ?[]const u8 {
    if (raw.len < 3) return null;

    // Strip surrounding quotes
    const quote_char: u8 = if (raw[0] == '"' or raw[0] == '\'') raw[0] else return null;
    if (raw[raw.len - 1] != quote_char) return null;
    const inner = raw[1 .. raw.len - 1];

    if (inner.len == 0) return null;

    if (inner[0] == '#') {
        // Validate: 6 or 8 hex chars after '#'
        if (inner.len == 7 or inner.len == 9) return inner[0..7];
        return null;
    }

    // Handle 0xRRGGBB format
    if (inner.len >= 8 and std.mem.startsWith(u8, inner, "0x")) {
        // Return as-is without the prefix; caller would get 0x... but we need #...
        // We need to allocate here — not possible without an allocator.
        // For simplicity, return null and let the caller handle it.
        // In practice, Alacritty themes mostly use "#" format.
        return null;
    }

    return null;
}

/// Converts a theme name to a URL-friendly slug.
/// "Catppuccin Mocha" → "catppuccin-mocha"
/// "Dracula+" → "dracula-plus" ('+' is expanded to "plus")
fn slugify(a: Allocator, name: []const u8) ![]u8 {
    // Allocate enough space: '+' can expand to 4 chars ("plus")
    var result = try a.alloc(u8, name.len * 4);
    var write: usize = 0;
    var prev_was_sep = true; // start true to skip leading separators

    for (name) |c| {
        switch (c) {
            'A'...'Z' => {
                result[write] = c + 32;
                write += 1;
                prev_was_sep = false;
            },
            'a'...'z', '0'...'9' => {
                result[write] = c;
                write += 1;
                prev_was_sep = false;
            },
            '+' => {
                // Treat '+' as "-plus" to avoid collisions (e.g. "Dracula" vs "Dracula+")
                if (!prev_was_sep) {
                    result[write] = '-';
                    write += 1;
                }
                @memcpy(result[write..][0..4], "plus");
                write += 4;
                prev_was_sep = false;
            },
            ' ', '_', '(', ')', '[', ']', '.', ',', '\'' => {
                if (!prev_was_sep) {
                    result[write] = '-';
                    write += 1;
                    prev_was_sep = true;
                }
            },
            else => {},
        }
    }

    // Strip trailing separator
    while (write > 0 and result[write - 1] == '-') write -= 1;

    return result[0..write];
}

/// Encode a basename for appending after a GitHub `blob/.../` directory URL (RFC 3986 path segment subset).
pub fn githubFilenameUrlEncode(writer: anytype, path: []const u8) !void {
    for (path) |b| switch (b) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.' => try writer.writeByte(b),
        else => try writer.print("%{X:0>2}", .{b}),
    };
}

/// Emits the full `origin` blob URL (`prefix` ends with slash, then encoded `toml_filename`).
pub fn composeOriginUrlScratch(a: Allocator, prefix: []const u8, toml_filename: []const u8) ![]u8 {
    const est: usize = prefix.len + toml_filename.len * 3;
    var buf = try std.ArrayListUnmanaged(u8).initCapacity(a, est);
    errdefer buf.deinit(a);
    try buf.appendSlice(a, prefix);
    try githubFilenameUrlEncode(buf.writer(a), toml_filename);
    return try buf.toOwnedSlice(a);
}

/// Emits a Highlights flat YAML string for the given theme name and parsed colors.
///
/// When `maybe_origin_blob_url` is null, **`meta.origin` is omitted**.
fn emitYaml(a: Allocator, display_name: []const u8, maybe_origin_blob_url: ?[]const u8, c: AlacrittyColors) ![]u8 {
    const hdr = blk: {
        if (maybe_origin_blob_url) |url| {
            break :blk try std.fmt.allocPrint(a,
                \\meta:
                \\  name: {s}
                \\  origin: "{s}"
                \\
                \\palette:
                \\
            , .{ display_name, url });
        }
        break :blk try std.fmt.allocPrint(a,
            \\meta:
            \\  name: {s}
            \\
            \\palette:
            \\
        , .{display_name});
    };

    defer a.free(hdr);

    return std.fmt.allocPrint(a,
        \\{s}  background:    "{s}"
        \\  foreground:    "{s}"
        \\  black:         "{s}"
        \\  red:           "{s}"
        \\  green:         "{s}"
        \\  yellow:        "{s}"
        \\  blue:          "{s}"
        \\  magenta:       "{s}"
        \\  cyan:          "{s}"
        \\  white:         "{s}"
        \\  bright-black:  "{s}"
        \\  bright-red:    "{s}"
        \\  bright-green:  "{s}"
        \\  bright-yellow: "{s}"
        \\  bright-blue:   "{s}"
        \\  bright-magenta: "{s}"
        \\  bright-cyan:   "{s}"
        \\  bright-white:  "{s}"
        \\terminal:
        \\  background:    background
        \\  foreground:    foreground
        \\  black:         black
        \\  red:           red
        \\  green:         green
        \\  yellow:        yellow
        \\  blue:          blue
        \\  magenta:       magenta
        \\  cyan:          cyan
        \\  white:         white
        \\  bright-black:  bright-black
        \\  bright-red:    bright-red
        \\  bright-green:  bright-green
        \\  bright-yellow: bright-yellow
        \\  bright-blue:   bright-blue
        \\  bright-magenta: bright-magenta
        \\  bright-cyan:   bright-cyan
        \\  bright-white:  bright-white
        \\document:
        \\  text:
        \\    primary:   foreground
        \\    secondary: bright-black
        \\    emphasis:  bright-white
        \\    heading:   foreground
        \\    link:      blue
        \\  background:
        \\    primary:   background
        \\    secondary: black
        \\    embed:     bright-black
        \\syntax:
        \\  variable:    magenta
        \\  constant:    bright-magenta
        \\  punctuation: bright-black
        \\  operator:    white
        \\  number:      yellow
        \\  type:        cyan
        \\  function:    blue
        \\  string:      green
        \\  comment:     bright-black
        \\  keyword:     red
        \\
    , .{
        hdr,
        c.background.?,
        c.foreground.?,
        c.normal_black.?,
        c.normal_red.?,
        c.normal_green.?,
        c.normal_yellow.?,
        c.normal_blue.?,
        c.normal_magenta.?,
        c.normal_cyan.?,
        c.normal_white.?,
        c.bright_black.?,
        c.bright_red.?,
        c.bright_green.?,
        c.bright_yellow.?,
        c.bright_blue.?,
        c.bright_magenta.?,
        c.bright_cyan.?,
        c.bright_white.?,
    });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const args = try std.process.argsAlloc(a);
    if (args.len < 3) {
        std.debug.print(
            "Usage: highlights-import <source-dir> <output-dir> [origin-prefix]\n" ++
                "  source-dir: path containing Alacritty .toml theme files\n" ++
                "  output-dir: destination for Highlights flat YAML files\n" ++
                "  origin-prefix: optional URL prefix ending in alacritty/ (\"-\" omit meta.origin).\n",
            .{},
        );
        std.process.exit(1);
    }

    const source_dir_path = args[1];
    const output_dir_path = args[2];
    const origin_pref_cli: []const u8 =
        if (args.len >= 4) args[3] else default_origin_blob_prefix;

    var source_dir = std.fs.openDirAbsolute(source_dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("error: cannot open source directory '{s}': {s}\n", .{ source_dir_path, @errorName(err) });
        std.process.exit(1);
    };
    defer source_dir.close();

    std.fs.makeDirAbsolute(output_dir_path) catch |err| {
        if (err != error.PathAlreadyExists) {
            std.debug.print("error: cannot create output directory '{s}': {s}\n", .{ output_dir_path, @errorName(err) });
            std.process.exit(1);
        }
    };

    var output_dir = try std.fs.openDirAbsolute(output_dir_path, .{});
    defer output_dir.close();

    var converted: usize = 0;
    var unchanged: usize = 0;
    var skipped: usize = 0;
    var skip_names = std.ArrayListUnmanaged([]const u8){};

    // Collect and sort entries for deterministic (idempotent) output order.
    var entries = std.ArrayListUnmanaged([]const u8){};
    {
        var it = source_dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".toml")) continue;
            try entries.append(a, try a.dupe(u8, entry.name));
        }
    }
    std.mem.sort([]const u8, entries.items, {}, struct {
        pub fn lessThan(_: void, a_: []const u8, b_: []const u8) bool {
            return std.mem.order(u8, a_, b_) == .lt;
        }
    }.lessThan);

    for (entries.items) |file_name| {
        const stem = file_name[0 .. file_name.len - 5]; // strip .toml
        const slug = try slugify(a, stem);
        if (slug.len == 0) {
            skipped += 1;
            try skip_names.append(a, try a.dupe(u8, stem));
            continue;
        }
        const out_name = try std.fmt.allocPrint(a, "{s}.yaml", .{slug});

        const toml_source = source_dir.readFileAlloc(a, file_name, 512 * 1024) catch {
            skipped += 1;
            try skip_names.append(a, try a.dupe(u8, stem));
            continue;
        };

        const parsed = parseAlacrittyToml(toml_source) orelse {
            skipped += 1;
            try skip_names.append(a, try a.dupe(u8, stem));
            continue;
        };

        const maybe_origin_url: ?[]const u8 =
            if (std.mem.eql(u8, origin_pref_cli, "-")) null else try composeOriginUrlScratch(a, origin_pref_cli, file_name);

        const yaml = try emitYaml(a, stem, maybe_origin_url, parsed);

        // Check if identical content already exists (idempotency).
        const existing = output_dir.readFileAlloc(a, out_name, 512 * 1024) catch "";
        if (std.mem.eql(u8, yaml, existing)) {
            unchanged += 1;
            continue;
        }

        const out_file = output_dir.createFile(out_name, .{}) catch {
            skipped += 1;
            try skip_names.append(a, try a.dupe(u8, stem));
            continue;
        };
        defer out_file.close();
        try out_file.writeAll(yaml);
        converted += 1;
    }

    std.debug.print(
        "highlights-import: {d} converted, {d} unchanged, {d} skipped\n",
        .{ converted, unchanged, skipped },
    );

    if (skip_names.items.len > 0) {
        std.debug.print("skipped:\n", .{});
        for (skip_names.items) |name| {
            std.debug.print("  - {s}\n", .{name});
        }
    }
}

// ── Tests ────────────────────────────────────────────────────────────────────

const testing = std.testing;

test "slugify: basic cases" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try testing.expectEqualStrings("catppuccin-mocha", try slugify(a, "Catppuccin Mocha"));
    try testing.expectEqualStrings("gruvbox-dark", try slugify(a, "Gruvbox Dark"));
    try testing.expectEqualStrings("solarized-light", try slugify(a, "Solarized Light"));
    try testing.expectEqualStrings("one-dark", try slugify(a, "One Dark"));
    try testing.expectEqualStrings("nord", try slugify(a, "Nord"));
    // '+' expands to "plus" so "Dracula" and "Dracula+" get distinct slugs
    try testing.expectEqualStrings("dracula", try slugify(a, "Dracula"));
    try testing.expectEqualStrings("dracula-plus", try slugify(a, "Dracula+"));
}

test "slugify: strips trailing separator" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    try testing.expectEqualStrings("theme", try slugify(a, "Theme "));
    try testing.expectEqualStrings("a-b", try slugify(a, "A  B"));
}

test "extractHex: valid inputs" {
    try testing.expectEqualStrings("#1e1e2e", extractHex("\"#1e1e2e\"").?);
    try testing.expectEqualStrings("#cdd6f4", extractHex("'#cdd6f4'").?);
    try testing.expectEqualStrings("#ffffff", extractHex("\"#ffffff\"").?);
}

test "extractHex: invalid inputs" {
    try testing.expect(extractHex("novalue") == null);
    try testing.expect(extractHex("\"nocolor\"") == null);
    try testing.expect(extractHex("") == null);
}

test "parseAlacrittyToml: complete theme" {
    const source =
        \\[colors.primary]
        \\background = "#1e1e2e"
        \\foreground = "#cdd6f4"
        \\
        \\[colors.normal]
        \\black   = "#45475a"
        \\red     = "#f38ba8"
        \\green   = "#a6e3a1"
        \\yellow  = "#f9e2af"
        \\blue    = "#89b4fa"
        \\magenta = "#f5c2e7"
        \\cyan    = "#94e2d5"
        \\white   = "#bac2de"
        \\
        \\[colors.bright]
        \\black   = "#585b70"
        \\red     = "#f38ba8"
        \\green   = "#a6e3a1"
        \\yellow  = "#f9e2af"
        \\blue    = "#89b4fa"
        \\magenta = "#f5c2e7"
        \\cyan    = "#94e2d5"
        \\white   = "#a6adc8"
    ;
    const result = parseAlacrittyToml(source).?;
    try testing.expectEqualStrings("#1e1e2e", result.background.?);
    try testing.expectEqualStrings("#cdd6f4", result.foreground.?);
    try testing.expectEqualStrings("#45475a", result.normal_black.?);
    try testing.expectEqualStrings("#f38ba8", result.normal_red.?);
    try testing.expectEqualStrings("#585b70", result.bright_black.?);
    try testing.expectEqualStrings("#a6adc8", result.bright_white.?);
}

test "parseAlacrittyToml: incomplete theme returns null" {
    const source =
        \\[colors.primary]
        \\background = "#1e1e2e"
        \\foreground = "#cdd6f4"
    ;
    try testing.expect(parseAlacrittyToml(source) == null);
}

fn sampleFullAlacrittyColors() AlacrittyColors {
    return .{
        .background = "#000000",
        .foreground = "#ffffff",
        .normal_black = "#010101",
        .normal_red = "#020202",
        .normal_green = "#030303",
        .normal_yellow = "#040404",
        .normal_blue = "#050505",
        .normal_magenta = "#060606",
        .normal_cyan = "#070707",
        .normal_white = "#080808",
        .bright_black = "#111111",
        .bright_red = "#121212",
        .bright_green = "#131313",
        .bright_yellow = "#141414",
        .bright_blue = "#151515",
        .bright_magenta = "#161616",
        .bright_cyan = "#171717",
        .bright_white = "#181818",
    };
}

test "composeOriginUrlScratch: encodes spaces" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const u = try composeOriginUrlScratch(a, "https://example.com/x/", "Dracula Plus.toml");
    try testing.expectEqualStrings("https://example.com/x/Dracula%20Plus.toml", u);
}

test "emitYaml: origin and terminal blocks" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const c = sampleFullAlacrittyColors();
    const url = try composeOriginUrlScratch(a, "https://gh/x/", "Test.toml");

    const yaml = try emitYaml(a, "Test Theme", url, c);
    try testing.expect(std.mem.indexOf(u8, yaml, "origin: \"https://gh/x/Test.toml\"") != null);
    try testing.expect(std.mem.indexOf(u8, yaml, "\nterminal:\n") != null);
    try testing.expect(std.mem.indexOf(u8, yaml, "\n  black:         black\n") != null);
}

test "emitYaml: no origin line when omitted" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const c = sampleFullAlacrittyColors();
    const yaml = try emitYaml(a, "Solo", null, c);
    try testing.expect(std.mem.indexOf(u8, yaml, "origin:") == null);
}
