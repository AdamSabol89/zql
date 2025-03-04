const tables = @import("tables.zig");
const parser = @import("parser.zig");
const lexer = @import("main.zig");
const std = @import("std");

fn todo() void {
    std.debug.print("TODO!\n", .{});
}

const SelectClause = struct {
    cols: []Expression,
};

const Expression = struct {};

const Table = struct {};

//const FromClause = struct { table: Table };
const FromClause = union(enum) {
    table: []const u8,
    select_query: SelectQuery,
};

pub const SelectQuery = struct {
    select_clause: SelectClause,
    from_clause: *FromClause,
    //where_clause: WhereClause,
    //join_clause: JoinClause,
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

const assert = std.debug.assert;
pub fn parse_from_clause(tokens: lexer.SOA_token, from_index: usize) FromClause {
    var next = tokens.get(from_index + 1);

    switch (next.type) {
        .IDENTIFIER => {
            if (lookup_table(next.info.lexeme)) {
                return FromClause{ .table = next.info.lexeme };
            }
        },

        .RIGHT_PAREN => {
            next = tokens.get(from_index + 2);
            //TODO think about subqueries

            assert(next.type == .SELECT);
            parse_select_query(from_index + 3, tokens);
        },

        else => {
            // Handle errors
            todo();
        },
    }
    return .{ .table = "hi" };
}

pub fn parse_select_query(start_index: usize, tokens: lexer.SOA_token) void {
    const types = tokens.items(.type);
    //const token_infos = tokens.items(.info);

    var i: usize = start_index;

    while (i < types.len) : (i += 1) {
        switch (types[i]) {
            .FROM => {
                std.debug.print("Found from clause ", .{});

                const from_clause = parse_from_clause(tokens, i);
                _ = from_clause;
            },

            else => {},
        }
    }

    //for (types, token_infos) |token_type, token_info| {
    //    switch (token_type) {
    //        .IDENTIFIER => {

    //        },

    //        .STAR => {

    //        },

    //        else => {},
    //    }
    //}
}

pub fn parse_query(tokens: lexer.SOA_token) void {
    const first_token = tokens.get(0);

    switch (first_token.type) {
        .SELECT => {
            parse_select_query(1, tokens);
        },

        else => {
            todo();
        },
    }
}
