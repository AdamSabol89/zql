const std = @import("std");
const Type = std.builtin.Type;
const StructField = Type.StructField;
const UnionField = Type.UnionField;
const EnumField = Type.EnumField;

const TokenTypesList = [_][:0]const u8{ "STAR", "EQUALS", "COMMA", "RIGHT_PAREN", "LEFT_PAREN", "PLUS", "DASH", "F_SLASH", "SEMI_COLON", "BARE_WORD" };

const TokenValList = [_][]const u8{ "*", "=", ",", ")", "(", "+", "-", "/", ";", "BARE_WORD" };
const TokenTypes = GenTokenTypes(&TokenTypesList);

pub const SOA_TokenTypes = std.MultiArrayList(TokenTypes);

const TokenInfo = struct {
    lexeme: []const u8,
    index: usize,
    //line_num: usize,
    //line_index: usize,
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
