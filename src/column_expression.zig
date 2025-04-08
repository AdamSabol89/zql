/// PARSER FOR COLUMN EXPRESSIONS
const std = @import("std");
const lexer = @import("main.zig");

//
//x + y
//f(x+y)
//

pub const BinaryOpInfo = struct {
    binary_op: BinaryOp,
    supported_type: []const PrimitiveType,

    // we no support operator overloading in SQL
    // zig fmt: off
    const data: [103]PrimitiveType = .{ 
        //AND
        .BOOLEAN, .SENTINEL, 
        //XOR
        .BOOLEAN, .SENTINEL, 
        //OR
        .BOOLEAN, .SENTINEL, 
        //ADD
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //MUL
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //DIV
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //SUB
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //MOD
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //LTH
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //GTH
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //LTHEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //GTHEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //EQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .BOOLEAN, .BYTES, .SENTINEL, 
        //NEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .BOOLEAN, .BYTES, .SENTINEL, 
        //SHF_RIGHT
        .INT64, .INT32, .U32, .U64, .BYTES,  .SENTINEL, 
        //SHF_LEFT
        .INT64, .INT32, .U32, .U64, .BYTES,  .SENTINEL, 
        //LIKE 
        .BYTES, .SENTINEL,
        //RLIKE 
        .BYTES, .SENTINEL,
    };
    // zig fmt: on

    pub const binary_ops: [19]BinaryOpInfo = generate_binary_ops();

    pub fn generate_binary_ops() [19]BinaryOpInfo {
        comptime var result: [19]BinaryOpInfo = undefined;

        comptime var result_index: u8 = 0;
        comptime var i: usize = 0;
        comptime var prev: usize = 0;

        inline while (i < data.len) {
            if (data[i] == .SENTINEL) {
                result[result_index] = .{
                    .supported_type = data[prev..i],
                    .binary_op = @enumFromInt(result_index),
                };
                result_index += 1;
                prev = i + 1;
            }
            i += 1;
        }
        return result;
    }
};

test "generate binary ops" {
    const test_val = BinaryOpInfo.binary_ops[1];
    std.debug.print("{any}\n", .{test_val});
}

test "add binary opp" {
    const types: [3]PrimitiveType = .{ .INT64, .INT32, .U32 };

    const something = .{ .binary_op = .AND, .supported_type = types[0..] };
    _ = something;
}

pub const PrimitiveType = enum(u8) {
    INT64 = 0,
    INT32 = 1,
    U32 = 2,
    U64 = 3,

    BOOLEAN = 4,
    FLOAT32 = 5,
    FLOAT64 = 6,

    BYTES = 7,
    SENTINEL = 8,
};

pub const TernaryOp = enum(u8) {
    BETWEEN = 0,
};

pub const UnaryOp = enum(u8) {
    NOT = 0,
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
//for identifier
// -> lookup named
// -> interpret as literal
//
// 1 + 2 + 3 + 4

//test "create_ast_from_expression" {
//    var buffer: [10000]u8 = undefined;
//    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
//    const root_allocator = fba.allocator();
//
//    var arena = std.heap.ArenaAllocator.init(root_allocator);
//    const allocator = arena.allocator();
//    defer arena.deinit();
//
//    //TODO: bug
//    //these cause index out of bound crashes
//    const expression = "100 + 22 + 3 + 10 + 111 * 1000";
//    //const expression = "1 + 2 + 33";
//    //const expression = "100 + 20 + 33 ";
//
//    var soa_token: lexer.SOA_token = .{};
//
//    var scanner = try lexer.Scanner.init(&soa_token, expression, allocator);
//    defer scanner.deinit(allocator);
//    try scanner.tokenize(allocator);
//
//    const tokentypes = soa_token.items(.type);
//
//    try parse_add_expression(
//        tokentypes,
//        &soa_token,
//        0,
//    );
//}

//pub fn parse_add_expression(tokens: lexer.SOA_token, left_index: usize) ExpressionType {
//}
//
pub const ExpressionParser = struct {
    tokens: lexer.SOA_token,
    curr_index: usize,
    curr_token_type: lexer.TokenType,

    const Self = @This();

    pub fn parse_pratt(self: *Self) void {
        _ = self;
    }
};

//5 + 2 && 1
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

//pub fn parse_add_expression(tokens: []const lexer.TokenType, token_details: *tokenizer.SOA_token, left_index: usize) !void {
//    if (left_index == tokens.len) return;
//    //these would need to be allocated
//    //TODO: we should have a rough idea of the size once we parse so using bump allocations here may not be optimal
//    var left: ExpressionInfo = undefined;
//
//    switch (tokens[left_index]) {
//        .PLUS => {
//            left = ExpressionInfo{ .BINARY_OP = .ADD };
//            std.debug.print("FOUND PLUS: {any}\n", .{left});
//        },
//
//        .STAR => {
//            left = ExpressionInfo{ .BINARY_OP = .MUL };
//            std.debug.print("FOUND PLUS: {any}\n", .{left});
//        },
//
//        .IDENTIFIER => {
//            const token_detail = token_details.get(left_index);
//            const lexeme = token_detail.info.lexeme;
//            const parsed_int = try std.fmt.parseInt(usize, lexeme, 0);
//
//            const right = ExpressionInfo{ .IDENTIFIER = .{ .val = parsed_int } };
//            std.debug.print("{any}\n", .{right});
//        },
//
//        else => {
//            std.debug.print("BIG PROBLEM! \n", .{});
//        },
//    }
//
//    try parse_add_expression(tokens, token_details, left_index + 1);
//    return;
//}

pub const IdentifierInfo = struct {
    val: []const u8,
};

pub const FunctionInfo = struct {
    val: []const u8,
    //TODO: hash: []const u8,
    args: []*ColumnExpression,
};

pub const ExpressionType = enum {
    BINARY_OP,
    TERNARY_OP,
    UNARY_OP,
    FUNCTION_CALL,
    IDENTIFIER,
};

pub const ExpressionInfo = union(ExpressionType) {
    //for binary op and function call we just store the index
    BINARY_OP: BinaryOp,
    TERNARY_OP: TernaryOp,
    UNARY_OP: UnaryOp,
    //for binary op and function call we just store the index

    //UNARY_OP: struct {usize},

    FUNCTION_CALL: FunctionInfo,
    //for identifier we store details? maybe for now but this should maybe be tag and optional pointer?
    IDENTIFIER: IdentifierInfo,

    pub fn create_op_from_token(token: lexer.TokenType, etype: ExpressionType) ExpressionInfo {
        switch (etype) {
            .BINARY_OP => .{ .BINARY_OP = token_to_binop(token) },
            .TERNARY_OP => .{ .TERNARY_OP = undefined },
            .FUNCTION_CALL => .{ .FUNCTION_CALL = undefined },
            else => {},
        }
    }

    pub fn create_identifier_from_token(token: lexer.Token) ExpressionInfo {
        //std.debug.print("{s}\n", .{token.info.lexeme});
        return ExpressionInfo{ .IDENTIFIER = .{ .val = token.info.lexeme } };
    }

    pub fn create_function_call_from_token(token: lexer.Token, args: []*ColumnExpression) ExpressionInfo {
        return ExpressionInfo{ .FUNCTION_CALL = .{ .val = token.info.lexeme, .args = args } };
    }
};

pub const ColumnExpression = struct {
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
            std.debug.assert(false);
            break :blk BinaryOp.MUL;
        },
    };
}

pub const ColumnExpressionParser = struct {
    tokens: lexer.SOA_token,
    curr_token: usize,
    token_types: []lexer.TokenType,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(tokens: lexer.SOA_token, allocator: std.mem.Allocator, curr_token: ?usize) ColumnExpressionParser {
        // zig fmt: off
        return .{
            .tokens = tokens,
            .curr_token = if (curr_token) |index| index else 0 ,
            .token_types = tokens.items(.type),
            .allocator = allocator
                
        };
        // zig fmt: on
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

                    var args = try std.ArrayList(*ColumnExpression).initCapacity(self.allocator, 5);

                    if (self.peek_curr_token_type() != .RIGHT_PAREN) {
                        while (true) {
                            try args.append(try self.parse_column_expression(0));
                            if (self.peek_curr_token_type() != lexer.TokenType.COMMA) break else _ = self.consume_curr_token_type();
                        }
                    }

                    const right_paren = self.consume_curr_token_type();
                    std.debug.assert(right_paren == .RIGHT_PAREN);

                    node_ptr = try ColumnExpression.init_owned(self.allocator, .FUNCTION_CALL, children);
                    node_ptr.expression_lookup = ExpressionInfo.create_function_call_from_token(token_info, args.items);
                }
            },

            .LEFT_PAREN => {
                node_ptr = try self.parse_column_expression(0);
                if (self.peek_curr_token_type() != .RIGHT_PAREN) {
                    //TODO: Error
                    std.debug.print("Parsed a left a parenthesis and expression but no right parenthesis!", .{});
                    return ParseError.InvalidColumnExpression;
                }
            },

            else => {
                const token_info = self.tokens.get(self.curr_token - 1).info;
                //const line_number = line_number_from_index(token_info.index);

                std.debug.print("Invalid column expression at line: {d} index: {d}. Invalid identifier, likely a reserved word. Found: \"{s}\".\n", .{ token_info.line, token_info.index, token_info.lexeme });
                return ParseError.InvalidColumnExpression;
            },
        }

        return node_ptr;
    }

    fn print_curr_token(self: *Self) void {
        const curr_token = self.tokens.get(self.curr_token);
        std.debug.print("{s}\n", .{curr_token.info.lexeme});
    }

    pub fn parse_column_expression(self: *Self, precedence: usize) anyerror!*ColumnExpression {
        //self.print_curr_token();
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
                    left.expression_lookup = .{ .BINARY_OP = token_to_binop(curr_token_type) };
                },

                else => {
                    const token_info = self.tokens.get(self.curr_token - 1).info;
                    //const line_number = line_number_from_index(token_info.index);

                    std.debug.print("Invalid column expression at line: {d} index: {d}. Invalid operator found: \"{s}\".\n", .{ token_info.line, token_info.index, token_info.lexeme });
                    return ParseError.InvalidColumnExpression;
                },
            }
        }
        return left;
    }
};

const ParseError = error{
    InvalidColumnExpression,
};

//    + 1/2 max(left,right)
//  x   y
//+

// algo: dfs from root to get total depth
// root is x "  " * indent
// left is  "  " * indent - 1
// right is  "  " * indent + 1
// right always prints newline
//

//var depth: usize = 0;
//fn depth_of_ast(node: *ColumnExpression, curr_depth: usize) void {
//    if (curr_depth > depth) {
//        depth = curr_depth;
//    }
//
//    for (node.children) |child| {
//        if (child) |exists| {
//            depth_of_ast(exists, curr_depth + 1);
//        }
//    }
//}

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
