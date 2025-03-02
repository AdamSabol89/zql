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
    //line_num: usize,
    //line_index: usize,
};

//thoughts:
// we can do token_vals = [ ], token_types = []
// this mean each  KEYWORD is its own token
//
const TokenTypesList = [_][:0]const u8{ "STAR", "EQUALS", "COMMA", "RIGHT_PAREN", "LEFT_PAREN", "PLUS", "DASH", "F_SLASH", "SEMI_COLON", "BARE_WORD" };

const TokenValList = [_][]const u8{ "*", "=", ",", ")", "(", "+", "-", "/", ";", "BARE_WORD" };

const Keywords = [_]struct { []const u8 }{
    .{"select"},
    .{"from"},
    .{"where"},
    .{"join"},
    .{"inner"},
    .{"outer"},
    .{"left"},
    .{"right"},
    .{"limit"},
};

const ComptimeSet = std.StaticStringMap(void);
pub const KeywordsSet = ComptimeSet.initComptime(Keywords);

const TokenTypes = GenTokenTypes(&TokenTypesList);
pub const SOA_TokenTypes = std.MultiArrayList(TokenTypes);

pub fn GenTokenTypes(comptime token_types: []const [:0]const u8) type {
    comptime var enum_fields: [token_types.len]EnumField = undefined;
    comptime var union_fields: [token_types.len]UnionField = undefined;

    for (token_types, 0..token_types.len) |token, i| {
        enum_fields[i] = EnumField{
            .name = token,
            .value = @intCast(i),
        };
        union_fields[i] = UnionField{
            .name = token,
            .type = TokenInfo,
            .alignment = 0,
        };
    }

    const EnumToken = Type{
        .Enum = .{
            //LIMIT 255 union types
            .tag_type = u8,
            .decls = &[_]Type.Declaration{},
            .fields = &enum_fields,
            .is_exhaustive = true,
        },
    };

    const EnumTokenType = @Type(EnumToken);

    const LTokenTypes = Type{ .Union = .{
        .layout = Type.ContainerLayout.auto,
        .tag_type = EnumTokenType,
        .fields = &union_fields,
        .decls = &[_]Type.Declaration{},
    } };

    return @Type(LTokenTypes);
}

const Scanner = struct {
    text: []const u8,

    soa_token: *SOA_TokenTypes,
    soa_token_index: usize,

    curr_index: usize,
    curr_line: usize,
    bare_word_index: usize,

    reading_bareword: bool,

    const Self = @This();

    pub fn init(soa_token: *SOA_TokenTypes, text: []const u8, allocator: std.mem.Allocator) !Scanner {
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

    inline fn add_token(self: *Self, comptime token_enum_name: []const u8, start_index: usize, end_index: usize, allocator: std.mem.Allocator) !void {
        const parsed_token_payload = .{ .lexeme = self.text[start_index..end_index], .index = self.curr_index };
        const parsed_token = @unionInit(TokenTypes, token_enum_name, parsed_token_payload);

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
        try self.add_token("BARE_WORD", start_index, end_index + 1, allocator);
        self.reading_bareword = false;
    }

    fn try_eat_token(self: *Self, allocator: std.mem.Allocator) !void {
        self.skip_whitespace();

        inline for (TokenValList, 0..) |token_val, i| {
            if (std.mem.startsWith(u8, self.text[self.curr_index..], token_val)) {
                if (self.reading_bareword) {
                    try self.finish_bareword(self.bare_word_index, self.curr_index - 1, allocator);
                }
                try self.add_token(TokenTypesList[i], self.curr_index, self.curr_index + token_val.len, allocator);
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

    var soa_token: SOA_TokenTypes = .{};
    var scanner = try Scanner.init(&soa_token, query, allocator);
    defer scanner.deinit(allocator);

    const start = std.time.nanoTimestamp();
    try scanner.tokenize(allocator);
    const end = std.time.nanoTimestamp();
    std.debug.print("time to tokenize {d}\n", .{end - start});

    defer soa_token.deinit(allocator);

    const t1 = soa_token.get(9);
    switch (t1) {
        .BARE_WORD => |token| {
            std.debug.print("{s}\n", .{token.lexeme});
        },
        .STAR => |token| {
            std.debug.print("{s}\n", .{token.lexeme});
            //assert(std.mem.eql(u8, "*", token.lexeme));
        },
        .COMMA => |token| {
            std.debug.print("FOUDN COMMA: {s}\n", .{token.lexeme});
            //assert(std.mem.eql(u8, "*", token.lexeme));
        },
        .LEFT_PAREN => |token| {
            std.debug.print("{s}\n", .{token.lexeme});
            //assert(std.mem.eql(u8, "*", token.lexeme));
        },
        else => {},
    }
}

pub fn parse_query_syntax(tables_table: tables.TablesTable, tokens: SOA_TokenTypes) void {
    const init_query_token = tokens.get(0);

    switch (init_query_token) {
        .BARE_WORD => {
            _ = parser.parse_select_query(tokens, tables_table);
        },
        else => {},
    }
}

test "create token tagged union" {
    const Token = GenTokenTypes(&TokenTypesList);

    const select_token: Token = Token{ .BARE_WORD = .{
        .lexeme = "",
        .index = 12,
    } };

    std.debug.print("{s}", .{@tagName(select_token)});
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
