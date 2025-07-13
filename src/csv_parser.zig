//Serializes a CSV into a series of in memory vectorized buffers

const std = @import("std");
const types = @import("types.zig");
const assert = std.debug.assert;
const PrimitiveType = types.PrimitiveType;

pub const Quoting = enum {
    QUOTE_ALL,
    QUOTE_NONE,
    QUOTE_NONNUMERIC,
    INFER_QUOTING,
};

pub const CSVReaderOptions = struct {
    file_path: []const u8,
    sep: u8,
    header: ?[]const []const u8 = null,
    dtypes: ?[]?PrimitiveType = null,
    skip_blank_lines: bool = true,
    quoting: Quoting = .INFER_QUOTING,
    new_line: u8 
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

const HeaderInternal = struct{ 
    payload: [*]u8,
    offsets: []u32,
    const Self = @This();

    fn get_column_name(self: *Self, index: usize) []const u8 { 
        // Last offset is the end of the whole payload
        assert(index < self.offsets.len - 1); 
        const start = self.offsets[index];
        const end = self.offsets[index + 1]; 

        return self.payload[start..end]; 
    }
    

    fn parse_header_from_buffer(self: *Self, options: *CSVReaderOptions, buffer: []const u8 ) void {
    }

};

pub const CSVReader = struct {
    options: CSVReaderOptions,
    file_size: u64,
    fd: std.fs.File,
    text_buffers: std.ArrayList([]u8),

    const Self = @This();

    pub fn csv_to_buffers(self: *Self) ![]Buffer {
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

    fn parse_header(self: *Self) void { 

    }

    fn parse_buffer(self: *Self, buffer_index: usize) void {
        assert(buffer_index < self.text_buffers.len);
        const buffer = self.text_buffers[buffer_index];

        var parser: ParserState = .{};

        while ((parser.index) < buffer.len) : (parser.index += 1) {

        }
    }

};

const CSVParserMetadata = struct { 

};


const ParseFrame = struct { 
    const u8_64width_vec = @Vector(64, u8);

    inline fn fast_offset(some_bool: bool) isize { 
        @setRuntimeSafety(false);
        const x: isize = @intFromBool(some_bool);
        return 1 - (x << 1);
    }

    fn parse_chunk_frame(chunk: []const u8, parse_options: *CSVReaderOptions, parse_metadata: *CSVParserMetadata,) ParseFrame { 
        @setRuntimeSafety(false);
        // We assume chunk is passed on start of field[0]
        //while(std.ascii.isWhiteSpace(chunk[parse_state.index])) : (parse_state.index += 1) { }
        var stack: []usize = undefined;

        const all_quotes = [_]u8{'"'} ** 64;
        var parse_state: ParserState = .{};

        const quotes_vec: u8_64width_vec = all_quotes;
        const chunk_vec: u8_64width_vec = chunk[parse_state.index..][0..64].*;

        var bitmask: u64 = @bitCast(chunk_vec == quotes_vec);
        const next_quote: u64 = @ctz(bitmask);

        //REMINDER: must compute proper offset

        // branch prediction is prob hard here 
        while (true) { 

            // could we use lt gt? 
            const previous_quote = stack.pop();

            // branch prediction is prob hard here 
            if (!(next_quote - previous_quote == 0 )) {
                try stack.push_unchecked(previous_quote);
                try stack.push(next_quote);

            } 

            const shft: u6 = @truncate(next_quote + 1);
            bitmask <<= shft;

        }
    }
    //const index_offset = ParseFrame.fast_offset(previous_quote.quoute_index == next_quote);
    //const return_index = previous_quote.index += index_offset;
};


// if -> isDigit parse as usize32
// if -> isDigit w/ dash parse as int32
// if -> isDigit w/ . parse as f32 
// if -> parse as bool (string true/false)
// if -> parse as bytes
fn infer_datatypes(first_row: []const u8) []types.PrimitiveType { 
    std.ascii.isDigit();

}
