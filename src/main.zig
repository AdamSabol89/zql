const std = @import("std");
const Type = std.builtin.Type;
const StructField = Type.StructField;
const UnionField = Type.UnionField;
const EnumField = Type.EnumField;
const tables = @import("tables.zig");
const parser = @import("parser.zig");
const assert = std.debug.assert;

const TokenInfo = struct {
    lexeme: []const u8,
    index: usize,
};

const Token = struct { type: TokenType, info: TokenInfo };

const SmallTokenValList = [_][]const u8{
    "*",
    "=",
    ",",
    ")",
    "(",
    "+",
    "-",
    "/",
    ";",
};

const SmallTokenTypesList = [_][]const u8{
    "STAR",
    "EQUALS",
    "COMMA",
    "RIGHT_PAREN",
    "LEFT_PAREN",
    "PLUS",
    "DASH",
    "F_SLASH",
    "SEMI_COLON",
};

const TokenType = enum(u8) {
    STAR = 0,
    EQUALS = 1,
    COMMA = 2,
    RIGHT_PAREN = 3,
    LEFT_PAREN = 4,
    PLUS = 5,
    DASH = 6,
    F_SLASH = 7,
    SEMI_COLON = 8,

    //KEYWORDS
    SELECT = 10,
    FROM = 11,
    WHERE = 12,
    JOIN = 13,
    INNER = 14,
    OUTER = 15,
    LEFT = 16,
    RIGHT = 17,
    LIMIT = 18,
    ON = 19,

    IDENTIFIER = 255,
};
//TODO: figure out what THE Fuck to do about this duplication definitely a BIG problem
// defintely some comptime shit we can pull here

const Keywords = [_]struct { []const u8, u8 }{
    .{ "select", 10 },
    .{ "from", 11 },
    .{ "where", 12 },
    .{ "join", 13 },
    .{ "inner", 14 },
    .{ "outer", 15 },
    .{ "left", 16 },
    .{ "right", 17 },
    .{ "limit", 18 },
    .{ "on", 19 },
};

const ComptimeSet = std.StaticStringMap(u8);
pub const KeywordsSet = ComptimeSet.initComptime(Keywords);
pub const SOA_token = std.MultiArrayList(Token);

const Scanner = struct {
    text: []const u8,

    soa_token: *SOA_token,
    soa_token_index: usize,

    curr_index: usize,
    curr_line: usize,

    bare_word_index: usize,
    reading_bareword: bool,

    const Self = @This();

    pub fn init(soa_token: *SOA_token, text: []const u8, allocator: std.mem.Allocator) !Scanner {
        const lower = try std.ascii.allocLowerString(allocator, text);

        return .{
            .text = lower,
            .soa_token = soa_token,
            .soa_token_index = 0,
            .curr_index = 0,
            .curr_line = 0,
            .reading_bareword = false,
            .bare_word_index = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }

    inline fn add_token(self: *Self, enum_val: u8, start_index: usize, end_index: usize, allocator: std.mem.Allocator) !void {
        const token_info = .{ .lexeme = self.text[start_index..end_index], .index = self.curr_index };
        const parsed_token = Token{ .type = @enumFromInt(enum_val), .info = token_info };

        try self.*.soa_token.insert(allocator, self.soa_token_index, parsed_token);

        self.*.soa_token_index += 1;
    }

    fn skip_whitespace(self: *Self) void {
        while (true) : (self.*.curr_index += 1) {
            if (self.curr_index >= self.text.len) {
                return;
            }
            switch (self.text[self.curr_index]) {
                inline ' ', '\n', '\t' => {
                    continue;
                },

                '-' => {
                    if (self.text[self.curr_index + 1] != '-') {
                        return;
                    }

                    while (self.text[self.curr_index] != '\n') {
                        self.*.curr_index += 1;
                        if (self.curr_index >= self.text.len) {
                            return;
                        }
                    }

                    continue;
                },

                else => {
                    return;
                },
            }
        }
    }

    inline fn is_whitespace(self: *Self, index: usize) bool {
        if (self.curr_index >= self.text.len) {
            return true;
        }

        switch (self.text[index]) {
            inline ' ', '\n', '\t' => {
                return true;
            },

            '-' => {
                if (self.text[index] != '-') {
                    return false;
                }
                return true;
            },
            else => {
                return false;
            },
        }
    }

    inline fn finish_bareword(self: *Self, start_index: usize, end_index: usize, allocator: std.mem.Allocator) !void {
        const o_enum_val = KeywordsSet.get(self.text[start_index .. end_index + 1]);
        if (o_enum_val) |enum_val| {
            try self.add_token(enum_val, start_index, end_index + 1, allocator);
        } else {
            try self.add_token(255, start_index, end_index + 1, allocator);
        }
        self.reading_bareword = false;
    }

    fn try_eat_token(self: *Self, allocator: std.mem.Allocator) !void {
        self.skip_whitespace();

        inline for (SmallTokenValList, 0..) |token_val, i| {
            if (std.mem.startsWith(u8, self.text[self.curr_index..], token_val)) {
                if (self.reading_bareword) {
                    try self.finish_bareword(self.bare_word_index, self.curr_index - 1, allocator);
                }
                try self.add_token(i, self.curr_index, self.curr_index + token_val.len, allocator);
                self.curr_index += token_val.len;
                return;
            }
        }

        if (self.is_whitespace(self.curr_index + 1) and self.reading_bareword) {
            try self.finish_bareword(self.bare_word_index, self.curr_index, allocator);
            self.curr_index += 1;
            return;
        }

        if (!self.reading_bareword) {
            self.reading_bareword = true;
            self.bare_word_index = self.curr_index;
        }

        self.curr_index += 1;
        return;
    }

    pub fn tokenize(self: *Self, allocator: std.mem.Allocator) !void {
        while (self.curr_index < self.text.len) {
            try self.try_eat_token(allocator);
        }
    }
};

test "read a token properly" {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const root_allocator = fba.allocator();

    var arena = std.heap.ArenaAllocator.init(root_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var soa_token: SOA_token = .{};
    var scanner = try Scanner.init(&soa_token, query, allocator);
    defer scanner.deinit(allocator);

    const start = std.time.nanoTimestamp();
    try scanner.tokenize(allocator);
    const end = std.time.nanoTimestamp();
    std.debug.print("time to tokenize {d}\n", .{end - start});

    defer soa_token.deinit(allocator);

    const t1 = soa_token.get(0);
    std.debug.print("{s}\n", .{t1.info.lexeme});
    std.debug.print("{d}\n", .{@intFromEnum(t1.type)});
    parser.parse_query(soa_token);
}

pub fn parse_query_syntax(tables_table: tables.TablesTable, tokens: SOA_token) void {
    const init_query_token = tokens.get(0);

    switch (init_query_token) {
        .BARE_WORD => {
            _ = parser.parse_select_query(tokens, tables_table);
        },
        else => {},
    }
}

const query =
    \\SELECT  *
    \\    users.name + users.phone ,  
    \\    FUNCTION(users.name , users.phone) ,
    \\ --THIS IS A COMMENT 
    \\ FROM users
    \\ JOIN content ON users.content_id = content.id
    \\ WHERE users.id = 12
    \\ LIMIT 100 
;

pub fn main() !void {}
