const std = @import("std");
const Type = std.builtin.Type;
const StructField = Type.StructField;
const UnionField = Type.UnionField;
const EnumField = Type.EnumField;
const tables = @import("tables.zig");
const parser = @import("parser.zig");

const TokenInfo = struct {
    lexeme: []const u8,
    index: usize,
};

//thoughts:
// we can do token_vals = [ ], token_types = []
// this mean each  KEYWORD is its own token
//
const TokenValList = [_][]const u8{
    "IDENTIFIER",
    "SELECT",
    "FROM",
    "WHERE",
    "LIMIT",
    "WILDCARD",
    "EQUALS",
    "JOIN",
    "INNER",
    "OUTER",
    "ON",
    "AND",
    "UPDATE",
    "DELETE",
    "INSERT",
    "COMMA",
    "RIGHT_PAREN",
    "LEFT_PAREN",
    "ADD_OPP",
};
const TokenTypesList = [_][:0]const u8{ "IDENTIFIER", "SELECT", "FROM", "WHERE", "LIMIT", "*", "=", "JOIN", "INNER", "OUTER", "ON", "AND", "UPDATE", "DELETE", "INSERT", ",", ")", "(", "+" };

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

//TODO: think about parser some more
pub fn tokenize_query(allocator: std.mem.Allocator) !SOA_TokenTypes {
    const delimiters = [_]u8{ ' ', '\n', '\t' };

    var token_iter = std.mem.tokenizeAny(u8, query, delimiters[0..]);
    var SOA_token: SOA_TokenTypes = .{};

    var token_index: usize = 0;
    token_iter: while (token_iter.next()) |token| {

        // HANDLE COMMENTS
        if (std.mem.startsWith(u8, token, "--")) {
            var i = 0 + token_iter.index;

            while (query[i] != '\n') {
                i += 1;
            }

            token_iter.index = i;

            continue :token_iter;
        }

        // HANDLE KEYWORDS
        inline for (TokenTypesList) |match_token| {
            if (std.mem.eql(u8, match_token[0..], token)) {
                defer token_index += 1;

                //std.debug.print("Found Token: {s} at: {d} \n", .{ token, token_iter.index });

                const parsed_token_payload = .{ .lexeme = token, .index = token_iter.index };
                const parsed_token = @unionInit(TokenTypes, match_token, parsed_token_payload);

                try SOA_token.insert(allocator, token_index, parsed_token);

                continue :token_iter;
            }
        }

        // HANDLE IDENTIFIERS
        const parsed_token = TokenTypes{ .IDENTIFIER = .{
            .lexeme = token,
            .index = token_iter.index,
        } };

        try SOA_token.insert(allocator, token_index, parsed_token);
        token_index += 1;

        //std.debug.print("Identifier: {s}, at: {d} \n", .{ token, token_iter.index });
    }

    return SOA_token;
}

pub fn parse_query_syntax(tables_table: tables.TablesTable, tokens: SOA_TokenTypes) void {
    const init_query_token = tokens.get(0);

    switch (init_query_token) {
        .SELECT => {
            parser.parse_select_query(tables_table, tokens);
        },
        .UPDATE => {},
        .INSERT => {},
        .DELETE => {},
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
        .IDENTIFIER => |token| {
            try std.testing.expect(std.mem.eql(u8, token.lexeme, "IDENTIFIER"));
        },

        else => {
            std.debug.print("FUCK", .{});
        },
    }
}

test "create token tagged union" {
    const Token = GenTokenTypes(&TokenTypesList);

    const select_token: Token = Token{ .SELECT = .{
        .lexeme = "",
        .index = 12,
    } };

    std.debug.print("{s}", .{@tagName(select_token)});
}

const query =
    \\ SELECT 
    \\    users.name + users.phone,  
    \\    FUNCTION(users.name, users.phone),
    \\ --THIS IS A COMMENT 
    \\ FROM users
    \\ JOIN content ON users.content_id = content.id
    \\ WHERE users.id = 12
    \\ LIMIT 100 
;

pub fn main() !void {}
