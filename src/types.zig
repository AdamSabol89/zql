const std = @import("std");
const column_expression = @import("column_expression.zig");
const BinaryOp = column_expression.BinaryOp;

pub const PrimitiveType = enum(u8) {
    INT64 = 0,
    INT32 = 1,
    U32 = 2,
    U64 = 3,

    BOOLEAN = 4,
    FLOAT32 = 5,
    FLOAT64 = 6,

    BYTES = 7,
    SENTINEL = 8,
};

pub const BinaryOpInfo = struct {
    binary_op: BinaryOp,
    supported_type: []const PrimitiveType,

    const Self = @This();

    pub fn contains(self: *Self, target: PrimitiveType) bool {
        for (self.supported_type) |match_type| {
            if (target == match_type) return true;
        }
        return false;
    }

    // zig fmt: off
    const data: [103]PrimitiveType = .{ 
        //AND
        .BOOLEAN, .SENTINEL, 
        //XOR
        .BOOLEAN, .SENTINEL, 
        //OR
        .BOOLEAN, .SENTINEL, 
        //ADD
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //MUL
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //DIV
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //SUB
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //MOD
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //LTH
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //GTH
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //LTHEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //GTHEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .SENTINEL, 
        //EQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .BOOLEAN, .BYTES, .SENTINEL, 
        //NEQ
        .INT64, .INT32, .U32, .U64, .FLOAT32, .FLOAT64, .BOOLEAN, .BYTES, .SENTINEL, 
        //SHF_RIGHT
        .INT64, .INT32, .U32, .U64, .BYTES,  .SENTINEL, 
        //SHF_LEFT
        .INT64, .INT32, .U32, .U64, .BYTES,  .SENTINEL, 
        //LIKE 
        .BYTES, .SENTINEL,
        //RLIKE 
        .BYTES, .SENTINEL,
    };
    // zig fmt: on

    pub const binary_ops: [19]BinaryOpInfo = generate_binary_ops();

    pub fn generate_binary_ops() [19]BinaryOpInfo {
        comptime var result: [19]BinaryOpInfo = undefined;

        comptime var result_index: u8 = 0;
        comptime var i: usize = 0;
        comptime var prev: usize = 0;

        inline while (i < data.len) {
            if (data[i] == .SENTINEL) {
                result[result_index] = .{
                    .supported_type = data[prev..i],
                    .binary_op = @enumFromInt(result_index),
                };
                result_index += 1;
                prev = i + 1;
            }
            i += 1;
        }
        return result;
    }
};
