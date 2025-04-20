const std = @import("std");
const tokenizer = @import("main.zig");
const parser = @import("parser.zig");
const ctg = @import("table_catalog.zig");
const types = @import("types.zig");
const binder = @import("binder.zig");

const BinaryOpInfo = types.BinaryOpInfo;
const SOA_token = tokenizer.SOA_token;
const Scanner = tokenizer.Scanner;
const PrimitiveType = types.PrimitiveType;
const assert = std.debug.assert;

const query =
    \\SELECT  
    \\    users.name + users.phone,  
    \\    FUNCTION(users.name , users.phone) 
    \\ --THIS IS A COMMENT 
    \\ FROM users
    //\\ JOIN content ON users.content_id = content.id
    //\\ WHERE users.id = 12
    //\\ LIMIT 100;
;

test "read a token properly" {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const root_allocator = fba.allocator();

    var arena = std.heap.ArenaAllocator.init(root_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    var soa_token: SOA_token = .{};
    var scanner = try Scanner.init(&soa_token, query, allocator);
    defer scanner.deinit(allocator);

    const start = std.time.nanoTimestamp();
    try scanner.tokenize(allocator);
    const end = std.time.nanoTimestamp();
    std.debug.print("time to tokenize {d}\n", .{end - start});

    defer soa_token.deinit(allocator);

    const t1 = soa_token.get(0);
    std.debug.print("{s}\n", .{t1.info.lexeme});
    std.debug.print("{d}\n", .{@intFromEnum(t1.type)});
    try parser.parse_query(soa_token, allocator);
}

test "test table catalog" {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const root_allocator = fba.allocator();

    var arena = std.heap.ArenaAllocator.init(root_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const table_catalog = try ctg.create_test_catalog(allocator);

    const table_test_result = table_catalog.read_table_info("blah", .{});
    assert(table_test_result == ctg.TableCatalogError.TableDoesNotExist);
    const users_table = try table_catalog.read_table_info("users", .{});

    const id_column = users_table.columns.get("id").?;
    assert(id_column.column_type == .U64);
}

test "test table context " {
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const root_allocator = fba.allocator();

    var arena = std.heap.ArenaAllocator.init(root_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    const table_catalog = try ctg.create_test_catalog(allocator);
    var users_table = try table_catalog.read_table_info("users", .{});

    const t_ctx: binder.TableContext = .{ .table_info = &users_table, .alias = "usrs" };
    var arr = [1]binder.TableContext{t_ctx};
    var q_ctx = binder.Context.init(arr[0..]);

    const col_detail = binder.read_as_identifier("usrs.id");
    const col_info = q_ctx.try_read_identifier(col_detail);
    const val = col_info.?;

    std.debug.print("if exists {s}\n", .{val.column_info.name});

    //assert(std.mem.eql(ctg.TableInfo, tbl_context.?.table_info.*, users_table));
}

test "generate binary ops" {
    const test_val = BinaryOpInfo.binary_ops[1];
    std.debug.print("{any}\n", .{test_val});
}

test "add binary opp" {
    const test_types: [3]PrimitiveType = .{ .INT64, .INT32, .U32 };

    const something = .{ .binary_op = .AND, .supported_type = test_types[0..] };
    _ = something;
}

test "count identifiers" {
    const test_ident_name = "schema1.users.id";

    const num_identifiers = binder.count_identifiers_in_path(test_ident_name);
    assert(num_identifiers == 3);
}

test "parse identifier" {
    const test_ident_name = "schema1.users.id";
    const identifier_info = binder.read_as_identifier(test_ident_name);
    assert(std.mem.eql(u8, identifier_info.column, "id"));
}

test "column expression binder" {}

test "vector addition" {
    const slice_i32 = [16]i32{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100 };
    const slice_i32_2 = [16]i32{ 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100 };

    const vector_i32: @Vector(16, i32) = slice_i32;
    const vector_i32_2: @Vector(16, i32) = slice_i32_2;

    const vector_3 = vector_i32 + vector_i32_2;

    const slice_result: [16]i32 = vector_3;

    assert(slice_result[0] == 200);
}
