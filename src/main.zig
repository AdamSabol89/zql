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

//Node (val, pointer, len)
//    pointer, pointer, ponter
//        Node (val pointer len)

//detect non keyword tokens ->
//if its bareword do hashlookup in table
//if not assume its identifier
//SELECT, INSERT, UPDATE, STAR
//linear search children???
//
//
//std.StaticStringMap()

//THIS IS GARBAGE
inline fn finish_bareword(previous_index: *usize, current_index: *usize, token_index: *usize, SOA_token: *SOA_TokenTypes, allocator: std.mem.Allocator) !void {
    const lexeme = query[previous_index.*..current_index.*];

    const parsed_token = TokenTypes{ .BARE_WORD = .{
        .lexeme = lexeme,
        .index = previous_index.*,
    } };
    std.debug.print("Bare word: {s}, at: {d} \n", .{ lexeme, previous_index.* });

    try SOA_token.*.insert(allocator, token_index.*, parsed_token);
    token_index.* += 1;
    previous_index.* = 0;
}

pub fn tokenize_query(allocator: std.mem.Allocator) !SOA_TokenTypes {
    const white_space = [_]u8{ ' ', '\n', '\t' };

    var SOA_token: SOA_TokenTypes = .{};

    var token_index: usize = 0;
    var i: usize = 0;
    var k: usize = 0;

    token_iter: while (i < query.len) {

        // HANDLE WHITE SPACE
        inline for (white_space) |value| {
            if (query[i] == value) {
                try finish_bareword(&k, &i, &token_index, &SOA_token, allocator);
                i += 1;
                continue :token_iter;
            }
        }

        // HANDLE COMMENTS
        if (std.mem.startsWith(u8, query[i..], "--")) {
            try finish_bareword(&k, &i, &token_index, &SOA_token, allocator);

            while (query[i] != '\n') {
                i += 1;
            }

            continue :token_iter;
        }

        // HANDLE MATCH_TOKENS
        inline for (TokenValList, 0..TokenValList.len) |match_token, j| {
            if (std.mem.eql(u8, match_token[0..], query[i .. i + match_token.len])) {
                try finish_bareword(&k, &i, &token_index, &SOA_token, allocator);
                defer token_index += 1;

                std.debug.print("Found Token: {s} at: {d} \n", .{ query[i..match_token.len], i });

                const parsed_token_payload = .{ .lexeme = query[i..match_token.len], .index = i };
                const parsed_token = @unionInit(TokenTypes, TokenTypesList[j], parsed_token_payload);

                try SOA_token.insert(allocator, token_index, parsed_token);

                i += match_token.len;
                continue :token_iter;
            }
        }

        //IF all else fails were starting a new bareword or continuing a bareword
        if (k == 0) {
            k = i;
        }

        i += 1;
        std.debug.print("curr_index: {d}\n", .{i});
    }

    return SOA_token;
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

test "parse query" {
    const allocator = std.testing.allocator;

    var tokens = try tokenize_query(allocator);
    defer tokens.deinit(allocator);

    var tables_table = try tables.initTestTables(allocator);
    defer tables.deinitTablesTable(&tables_table, allocator);

    parse_query_syntax(tables_table, tokens);
}

test "tokenize query" {
    const allocator = std.testing.allocator;

    var tokens = try tokenize_query(allocator);
    defer tokens.deinit(allocator);

    const ident_token = tokens.get(1);

    switch (ident_token) {
        .BARE_WORD => |token| {
            try std.testing.expect(std.mem.eql(u8, token.lexeme, "users.name"));
        },

        else => {
            std.debug.print("FUCK", .{});
        },
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
    \\SELECT 
    \\    users.name + users.phone ,  
    \\    FUNCTION(users.name , users.phone) ,
    \\ --THIS IS A COMMENT 
    \\ FROM users
    \\ JOIN content ON users.content_id = content.id
    \\ WHERE users.id = 12
    \\ LIMIT 100 
;

pub fn main() !void {}
