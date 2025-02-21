const std = @import("std");
const assert = std.debug.assert;

pub const TablesTable = std.StringHashMap(Table);

pub const Table = struct {
    name: []const u8,
    columns: [][]const u8,

    const Self = @This();

    pub fn initOwned(name: []const u8, columns: [][]const u8, allocator: std.mem.Allocator) !Table {
        const owned_table_name = try allocator.alloc(u8, name.len);
        std.mem.copyForwards(u8, owned_table_name, name);

        var total_len: usize = 0;

        for (columns) |col| {
            total_len += col.len;
        }

        const table_names = try allocator.alloc(u8, total_len);

        var next: [*]u8 = table_names.ptr;

        var new_columns = try allocator.alloc([]u8, columns.len);

        for (columns, 0..columns.len) |col, i| {
            const owned_col_name = next[0..col.len];
            std.mem.copyForwards(u8, owned_col_name, col);

            new_columns[i] = owned_col_name;

            next = next + col.len;
        }

        return .{
            .name = owned_table_name,
            .columns = new_columns,
        };
    }

    pub fn deinitOwned(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.name);

        if (self.columns.len > 0) {
            const start: [*]const u8 = self.columns[0].ptr;

            var total_len: usize = 0;

            for (self.columns) |col| {
                total_len += col.len;
            }

            const free_slice = start[0..total_len];
            allocator.free(free_slice);
        }

        allocator.free(self.columns);
    }
};

pub fn initTablesTable(tables: []const []const u8, columns: [][][]const u8, allocator: std.mem.Allocator) !TablesTable {
    assert(tables.len == columns.len);

    var tables_table = TablesTable.init(allocator);

    for (0..tables.len) |i| {
        const table = try Table.initOwned(tables[i], columns[i], allocator);
        try tables_table.put(tables[i], table);
    }

    return tables_table;
}

pub fn deinitTablesTable(tables_table: *TablesTable, allocator: std.mem.Allocator) void {
    var table_iter = tables_table.valueIterator();

    while (table_iter.next()) |table| {
        table.deinitOwned(allocator);
    }

    tables_table.deinit();
}

pub fn initTestTables(allocator: std.mem.Allocator) !TablesTable {
    const tables = [_][]const u8{ "users", "columns" };

    var first_table_columns = [_][]const u8{ "id", "name", "phone" };
    var second_table_columns = [_][]const u8{ "id", "name", "create_date" };

    var all_columns: [2][][]const u8 = undefined;

    all_columns[0] = first_table_columns[0..];
    all_columns[1] = second_table_columns[0..];

    const tables_table = try initTablesTable(tables[0..], all_columns[0..], allocator);
    return tables_table;
}

test "create test tables table" {
    const allocator = std.testing.allocator;

    var tables_table = try initTestTables(allocator);
    defer deinitTablesTable(&tables_table, allocator);

    const users = tables_table.get("users");
    try std.testing.expect(std.mem.eql(u8, users.?.name, "users"));
}

test "create table" {
    const allocator = std.testing.allocator;
    const table_name = "idk";
    var col_names = [_][]const u8{ "hello", "world" };

    var table = try Table.initOwned(table_name[0..], col_names[0..], allocator);
    defer table.deinitOwned(allocator);
}
