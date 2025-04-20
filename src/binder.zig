const expression = @import("column_expression.zig");
const parser = @import("parser.zig");
const types = @import("types.zig");
const tables = @import("table_catalog.zig");
const std = @import("std");
const assert = std.debug.assert;

const BinaryOpInfo = types.BinaryOpInfo;

const BindError = error{ TableDoesNotExistInContext, ColumnDoesNotExistInTable };

//schema.table.column
const ColumnDetail = struct {
    table: ?[]const u8,
    column: []const u8,
};

pub fn count_identifiers_in_path(identifier: []const u8) usize {
    var count: usize = 0;
    var window = identifier;

    while (std.mem.indexOf(u8, window, &[1]u8{'.'})) |next| {
        count += 1;
        window = window[next + 1 ..];
    }
    return count + 1;
}

pub fn parse_as_identifier(identifier: []const u8) ColumnDetail {
    const path_size = count_identifiers_in_path(identifier);

    return switch (path_size) {
        1 => ColumnDetail{
            .table = null,
            .column = identifier,
        },

        2 => blk: {
            var iter = std.mem.splitScalar(u8, identifier, '.');
            const table = iter.next().?;
            const column = iter.next().?;

            const result = ColumnDetail{
                .table = table,
                .column = column,
            };
            break :blk result;
        },
        else => blk: {
            var iter = std.mem.splitScalar(u8, identifier, '.');
            _ = iter.next().?;
            const table = iter.next().?;
            const column = iter.rest();

            const result = ColumnDetail{
                .table = table,
                .column = column,
            };
            break :blk result;
        },
    };
}

// 1.)
// Parse CSV into memory =>
// Run queries on CSV
//
pub const QueryContext = struct {
    table_context: []TableContext,
    column_context: std.ArrayList(*tables.ColumnInfo),
    const Self = @This();

    fn search_context_for_identifier(self: *Self, identifier: []const u8) !?*tables.ColumnInfo {
        const parsed_ident = parse_as_identifier(identifier);

        if (parsed_ident.table) |table_name| {
            const table_detail = try find_table_from_name(table_name, self.table_context);

            if (table_detail.columns.get(parsed_ident.column)) |column| {
                return column;
            }

            return BindError.ColumnDoesNotExistInTable;
        }

        return self.find_column_in_context(parsed_ident.column);
    }

    pub fn find_column_in_context(self: *Self, column_name: []const u8) ?tables.ColumnInfo {}

    pub inline fn find_table_from_name(self: *Self, table_name: []const u8) !*tables.TableInfo {
        for (self.table_context) |table_info| {
            if (std.mem.eql(u8, table_info.alias_or_name, table_name)) {
                return table_info.table_lookup;
            }
        }
        return BindError.TableDoesNotExistInContext;
    }

    fn add_to_column_context() !void {}

    fn add_to_query_context() !void {}
};

//ColumnInfo {
//    PrimitiveType = UINT
//    name = "something"
//
//}
////AT THE ROOT OF COLUMN_EXPRESSION WE GENERATE A column_info and ADD it to the context
//        unary_op (as) prim_type = UINT
//                      column_info = generate(prim_type, alias)
//        /
//        +
///             \
//identifier   identifier
//prim_type = UINT         prim_type = UINT
//column_info = users.name scalar_val = 1

//SELECT
// schema.users.name + 1 AS something,
// something + 1
// FROM users

pub const TableContext = struct {
    table_lookup: *tables.TableInfo,
    alias_or_name: []const u8,
};

// This needs to have all tables relevant to the query passed into it. WITH aliases resolved
fn bind_identifiers_column_expression(root: *expression.ColumnExpression, context: []TableContext) !void {
    switch (root.type) {
        .IDENTIFIER => {
            const parsed_ident = parse_as_identifier(root.expression_lookup.IDENTIFIER.val);

            if (parsed_ident.table) |table_name| {
                const table_detail = try find_table_from_name(table_name, context);

                if (table_detail.columns.get(parsed_ident.column)) |column| {
                    root.expression_lookup.IDENTIFIER.ident_type = column.column_type;
                    return;
                }
                return BindError.ColumnDoesNotExistInTable;
            }

            const column = find_column_in_context(parsed_ident.column){};
        },
    }
}

// SELECT usrs.column1
// FROM users. usrs
