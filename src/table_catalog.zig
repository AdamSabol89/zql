const std = @import("std");
const types = @import("types.zig");

const Thread = std.Thread;
const PrimitiveType = types.PrimitiveType;
const assert = std.debug.assert;

pub const TableCatalogError = error{
    TableDoesNotExist,
};

const TableCatalog = struct {
    table_lookup: std.StringHashMap(TableInfo),
    lock: Thread.RwLock = .{},
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(tables: []TableInfo, allocator: std.mem.Allocator) !TableCatalog {
        var table_lookup = std.StringHashMap(TableInfo).init(allocator);

        for (tables) |table| {
            //todo: slow allocation
            //what we should do is generate an ID(hash) and use that to store in the TableCatalog
            //but we need a custom table implementation for this (TODO).
            const temp_arr = [2][]const u8{
                table.schema.name,
                table.name,
            };

            const lookup_name = try std.mem.concat(allocator, u8, &temp_arr);
            //defer allocator.free(lookup_name);

            try table_lookup.put(lookup_name, table);
        }

        return .{
            .table_lookup = table_lookup,
            .allocator = allocator,
        };
    }

    pub fn read_table_info(self: Self, name: []const u8, schema: DataBaseSchema) !TableInfo {
        //TODO: this whole implementation should be one of the first things to FIX
        var temp_arr = [2][]const u8{
            schema.name,
            name,
        };

        const lookup_name = try std.mem.concat(self.allocator, u8, &temp_arr);
        defer self.allocator.free(lookup_name);

        const option = self.table_lookup.get(lookup_name);

        if (option) |table| {
            return table;
        }
        std.debug.print("Table: \"{s}\" does not exist in table catalog.\n", .{name});
        return TableCatalogError.TableDoesNotExist;
    }
};

pub const TableInfo = struct {
    columns: std.StringHashMap(ColumnInfo),
    name: []const u8,
    schema: DataBaseSchema = .{},

    pub fn init(column_list: []ColumnInfo, name: []const u8, schema: ?DataBaseSchema, allocator: std.mem.Allocator) !TableInfo {
        var columns = std.StringHashMap(ColumnInfo).init(allocator);

        for (column_list) |column| {
            try columns.put(column.name, column);
        }

        return .{
            .columns = columns,
            .name = name,
            .schema = if (schema) |has_schema| has_schema else .{ .name = "global" },
        };
    }
};

pub const ColumnInfo = struct {
    column_type: PrimitiveType,
    name: []const u8,

    pub fn init(column_type: PrimitiveType, name: []const u8) ColumnInfo {
        return .{
            .column_type = column_type,
            .name = name,
        };
    }
};

pub const DataBaseSchema = struct {
    name: []const u8 = "global",
};

//TODO: initialize db catalog from stored state/binary format serialize-deserialize
pub fn init_db_catalog(tables: []TableInfo, allocator: std.mem.Allocator) TableCatalog {
    _ = tables;
    _ = allocator;
}

pub fn create_test_catalog(allocator: std.mem.Allocator) !TableCatalog {
    const table1_column_names = [3][]const u8{ "name", "phone", "id" };
    const table1_column_type = [3]PrimitiveType{ .BYTES, .BYTES, .U64 };
    const table1_name = "users";

    const table2_column_names = [3][]const u8{ "source_id", "title", "id" };
    const table2_column_type = [3]PrimitiveType{ .BYTES, .BYTES, .U64 };
    const table2_name = "content";

    var table_1_columns: [3]ColumnInfo = undefined;
    var table_2_columns: [3]ColumnInfo = undefined;
    var tables_list: [2]TableInfo = undefined;

    for (0..3) |i| {
        table_1_columns[i] = ColumnInfo.init(table1_column_type[i], table1_column_names[i]);
        table_2_columns[i] = ColumnInfo.init(table2_column_type[i], table2_column_names[i]);
    }

    tables_list[0] = try TableInfo.init(table_1_columns[0..], table1_name, null, allocator);
    tables_list[1] = try TableInfo.init(table_2_columns[0..], table2_name, null, allocator);

    const table_catalog = try TableCatalog.init(tables_list[0..], allocator);

    return table_catalog;
}
