const std = @import("std");
const lexer = @import("main.zig");
const types = @import("types.zig");
const binder = @import("binder.zig");
const tables = @import("table_catalog.zig");
const assert = std.debug.assert;

pub const ParseError = error{
    InvalidColumnExpression,
};

pub const UnaryOp = enum(u8) {
    NOT = 0,
    SOMETHING_TEST = 1,
};

pub const BinaryOp = enum(u8) {
    AND = 0,
    XOR = 1,
    OR = 2,
    ADD = 3,
    MUL = 4,
    DIV = 5,
    SUB = 6,
    MOD = 7,

    LTHN = 8,
    GTHN = 9,
    LTHNEQ = 10,
    GTHNEQ = 11,
    EQ = 12,
    NEQ = 13,

    SHF_RIGHT = 14,
    SHF_LEFT = 15,

    LIKE = 16,
    RLIKE = 17,
};

pub const TernaryOp = enum(u8) {
    BETWEEN = 0,
};

pub const ExpressionType = enum {
    BINARY_OP,
    TERNARY_OP,
    UNARY_OP,
    FUNCTION_CALL,
    IDENTIFIER,
};

const IdentifierDetail = union(enum) {
    scalar: binder.LiteralVal,
    column: *tables.ColumnInfo,
};

pub const IdentifierInfo = struct {
    val: []const u8,

    bound: bool = false,
    ident_detail: IdentifierDetail = undefined,
    ident_type: types.PrimitiveType = undefined,
};

pub const BinaryOpInfo = struct {
    binary_op: BinaryOp,
    bound: bool = false,
    resolved_type: types.PrimitiveType = undefined,
};

pub const FunctionInfo = struct {
    val: []const u8,
    //TODO: hash: []const u8,
    args: []*ColumnExpression,
};

pub const ExpressionInfo = union(ExpressionType) {
    BINARY_OP: BinaryOpInfo,
    TERNARY_OP: TernaryOp,
    UNARY_OP: UnaryOp,
    FUNCTION_CALL: FunctionInfo,
    IDENTIFIER: IdentifierInfo,

    pub fn create_op_from_token(token: lexer.TokenType, etype: ExpressionType) ExpressionInfo {
        switch (etype) {
            .BINARY_OP => create_binop_from_token(token),
            .TERNARY_OP => .{ .TERNARY_OP = undefined },
            else => {},
        }
    }

    pub fn create_identifier_from_token(token: lexer.Token) ExpressionInfo {
        return ExpressionInfo{ .IDENTIFIER = .{ .val = token.info.lexeme } };
    }

    pub fn create_binop_from_token(token: lexer.Token) ExpressionInfo {
        return ExpressionInfo{ .BINARY_OP = .{ .binary_op = token_to_binop(token) } };
    }

    pub fn create_function_call_from_token(token: lexer.Token, args: []*ColumnExpression) ExpressionInfo {
        return ExpressionInfo{ .FUNCTION_CALL = .{ .val = token.info.lexeme, .args = args } };
    }
};

//pub fn ExpressionInfoPool(size: usize) type {
//    return struct {
//        allocator: std.mem.Allocator,
//        pool: []ExpressionInfo,
//        free_list: [size]u64,
//        const Self = @This();
//
//        pub fn init(allocator: std.mem.Allocator) !Self {
//            return .{
//                .allocator = allocator,
//                .pool = try allocator.alloc(Self, 64 * size),
//                .free_list = 0 * size,
//            };
//        }
//
//        pub fn free(self: *Self, index: u64) void {
//            assert(index < size * 64);
//            const one: u64 = 1;
//            const free_list_index = index / 64;
//            const offset: u6 = index % 64;
//            const blk = self.free_list[free_list_index];
//            const free_offset = ~(one << offset);
//            const return_blk = blk & free_offset;
//            self.free_list[free_list_index] = return_blk;
//        }
//
//        pub fn create() u64 {}
//    };
//}

pub const ColumnExpression = struct {
    //expression_lookup: u32,
    type: ExpressionType,
    children: [3]?*ColumnExpression,
    expression_lookup: ExpressionInfo,

    pub fn init_owned(allocator: std.mem.Allocator, etype: ExpressionType, children: [3]?*ColumnExpression) !*ColumnExpression {
        var new = try allocator.create(ColumnExpression);
        new.type = etype;
        new.children = children;
        return new;
    }
};

pub inline fn get_precedence(token: lexer.TokenType) usize {
    return switch (token) {
        .GTHN, .LTHN, .EQL, .LTHN_EQL, .GTHN_EQL => 5,
        .PLUS, .DASH => 10,
        .F_SLASH, .STAR => 20,
        .AND => 30,
        .EXLMRK => 40,
        else => 0,
    };
}

//TODO: switch to indexing/table over switch.
pub fn token_to_binop(token: lexer.TokenType) BinaryOp {
    return switch (token) {
        .DASH => BinaryOp.SUB,
        .STAR => BinaryOp.MUL,
        .F_SLASH => BinaryOp.DIV,
        .PLUS => BinaryOp.ADD,
        .AND => BinaryOp.AND,
        .LTHN => BinaryOp.LTHN,
        .GTHN => BinaryOp.GTHN,
        else => blk: {
            std.debug.print("Invalid Token attempted to parse as binary op .{any}", .{token});
            assert(false);
            break :blk BinaryOp.MUL;
        },
    };
}

const TokenIter = struct {
    tokens: lexer.SOA_token,
    curr_token: usize,
    token_types: []lexer.TokenType,
};

pub const ColumnExpressionParser = struct {
    tokens: lexer.SOA_token,
    curr_token: usize,
    token_types: []lexer.TokenType,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(tokens: lexer.SOA_token, allocator: std.mem.Allocator, curr_token: ?usize) ColumnExpressionParser {
        return .{
            .tokens = tokens,
            .curr_token = if (curr_token) |index| index else 0,
            .token_types = tokens.items(.type),
            .allocator = allocator,
        };
    }

    // TODO: curr_token > token_types.len we need to signal to end the parse
    // peeks the current token without consuming and returns its type
    pub inline fn peek_curr_token_type(self: *Self) lexer.TokenType {
        if (self.curr_token == self.token_types.len) {
            return .END_OF_TOKEN;
        }
        return self.token_types[self.curr_token];
    }

    // consumes the current token and returns its type
    pub inline fn consume_curr_token_type(self: *Self) lexer.TokenType {
        const result = self.token_types[self.curr_token];
        self.*.curr_token += 1;
        return result;
    }

    // peeks the next token and returns its type
    inline fn peek_next_token_type(self: *Self) lexer.TokenType {
        return self.token_types[self.curr_token + 1];
    }

    pub fn parse_primary(self: *Self) anyerror!*ColumnExpression {
        const curr_token = self.consume_curr_token_type();
        var node_ptr: *ColumnExpression = undefined;

        switch (curr_token) {
            .IDENTIFIER => {
                const token_info = self.tokens.get(self.curr_token - 1);
                const children: [3]?*ColumnExpression = [3]?*ColumnExpression{ null, null, null };

                if (self.peek_curr_token_type() != lexer.TokenType.LEFT_PAREN) {
                    // Bare Identifier
                    node_ptr = try ColumnExpression.init_owned(
                        self.allocator,
                        .IDENTIFIER,
                        children,
                    );

                    node_ptr.expression_lookup = ExpressionInfo.create_identifier_from_token(token_info);
                } else {
                    // Function Call
                    _ = self.consume_curr_token_type();

                    var args = try std.ArrayList(*ColumnExpression).initCapacity(self.allocator, 1);

                    if (self.peek_curr_token_type() != .RIGHT_PAREN) {
                        while (true) {
                            try args.append(try self.parse_column_expression(0));
                            if (self.peek_curr_token_type() != lexer.TokenType.COMMA) break else _ = self.consume_curr_token_type();
                        }
                    }

                    const right_paren = self.consume_curr_token_type();
                    assert(right_paren == .RIGHT_PAREN);

                    node_ptr = try ColumnExpression.init_owned(self.allocator, .FUNCTION_CALL, children);
                    node_ptr.expression_lookup = ExpressionInfo.create_function_call_from_token(token_info, args.items);
                }
            },

            .LEFT_PAREN => {
                node_ptr = try self.parse_column_expression(0);
                if (self.peek_curr_token_type() != .RIGHT_PAREN) {
                    std.debug.print("Parsed a left a parenthesis and expression but no right parenthesis!", .{});
                    return ParseError.InvalidColumnExpression;
                }
            },

            else => {
                const token_info = self.tokens.get(self.curr_token - 1).info;
                std.debug.print("Invalid column expression at line: {d} index: {d}. Invalid identifier, likely a reserved word. Found: \"{s}\".\n", .{ token_info.line, token_info.index, token_info.lexeme });
                return ParseError.InvalidColumnExpression;
            },
        }

        return node_ptr;
    }

    pub fn parse_column_expression(self: *Self, precedence: usize) anyerror!*ColumnExpression {
        var left: *ColumnExpression = try self.parse_primary();

        while (true) {
            const curr_token_type = self.peek_curr_token_type();
            const new_precedence = get_precedence(curr_token_type);

            if (new_precedence <= precedence) {
                break;
            }

            switch (curr_token_type) {
                .PLUS, .DASH, .F_SLASH, .STAR, .AND, .LTHN, .GTHN, .EQL, .LTHN_EQL, .GTHN_EQL => {
                    _ = self.consume_curr_token_type();

                    const right: *ColumnExpression = try self.parse_column_expression(new_precedence);
                    const children: [3]?*ColumnExpression = [3]?*ColumnExpression{ left, right, null };

                    left = try ColumnExpression.init_owned(self.allocator, .BINARY_OP, children);
                    left.expression_lookup = .{ .BINARY_OP = .{ .binary_op = token_to_binop(curr_token_type) } };
                },

                else => {
                    const token_info = self.tokens.get(self.curr_token - 1).info;
                    std.debug.print("Invalid column expression at line: {d} index: {d}. Invalid operator found: \"{s}\".\n", .{ token_info.line, token_info.index, token_info.lexeme });
                    return ParseError.InvalidColumnExpression;
                },
            }
        }
        return left;
    }
};

//test "parse sql column expression" {
//    var buffer: [10000]u8 = undefined;
//    //const column_expression = "(FUNCTION1(x,y,z) + FUNCTION2(a,z,d)) * x + z,";
//    const column_expression =
//        \\
//        \\ x < z > y
//    ;
//    //const column_expression = "x + z * 12 + function(z, x + 2)";
//    //const column_expression = "function(z + y) + x";
//
//    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
//    const root_allocator = fba.allocator();
//
//    var arena = std.heap.ArenaAllocator.init(root_allocator);
//    const allocator = arena.allocator();
//    defer arena.deinit();
//
//    var soa_token: lexer.SOA_token = .{};
//    var scanner = try lexer.Scanner.init(&soa_token, column_expression, allocator);
//    defer scanner.deinit(allocator);
//
//    try scanner.tokenize(allocator);
//    defer soa_token.deinit(allocator);
//
//    var expression_parser = ColumnExpressionParser.init(soa_token, allocator, null);
//    const root = try expression_parser.parse_column_expression(0);
//    _ = root.type;
//
//    //std.debug.print("ROOT TYPE: {s}\n", .{root.expression_lookup.IDENTIFIER.val});
//    //const left = root.children[0].?;
//    //std.debug.print("LEFT TYPE: {any} \n", .{left});
//}
//
