const tables = @import("tables.zig");
const lexer = @import("main.zig");
const std = @import("std");
const column_expression = @import("column_expression.zig");
const assert = std.debug.assert;

const ColumnExpressionParser = column_expression.ColumnExpressionParser;
const ColumnExpression = column_expression.ColumnExpression;

fn todo() void {
    std.debug.print("TODO!\n", .{});
}

const Table = struct {};

//const FromClause = struct { table: Table };
const FromClause = union(enum) {
    table: []const u8,
    select_query: SelectQuery,
};

const JoinClause = struct {};

pub const SelectQuery = struct {
    select_clause: []*ColumnExpression,
    from_clause: *FromClause,
    join_clause: JoinClause,
    //where_clause: WhereClause,
    //aggregation_clause: Aggregation_clause,
    //limit_clause: LimitClause,
    //order_by_clause: OrderByClause,

};

pub const QueryPlan = union(enum) {
    select_query: SelectQuery,
};

pub fn lookup_table(table_name: []const u8) bool {
    _ = table_name;
    //TODO!
    return true;
}

//pub fn parse_from_clause(tokens: lexer.SOA_token, from_index: usize) FromClause {
//    var next = tokens.get(from_index + 1);
//
//    switch (next.type) {
//        .IDENTIFIER => {
//            if (lookup_table(next.info.lexeme)) {
//                return FromClause{ .table = next.info.lexeme };
//            }
//        },
//
//        .RIGHT_PAREN => {
//            next = tokens.get(from_index + 2);
//
//            assert(next.type == .SELECT);
//            parse_select_query(from_index + 3, tokens);
//        },
//
//        else => {
//            // Handle errors
//            todo();
//        },
//    }
//    return .{ .table = "hi" };
//}

//TODO: clean up repetition, inheritance? nty
//NOTE(adam): This contains duplicated code and weird ways of getting a column_expression parser.
//really column_expression_parser and Query_parser should share the underlying tokens, curr_token, token_types and allocator STATE
//but thats not how i built column_expression_parser so every time we parse a column we build a new one???
const QueryParser = struct {
    tokens: lexer.SOA_token,
    curr_token: usize,
    token_types: []lexer.TokenType,
    allocator: std.mem.Allocator,

    const Self = @This();

    // peeks the current token without consuming and returns its type
    inline fn peek_curr_token_type(self: *Self) lexer.TokenType {
        if (self.curr_token == self.token_types.len) {
            return .END_OF_TOKEN;
        }
        return self.token_types[self.curr_token];
    }

    // consumes the current token and returns its type
    inline fn consume_curr_token_type(self: *Self) lexer.TokenType {
        const result = self.token_types[self.curr_token];
        self.*.curr_token += 1;
        return result;
    }

    // peeks the next token and returns its type
    inline fn peek_next_token_type(self: *Self) lexer.TokenType {
        return self.token_types[self.curr_token + 1];
    }

    fn parse_select_list(self: *Self) ![]*ColumnExpression {
        assert(self.curr_token == 0);
        assert(self.consume_curr_token_type() == .SELECT);

        var column_list = std.ArrayList(*ColumnExpression).init(self.allocator);

        var column_parser = ColumnExpressionParser.init(self.tokens, self.allocator, self.curr_token);
        while (true) {
            const column = try column_parser.parse_column_expression(0);

            try column_list.append(column);

            //TODO: Trailing comma
            if (column_parser.peek_curr_token_type() != .COMMA) break else _ = column_parser.consume_curr_token_type();
        }
        self.curr_token = column_parser.curr_token;
        return column_list.items;
    }

    fn parse_from_clause(self: *Self) FromClause {
        //TODO: subqueries
        assert(self.consume_curr_token_type() == .IDENTIFIER);
        return .{ .table = self.tokens.get(self.curr_token - 1).info.lexeme };
    }

    pub fn parse_select_query(self: *Self) !SelectQuery {
        const column_list = try self.parse_select_list();
        assert(self.consume_curr_token_type() == .FROM);

        return SelectQuery{
            .select_clause = column_list,
            .from_clause = @constCast(&self.parse_from_clause()),
        };
    }

    pub fn init(tokens: lexer.SOA_token, allocator: std.mem.Allocator) QueryParser {
        return .{ .curr_token = 0, .tokens = tokens, .token_types = tokens.items(.type), .allocator = allocator };
    }
};

pub fn parse_query(tokens: lexer.SOA_token, allocator: std.mem.Allocator) !void {
    var parser = QueryParser.init(tokens, allocator);

    switch (parser.peek_curr_token_type()) {
        .SELECT => {
            const select_query_plan = try parser.parse_select_query();
            _ = select_query_plan;
        },

        else => {
            todo();
        },
    }
}
