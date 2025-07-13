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

//test "test table context " {
//    var buffer: [10000]u8 = undefined;
//    var fba = std.heap.FixedBufferAllocator.init(buffer[0..]);
//    const root_allocator = fba.allocator();
//
//    var arena = std.heap.ArenaAllocator.init(root_allocator);
//    const allocator = arena.allocator();
//    defer arena.deinit();
//
//    const table_catalog = try ctg.create_test_catalog(allocator);
//    var users_table = try table_catalog.read_table_info("users", .{});
//
//    const t_ctx: binder.TableContext = .{ .table_info = &users_table, .alias = "usrs" };
//    var arr = [1]binder.TableContext{t_ctx};
//    var q_ctx = binder.QueryContext.init(arr[0..], allocator);
//
//    const col_detail = binder.parse_as_identifier("usrs.id");
//    const col_info = binder.bind_identifier();
//    const col_info = q_ctx.try_read_identifier(col_detail);
//    const val = col_info.?;
//
//    std.debug.print("if exists {s}\n", .{val.column_info.name});
//
//    //assert(std.mem.eql(ctg.TableInfo, tbl_context.?.table_info.*, users_table));
//}

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
    const identifier_info = binder.parse_as_identifier(test_ident_name);
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


test "test parse header" { 
    //const header = "COLUMN1|COLUMN2|COLUMN3|COLUMN4|SUPAEXTRADUUUUUUUUPAAAAAALONGEEXTRALONGVERYVERYVERYLONGCOLUMNNAMETHATGOESONANDONANDONANDONANDONANDONCOLUMN|ANOTHERREALLYLONGCOLUMNNAMETHATISACTUALLYNOTTHATLONGBUTMIGHTLOOKKINDOFLONGBECAUSEYEAH|COLUMN7";
    const sep = '|';
    const all_sep = [_]u8{sep} ** 64;
    const header = "COLUMN1|COLUMN2|COLUMN3|COLUMN4|COLUMN5|COLUMN12|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    //const escaped_escaped= \\ COLUMN1\\|COLUMN2|COLUMN3\|COLUMN4|COLUMN5|COLUMN12|AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    //    ;
    
    
    //const header = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    var offset: usize = 0; 
    offset = 0;

    const u8_64width_vec = @Vector(64, u8);
    const inst_vec: u8_64width_vec = header[offset..][0..64].*;
    const sep_vec: u8_64width_vec = all_sep;


    const bitmask: u64 = @bitCast(inst_vec == sep_vec); 
    const sep_index: u64 = @ctz(bitmask);
    std.debug.print("byte values {d} \n", .{sep_index});

    const index_bool: bool = sep_index == 0;
    const index: usize = @intFromBool(index_bool);

    std.debug.print("something {d} \n", .{index});
}

test "bitshift" { 
    const test_val: usize = 0b0000;
    const result: usize = @ctz(test_val);

    const shift_result: usize = test_val >> @truncate(result);
    std.debug.print("ctz result: {b}\n", .{shift_result});
}
 
test "negative test" { 
    const neg_one: isize = -1;
    const index: isize = 100; 
    const result: isize = neg_one + index;
    const neg_one_small: i1 = @truncate(result);

    std.debug.print("somethign {d}\n", .{neg_one_small});
}
