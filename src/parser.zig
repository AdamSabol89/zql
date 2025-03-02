const tables = @import("tables.zig");
const parser = @import("parser.zig");
const lexer = @import("main.zig");
const std = @import("std");

pub const QueryPlan = struct {};

pub const StateMachine = struct {};

pub fn parse_select_query(tokens: lexer.SOA_TokenTypes, tables_table: tables.TablesTable) QueryPlan {
    _ = tables_table;
    var i: usize = 1;

    while (i < tokens.len) : (i += 1) {
        switch (tokens.get(i)) {
            .BARE_WORD => {},

            else => {},
        }
    }

    return .{};
}
