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

const AliasedTable = struct {
    table: []const u8,
    alias: ?[]const u8,
};

const AliasedColumnExpression = struct {
    expression: *ColumnExpression,
    alias: ?[]const u8,
};

//const FromClause = struct { table: Table };
const FromClause = union(enum) {
    table: AliasedTable,
    //table: []const u8,
    select_query: SelectQuery,
};

const JoinClause = struct {};

pub const SelectQuery = struct {
    select_clause: []AliasedColumnExpression,
    from_clause: *FromClause,
    //join_clause: JoinClause,
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

//TODO: clean up repetition, inheritance? nty
//NOTE(adam): This contains duplicated code and weird ways of getting a column_expression parser.
//really column_expression_parser and Query_parser should share the underlying tokens, curr_token, token_types and allocator STATE
//but thats not how i built column_expression_parser so every time we parse a column we build a new one???
// Think the solution here is token_iter struct which is shared.
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

    fn try_parse_alias(self: *Self, column_parser: *ColumnExpressionParser) ?[]const u8 {
        _ = self;
        return switch (column_parser.peek_curr_token_type()) {
            .AS => blk: {
                _ = column_parser.consume_curr_token_type();
                _ = column_parser.consume_curr_token_type();

                break :blk column_parser.tokens.get(column_parser.curr_token - 1).info.lexeme;
            },
            .IDENTIFIER => blk: {
                _ = column_parser.consume_curr_token_type();
                break :blk column_parser.tokens.get(column_parser.curr_token - 1).info.lexeme;
            },
            else => null,
        };
    }

    // peeks the next token and returns its type
    inline fn peek_next_token_type(self: *Self) lexer.TokenType {
        return self.token_types[self.curr_token + 1];
    }

    fn parse_select_list(self: *Self) anyerror![]AliasedColumnExpression {
        assert(self.consume_curr_token_type() == .SELECT);

        var column_list = std.ArrayList(AliasedColumnExpression).init(self.allocator);

        var column_parser = ColumnExpressionParser.init(self.tokens, self.allocator, self.curr_token);
        while (true) {
            const column = try column_parser.parse_column_expression(0);
            const alias = self.try_parse_alias(&column_parser);

            try column_list.append(.{ .expression = column, .alias = alias });

            //TODO: Trailing comma
            if (column_parser.peek_curr_token_type() != .COMMA) break else _ = column_parser.consume_curr_token_type();
        }
        self.curr_token = column_parser.curr_token;
        return column_list.items;
    }

    fn parse_from_clause(self: *Self) anyerror!FromClause {
        switch (self.consume_curr_token_type()) {
            .IDENTIFIER => {
                const table_name = self.tokens.get(self.curr_token - 1).info.lexeme;
                // TODO: alias parsing should not be coupled to column parsing need token_iter struct
                var column_parser = ColumnExpressionParser.init(self.tokens, self.allocator, self.curr_token);
                const alias = self.try_parse_alias(&column_parser);

                return FromClause{ .table = AliasedTable{ .table = table_name, .alias = alias } };
            },

            .RIGHT_PAREN => {
                const select_query = try self.parse_select_query();
                return .{ .select_query = select_query };
            },
            else => {
                const token_info = self.tokens.get(self.curr_token - 1).info;
                std.debug.print("Invalid from clause expected scannable found: {s}. At line: {d}, index: {d}.\n", .{ token_info.lexeme, token_info.line, token_info.index });
                return column_expression.ParseError.InvalidColumnExpression;
            },
        }
    }

    pub fn parse_select_query(self: *Self) anyerror!SelectQuery {
        const column_list = try self.parse_select_list();
        assert(self.consume_curr_token_type() == .FROM);

        return SelectQuery{
            .select_clause = column_list,
            .from_clause = @constCast(&try self.parse_from_clause()),
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
