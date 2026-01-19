const std = @import("std");
const app = @import("app.zig");

const GitHubRelease = struct {
    tag_name: []const u8,
    name: []const u8,
    assets: []Asset,
    const Asset = struct {
        name: []const u8,
        browser_download_url: []const u8,
    };
};

pub fn downloadFile(allocator: std.mem.Allocator, url: []const u8, output_path: []const u8) !void {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);

    var redirect_buffer: [8 * 1024]u8 = undefined;

    // Create output file
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();

    var file_writer_buffer: [8 * 1024]u8 = undefined;
    var file_writer = file.writer(&file_writer_buffer);

    std.debug.print("Downloading {s}...\n", .{url});

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .redirect_buffer = &redirect_buffer,
        .response_writer = &file_writer.interface,
        .headers = .{
            .user_agent = .{ .override = "zig-download-example" },
        },
    });

    try file_writer.interface.flush();

    if (result.status != .ok) {
        std.debug.print("Download failed with status: {}\n", .{result.status});
        return error.HttpError;
    }

    std.debug.print("Download complete: {s}\n", .{output_path});
}

pub fn extractTarGz(allocator: std.mem.Allocator, archive_path: []const u8, output_dir: []const u8) !void {
    std.debug.print("Extracting tar.gz: {s} to {s}\n", .{ archive_path, output_dir });

    // Read the compressed file
    const file = try std.fs.cwd().openFile(archive_path, .{});
    defer file.close();

    // Create output directory
    try std.fs.cwd().makePath(output_dir);

    // Decompress gzip
    var gzip_stream = try std.compress.gzip.decompressor(file.reader());

    // Read tar archive
    var tar = std.tar.Iterator(.{ .strip_components = 0 }).init(gzip_stream.reader());

    // Extract all files
    while (try tar.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &.{ output_dir, entry.name });
        defer allocator.free(full_path);

        switch (entry.kind) {
            .directory => {
                std.debug.print("Creating directory: {s}\n", .{full_path});
                try std.fs.cwd().makePath(full_path);
            },
            .file => {
                std.debug.print("Extracting file: {s}\n", .{full_path});

                // Ensure parent directory exists
                if (std.fs.path.dirname(full_path)) |parent| {
                    try std.fs.cwd().makePath(parent);
                }

                // Create and write file
                const out_file = try std.fs.cwd().createFile(full_path, .{});
                defer out_file.close();

                var buffer: [4096]u8 = undefined;
                var reader = entry.reader();
                while (true) {
                    const n = try reader.read(&buffer);
                    if (n == 0) break;
                    try out_file.writeAll(buffer[0..n]);
                }
            },
            else => {
                std.debug.print("Skipping entry: {s} (type: {})\n", .{ entry.name, entry.kind });
            },
        }
    }

    std.debug.print("Extraction complete!\n", .{});
}

pub fn extractZip(allocator: std.mem.Allocator, archive_path: []const u8, output_dir: []const u8) !void {
    std.debug.print("Extracting zip: {s} to {s}\n", .{ archive_path, output_dir });

    // Open the zip file
    const file = try std.fs.cwd().openFile(archive_path, .{});
    defer file.close();

    // Create output directory
    try std.fs.cwd().makePath(output_dir);

    // Read entire file into memory for zip processing
    const file_size = (try file.stat()).size;
    const file_data = try allocator.alloc(u8, file_size);
    defer allocator.free(file_data);
    _ = try file.readAll(file_data);

    // Create zip iterator
    var zip = std.zip.Iterator.init(file_data);

    // Extract all files
    while (try zip.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &.{ output_dir, entry.name });
        defer allocator.free(full_path);

        // Check if it's a directory (ends with /)
        if (std.mem.endsWith(u8, entry.name, "/")) {
            std.debug.print("Creating directory: {s}\n", .{full_path});
            try std.fs.cwd().makePath(full_path);
        } else {
            std.debug.print("Extracting file: {s}\n", .{full_path});

            // Ensure parent directory exists
            if (std.fs.path.dirname(full_path)) |parent| {
                try std.fs.cwd().makePath(parent);
            }

            // Decompress and write file
            const decompressed = try entry.decompress(allocator);
            defer allocator.free(decompressed);

            const out_file = try std.fs.cwd().createFile(full_path, .{});
            defer out_file.close();
            try out_file.writeAll(decompressed);
        }
    }

    std.debug.print("Extraction complete!\n", .{});
}

pub fn main() !void {
    // ANSI Escape Codes for Green
    const green = "\x1b[32m";
    const reset = "\x1b[0m";

    // Using std.log (standard logging)
    std.log.info("{s} {s} {s} v{s}{s} {s}starting...", .{
        green, app.name,    reset,
        green, app.version, reset,
    });
    defer std.log.info("{s} BoxWallet {s} v{s}0.01 {s}finished!", .{
        green, reset,
        green, reset,
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    // const uri = try std.Uri.parse("https://api.github.com/repos/ziglang/zig/releases/latest");
    const uri = try std.Uri.parse("https://api.github.com/repos/richardltc/boxwallet2/releases/latest");

    // var writer_buffer: [8 * 1024]u8 = undefined;
    var redirect_buffer: [8 * 1024]u8 = undefined;

    // Create a writer to collect the response
    var body_writer: std.Io.Writer.Allocating = .init(allocator);
    defer body_writer.deinit();

    const result = try client.fetch(.{
        .location = .{ .uri = uri },
        .method = .GET,
        .redirect_buffer = &redirect_buffer,
        .response_writer = &body_writer.writer,
        .headers = .{
            .user_agent = .{ .override = "zig-fetch-example" },
        },
    });

    if (result.status != .ok) return error.HttpError;

    const response_body = body_writer.written();

    const parsed = try std.json.parseFromSlice(
        GitHubRelease,
        allocator,
        response_body,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    std.debug.print("Latest Release: {s}\n", .{parsed.value.tag_name});
    for (parsed.value.assets) |asset| {
        const tar_url = asset.browser_download_url;
        const tar_output = try std.mem.concat(allocator, u8, &[_][]const u8{ "./", asset.name });
        defer allocator.free(tar_output);
        // const tar_extract_dir = "./";
        std.debug.print("- Asset: {s} URL: {s}\n", .{ asset.name, tar_url });
        try downloadFile(allocator, tar_url, tar_output);
    }

    // Example 1: Download a tar.gz file
    // const tar_url = "https://example.com/file.tar.gz";
    // const tar_output = "downloaded.tar.gz";
    // const tar_extract_dir = "extracted_tar";

    // Uncomment to download and extract tar.gz
    // try downloadFile(allocator, tar_url, tar_output);
    // try extractTarGz(allocator, tar_output, tar_extract_dir);

    // Example 2: Download a zip file
    // const zip_url = "https://example.com/file.zip";
    // const zip_output = "downloaded.zip";
    // const zip_extract_dir = "extracted_zip";

    // Uncomment to download and extract zip
    // try downloadFile(allocator, zip_url, zip_output);
    // try extractZip(allocator, zip_output, zip_extract_dir);
}
