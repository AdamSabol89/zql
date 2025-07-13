const expression = @import("column_expression.zig");
const parser = @import("parser.zig");
const types = @import("types.zig");
const tables = @import("table_catalog.zig");
const std = @import("std");
const assert = std.debug.assert;

const BinaryOpInfo = types.BinaryOpInfo;

pub fn todo(args: anytype) void {
    _ = args;
    std.debug.print("TODO!\n", .{});
}

const BindError = error{
    TableDoesNotExistInContext,
    ColumnDoesNotExistInTable,
    AmbiguosColumnReference,
};

//schema.table.column
const ColumnDetail = struct {
    schema: ?[]const u8,
    table: ?[]const u8,
    column: []const u8,
};

pub const LiteralVal = union(enum) {
    float: f64,
    int: i64,
    bytes: []const u8,

    pub fn parse_as_literal(identifier: []const u8) ?LiteralVal {
        const int_result: ?i64 = try std.fmt.parseInt(i64, identifier) catch null;
        if (int_result) |int| {
            return .{ .int = int };
        }

        const float_result: ?f64 = try std.fmt.parseFloat(f64, identifier) catch null;
        if (float_result) |flt| {
            return .{ .float = flt };
        }

        if (identifier[0] == '\'' or identifier[0] == '"') {
            //TODO: bug we should check that it also closes with a matching ' or ", is this a bug in the tokenizer?
            return .{ .bytes = identifier[1 .. identifier.len - 1] };
        }

        return null;
    }
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
            .schema = null,
            .table = null,
            .column = identifier,
        },
        2 => blk: {
            var iter = std.mem.splitScalar(u8, identifier, '.');
            const table = iter.next().?;
            const column = iter.next().?;

            const result = ColumnDetail{
                .schema = null,
                .table = table,
                .column = column,
            };
            break :blk result;
        },
        else => blk: {
            var iter = std.mem.splitScalar(u8, identifier, '.');
            const schema = iter.next().?;
            const table = iter.next().?;
            const column = iter.rest();

            const result = ColumnDetail{
                .schema = schema,
                .column = column,
                .table = table,
            };
            break :blk result;
        },
    };
}

pub const QueryContext = struct {
    table_context: []TableContext,
    column_context: std.ArrayList(*tables.ColumnInfo),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(tbls: []TableContext, allocator: std.mem.Allocator) QueryContext { 
        return .{ 
            .table_context = tbls, 
            .column_context = std.ArrayList(*tables.ColumnInfo).init(allocator),
            .allocator= allocator,
        };
    }

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

    //pub fn find_column_in_context(self: *Self, column_name: []const u8) ?tables.ColumnInfo {}

    pub inline fn find_table_from_name(self: *Self, table_name: []const u8) !*tables.TableInfo {
        for (self.table_context) |table_info| {
            if (std.mem.eql(u8, table_info.alias_or_name, table_name)) {
                return table_info.table_info;
            }
        }
        return BindError.TableDoesNotExistInContext;
    }

    fn add_to_column_context() !void {}

    fn add_to_query_context() !void {}
};

pub const TableContext = struct {
    table_info: *tables.TableInfo,
    alias: ?[]const u8,
};

fn validate_types(root: parser.AliasedColumnExpression, ctx: QueryContext) types.PrimitiveType {
    switch (root.expression.type) {
        .IDENTIFIER => {
            return try bind_identifier(root.expression, ctx);
        },
        .BINARY_OP => {},
        else => {},
    }
}

fn lookup_table_with_schema(table_name: []const u8, schema: []const u8, ctx: QueryContext) !*tables.TableInfo {
    todo(.{ table_name, schema, ctx });
}

fn lookup_table_in_context(table_name: []const u8, ctx: QueryContext) !*tables.TableInfo {
    for (ctx.table_context) |search_tbl| {
        if (search_tbl.alias) |alias| {
            if (std.mem.eql(u8, alias, table_name)) {
                return search_tbl;
            }
        }
        if (std.mem.eql(u8, search_tbl.table_info.name, table_name)) {
            return search_tbl;
        }
    }
    return BindError.TableDoesNotExistInContext;
}

fn lookup_column_in_context(column_name: []const u8, ctx: QueryContext) !?*tables.TableInfo {
    var result: ?*tables.TableInfo = null;
    var ambiguous_cols = std.ArrayList(*tables.ColumnInfo).init(ctx.allocator);

    for (ctx.table_context) |search_tbl| {
        if (search_tbl.table_info.columns.getPtr(column_name)) |column| {
            if (result) |_| {
                try ambiguous_cols.append(column);
            } else {
                result = column;
            }
        }
    }

    return switch (ambiguous_cols.items.len) {
        0 => null,
        1 => result.? orelse unreachable,
        else => blk: {
            //TODO: Better string formatting
            std.debug.print("Found multiple columns, ambigous reference {s}, matches: ", .{column_name});
            for (ambiguous_cols.items) |col| {
                std.debug.print("{s}, ", .{col});
            }
            std.debug.print("\n");
            break :blk BindError.AmbiguosColumnReference;
        },
    };
}

pub fn bind_identifier(root: *expression.ColumnExpression, ctx: QueryContext) !?types.PrimitiveType {
    const parsed_ident = parse_as_identifier(root.expression_lookup.IDENTIFIER.val);

    if (parsed_ident.schema) |schema| {
        lookup_table_with_schema(parsed_ident.table.? orelse unreachable, schema, ctx);
    }

    if (parsed_ident.table) |table_name| {
        const table_match = try lookup_table_in_context(table_name, ctx);
        if (table_match.columns.getPtr(parsed_ident.column)) |col_ptr| {
            root.expression_lookup.IDENTIFIER.ident_detail = .{ .column = col_ptr };
            root.expression_lookup.IDENTIFIER.ident_type = col_ptr.column_type;
            root.expression_lookup.IDENTIFIER.bound = true;
            return col_ptr.column_type;
        }
    }

    if (try lookup_column_in_context(parsed_ident.column)) |col_ptr| {
        root.expression_lookup.IDENTIFIER.ident_detail = .{ .column = col_ptr };
        root.expression_lookup.IDENTIFIER.ident_type = col_ptr.column_type;
        root.expression_lookup.IDENTIFIER.bound = true;
        return col_ptr.column_type;
    }

    if (LiteralVal.parse_as_literal(root.expression_lookup.IDENTIFIER.val)) |literal| {
        root.expression_lookup.IDENTIFIER.ident_detail.scalar = literal;
        root.expression_lookup.IDENTIFIER.ident_type = switch (literal) {
            .float => types.PrimitiveType.FLOAT64,
            .int => types.PrimitiveType.INT64,
            .bytes => types.PrimitiveType.BYTES,
        };
        root.expression_lookup.IDENTIFIER.bound = true;
        return root.expression_lookup.IDENTIFIER.ident_type;
    }

    std.debug.print("Unable to resolve reference: {s}, \n", .{root.expression_lookup.IDENTIFIER.val});
    return BindError.ColumnDoesNotExistInTable;
}

// SELECT usrs.column1 + 1 as  something,
// something + 1,
//
//
//
// FROM users. usrs
//
//
// schema1.users.column1,
// schema2.users.column2,
