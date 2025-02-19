const std = @import("std");
const StructField = std.builtin.Type.StructField;
const UnionField = std.builtin.Type.UnionField;
const EnumField = std.builtin.Type.EnumField;

const TokenInfo = struct {
    lexeme: []u8,
    line: usize,
};

const TokenTypesList = [_][:0]const u8{
    "SELECT",
    "FROM",
    "WHERE",
};

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

    const EnumToken = std.builtin.Type{
        .Enum = .{
            //LIMIT 255 union types
            .tag_type = u8,
            .decls = &[_]std.builtin.Type.Declaration{},
            .fields = &enum_fields,
            .is_exhaustive = true,
        },
    };
    const EnumTokenType = @Type(EnumToken);

    const TokenTypes = std.builtin.Type{ .Union = .{
        .layout = std.builtin.Type.ContainerLayout.auto,
        .tag_type = EnumTokenType,
        .fields = &union_fields,
        .decls = &[_]std.builtin.Type.Declaration{},
    } };

    return @Type(TokenTypes);
}

test "create token tagged union" {
    const Token = GenTokenTypes(&TokenTypesList);

    const select_token: Token = Token{ .SELECT = .{
        .lexeme = "",
        .line = 12,
    } };

    std.debug.print("{s}", .{@tagName(select_token)});
}

const query =
    \\ SELECT * 
    \\ FROM users
    \\ WHERE id = 12
    \\ LIMIT 100 
;

pub fn main() !void {}
