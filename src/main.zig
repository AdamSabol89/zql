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

const Keywords = [_][]const u8{
    "SELECT",
    "FROM",
    "WHERE",
    "JOIN",
    "INNER",
    "OUTER",
    "LEFT",
    "RIGHT",
    "LIMIT",
};

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

//inline fn finish_bareword(previous_index: *usize, current_index: *usize, token_index: *usize, SOA_token: *SOA_TokenTypes, allocator: std.mem.Allocator) !void {
//    const lexeme = query[previous_index.*..current_index.*];
//
//    const parsed_token = TokenTypes{ .BARE_WORD = .{
//        .lexeme = lexeme,
//        .index = previous_index.*,
//    } };
//    std.debug.print("Bare word: {s}, at: {d} \n", .{ lexeme, previous_index.* });
//
//    try SOA_token.*.insert(allocator, token_index.*, parsed_token);
//    token_index.* += 1;
//    previous_index.* = 0;
//}

pub inline fn handle_bareword(token_index: usize, bare_word_index: usize, i: usize, SOA_token: *SOA_TokenTypes, allocator: std.mem.Allocator) !usize {
    if (bare_word_index == 0) {
        return 0;
    }

    const bare_word = query[bare_word_index..i];
    std.debug.print("FOUND BAREWORD {s}\n", .{bare_word});
    const parsed_token = .{ .BARE_WORD = .{ .lexeme = bare_word, .index = i } };
    try SOA_token.*.insert(allocator, token_index, parsed_token);

    return 1;
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

    pub fn init(soa_token: *SOA_TokenTypes, text: []const u8) Scanner {
        return .{
            .text = text,
            .soa_token = soa_token,
            .soa_token_index = 0,
            .curr_index = 0,
            .curr_line = 0,
            .reading_bareword = false,
            .bare_word_index = 0,
        };
    }

    pub fn add_token(self: *Self, comptime token_enum_name: []const u8, start_index: usize, end_index: usize, allocator: std.mem.Allocator) !void {
        const parsed_token_payload = .{ .lexeme = self.text[start_index..end_index], .index = self.curr_index };
        const parsed_token = @unionInit(TokenTypes, token_enum_name, parsed_token_payload);

        try self.*.soa_token.insert(allocator, self.soa_token_index, parsed_token);

        self.*.soa_token_index += 1;
    }

    pub fn skip_whitespace(self: *Self) void {
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

    pub fn is_whitespace(self: *Self, index: usize) bool {
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

    pub fn finish_bareword(self: *Self, start_index: usize, end_index: usize, allocator: std.mem.Allocator) !void {
        try self.add_token("BARE_WORD", start_index, end_index, allocator);
        std.debug.print("{s}\n", .{self.text[start_index .. end_index + 1]});
        self.reading_bareword = false;
    }
    //    users.name + users.phone ,
    //    FUNCTION(users.name , users.phone) ,
    // --THIS IS A COMMENT
    // FROM users
    // JOIN content ON users.content_id = content.id
    // WHERE users.id = 12
    // LIMIT 100

    pub fn try_eat_token(self: *Self, allocator: std.mem.Allocator) !void {
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

        // need to figure out how to have this work properly
        if (self.is_whitespace(self.curr_index + 1) and self.reading_bareword) {
            if (self.curr_index == 13) {
                std.debug.print("at thirteen: barewordindex: {d} currindex: {d}\n", .{ self.bare_word_index, self.curr_index });
            }
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
        //
    }

    pub fn tokenize(self: *Self, allocator: std.mem.Allocator) !void {
        while (self.curr_index < self.text.len) {
            try self.try_eat_token(allocator);
        }

        if (self.reading_bareword) {
            std.debug.print("CURRENT INDEX {d}\n", .{self.curr_index});
        }
    }
};

test "read a token properly" {
    const allocator = std.testing.allocator;

    var soa_token: SOA_TokenTypes = .{};
    var scanner = Scanner.init(&soa_token, query);

    try scanner.tokenize(allocator);
    defer soa_token.deinit(allocator);
}

//pub fn tokenize_query(allocator: std.mem.Allocator) !SOA_TokenTypes {
//    var soa_token: SOA_Tokenypes = .{};
//
//    var scanner = Scanner.init(soa_token, query);
//
//    scanner.skip_whitespace();
//
//    while (true){
//    }
//
//    return soa_token;
//}

pub fn parse_query_syntax(tables_table: tables.TablesTable, tokens: SOA_TokenTypes) void {
    const init_query_token = tokens.get(0);

    switch (init_query_token) {
        .BARE_WORD => {
            _ = parser.parse_select_query(tokens, tables_table);
        },
        else => {},
    }
}

//test "parse query" {
//    const allocator = std.testing.allocator;
//
//    var tokens = try tokenize_query(allocator);
//    defer tokens.deinit(allocator);
//
//    const token_1 = tokens.pop();
//
//    switch (token_1) {
//        .BARE_WORD => |token| {
//            std.debug.print("FOUND TOKEN {s}\n", .{token.lexeme});
//        },
//
//        else => {
//            std.debug.print("BUGGED \n", .{});
//        },
//    }
//    //var tables_table = try tables.initTestTables(allocator);
//    //defer tables.deinitTablesTable(&tables_table, allocator);
//
//    //parse_query_syntax(tables_table, tokens);
//}
//
//
//test "tokenize query" {
//    const allocator = std.testing.allocator;
//
//    var tokens = try tokenize_query(allocator);
//    defer tokens.deinit(allocator);
//
//    const ident_token = tokens.get(1);
//
//    switch (ident_token) {
//        .BARE_WORD => |token| {
//            try std.testing.expect(std.mem.eql(u8, token.lexeme, "users.name"));
//        },
//
//        else => {
//            std.debug.print("FUCK", .{});
//        },
//    }
//}
//
test "create token tagged union" {
    const Token = GenTokenTypes(&TokenTypesList);

    const select_token: Token = Token{ .BARE_WORD = .{
        .lexeme = "",
        .index = 12,
    } };

    std.debug.print("{s}", .{@tagName(select_token)});
}

const query =
    //\\SELECT  *
    \\    users.name + users.phone ,  
    \\    FUNCTION(users.name , users.phone) ,
    \\ --THIS IS A COMMENT 
    \\ FROM users
    \\ JOIN content ON users.content_id = content.id
    \\ WHERE users.id = 12
    \\ LIMIT 100 
;

//test "skip_whitespace" {
//    const text = "hello";
//    var soa_token: SOA_TokenTypes = .{};
//    var scanner = Scanner.init(&soa_token, text);
//
//    scanner.curr_index = 0;
//
//    curr_index = scanner.skip_whitespace();
//    assert(curr_index == 0);
//
//    const text2 =
//        \\--hello
//        \\ world
//    ;
//    scanner.curr_index = 0;
//
//    curr_index = Scanner.skip_whitespace(text2, curr_index);
//    assert(curr_index == 9);
//    assert(text2[curr_index] == 'w');
//
//    curr_index = 0;
//    const text3 = "-HELLO";
//    curr_index = Scanner.skip_whitespace(text3, curr_index);
//    assert(curr_index == 0);
//
//    curr_index = 0;
//    curr_index = Scanner.skip_whitespace(query, curr_index);
//    assert(curr_index == 0);
//}

pub fn main() !void {}
