const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // highlights-import: converts iTerm2-Color-Schemes Alacritty .toml themes
    // to Highlights flat YAML files at styles/highlights/data/colors/.
    //
    // Usage:
    //   zig build highlights -Dsource=/path/to/iTerm2-Color-Schemes/alacritty
    //
    // The source directory must contain Alacritty .toml theme files.
    // Output goes to styles/highlights/data/colors/ relative to this build root.
    const highlights_import_exe = b.addExecutable(.{
        .name = "highlights-import",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/highlights_import.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(highlights_import_exe);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/highlights_import.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const highlights_step = b.step(
        "highlights",
        "Run highlights-import (-Dsource=…); optional origin via -Domit-highlight-origin / -Dhighlight-origin=",
    );

    // -Dsource=<path>  Path to the Alacritty themes directory.
    // If omitted, `zig build highlights` is a no-op; run the executable directly
    // or pass -Dsource= to activate conversion.
    if (b.option(
        []const u8,
        "source",
        "Path to directory containing Alacritty .toml theme files (from iTerm2-Color-Schemes/alacritty/)",
    )) |source_dir| {
        const output_dir = b.pathFromRoot("styles/highlights/data/colors");
        const run = b.addRunArtifact(highlights_import_exe);
        run.addArg(source_dir);
        run.addArg(output_dir);

        const omit_origin =
            b.option(bool, "omit-highlight-origin", "Omit meta.origin from generated YAML (passes \"-\" to importer)") orelse false;

        const origin_pref: []const u8 = if (omit_origin)
            "-"
        else blk: {
            break :blk b.option(
                []const u8,
                "highlight-origin",
                "Blob URL prefix ending in alacritty/ (default: upstream mbadolato/iTerm2-Color-Schemes/master)",
            ) orelse "https://github.com/mbadolato/iTerm2-Color-Schemes/blob/master/alacritty/";
        };

        run.addArg(origin_pref);
        highlights_step.dependOn(&run.step);
    }
}
