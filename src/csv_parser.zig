//Serializes a CSV into a series of in memory vectorized buffers

const std = @import("std");
const types = @import("types.zig");
const assert = std.debug.assert;
const PrimitiveType = types.PrimitiveType;

pub const Quoting = enum {
    QUOTE_ALL,
    QUOTE_NONE,
    QUOTE_NONNUMERIC,
};

pub const CSVReaderOptions = struct {
    file_path: []const u8,
    sep: []const u8,
    header: ?[]const []const u8 = null,
    dtypes: ?[]?PrimitiveType = null,
    skip_blank_lines: bool = true,
    quoting: Quoting = .QUOTE_NONNUMERIC,
    //encoding: Encoding
    //encoding_errors: EncodingErrors,

    //nrows: ?usize
};

pub const Buffer = struct {};

const ParserState = struct {
    line: usize = 0,
    index: usize = 0,
    escaped: bool = false,
};

pub const CSVReader = struct {
    options: CSVReaderOptions,
    file_size: u64,
    fd: std.fs.File,
    text_buffers: std.ArrayList([]u8),

    const Self = @This();

    pub fn read_csv(self: *Self) ![]Buffer {
        const fd = try std.fs.openFileAbsolute(self.options.file_path, .{
            .mode = .read_only,
        });
        self.file_size = (try fd.stat()).size;
        self.fd = fd;
    }

    fn parse_whole_file(self: *Self) !void {
        const buffer = std.heap.page_allocator.alloc(u8, self.file_size);
        try self.fd.read(buffer, self.file_size);
        try self.text_buffers.append(buffer);
    }

    fn parse_buffer(self: *Self) void {
        const buffer = self.text_buffers.popOrNull().?;

        var parser: ParserState = .{};

        while ((parser.index) < buffer.len) : (parser.index += 1) {}
    }
};
