const std = @import("std");
const types = @import("types.zig");

const assert = std.debug.assert;
const PrimitiveType = types.PrimitiveType;

pub const BytesBuffer = struct { 
    indices: []BytesBufferMeta,
    payload: []u8,

    pub const BytesBufferMeta = struct {
        offset: u32, 
        length: u32,
    };

    pub fn init(size: usize, bytes_size: ?usize, allocator: std.mem.Allocator) !BytesBuffer { 
        const indices = try allocator.allocWithOptions(BytesBufferMeta, size, 64, null);
        const payload = try allocator.allocWithOptions(u8, bytes_size orelse size, 64, null);

        return .{ 
            .indices = indices,
            .payload = payload, 
        };
    }

    pub fn push_item() void { 

    }

};

pub fn Buffer(buffer_type: PrimitiveType) type {
    const native_type: type = PrimitiveType.get_native_type(buffer_type);

    return struct { 
        payload: []native_type,

        pub fn init(size: usize, bytes_size: ?usize, allocator: std.mem.Allocator) !BytesBuffer { 
            const payload = try allocator.allocWithOptions(native_type, bytes_size orelse size, 64, null);
            return .{ 
                .payload = payload, 
            };
        }
    };
}

fn get_buffer_type(buffer_type: PrimitiveType) type { 
    return switch(buffer_type) {
        .BYTES => BytesBuffer,
        .SENTINEL => blk: {
            std.debug.print("Invalid call on a non native type, either SENTINEL or BYTES \n");
            assert(false); 
            break :blk bool;
        },
        else => BufferBuilder(buffer_type)
    };
}

// Used for building unknown length buffers
pub fn BufferBuilder(prim_type: PrimitiveType) type { 
    switch(prim_type) { 
        .BYTES => { 
            return struct{ 
                const Self = @This();
                const PayloadResizable = std.ArrayList(u8);
                const BytesBufferMetaResizable = std.ArrayList(BytesBuffer.BytesBufferMeta);

                payload: PayloadResizable, 
                metadata: BytesBufferMetaResizable, 

                // Copies the input buffer into the payload and creates an entry in the size buffer
                fn push_element(self: *Self, data: []const u8) !void { 
                    const offset: u32 = @intCast(self.metadata.len);
                    const length: u32 = @intCast(data.len);

                    try self.payload.appendSlice(data);
                    try self.metadata.append(.{.offset=offset, .length = length});
                }

                // Copies the input buffers into the payload and creates an entry in the size buffer
                fn push_elements(self: *Self, data: [][]const u8) !void {
                    for (data) |buffer| {
                        const offset: u32 = @intCast(self.metadata.len);
                        const length: u32 = @intCast(buffer.len);

                        try self.payload.appendSlice(buffer);
                        try self.metadata.append(.{.offset=offset, .length = length});
                    }
                }

                fn push_null_element(self: *Self) void {
                    try self.metadata.append(.{.offset = 0, .length = 0});
                }

                // TODO: we have to transfer to an owned slice to avoid mem leak, 
                // idea: custom allocator, buffer size (items) is known, payload is like vec
                // but remaining mem is returned to the allocator after buffer is built
                fn seal(self: *Self) BytesBuffer {
                    const result = BytesBuffer{ 
                        .payload = try self.payload.toOwnedSlice(),
                        .indices = try self.metadata.toOwnedSlice(),
                    };

                    self.payload.deinit(); 
                    self.metadata.deinit();

                    return result;
                }

            };

        }, 
        .SENTINEL => { 
            std.debug.print("Invalid call on a non native type, either SENTINEL or BYTES \n");
            assert(false); 
        },
        else => { 

        }
    }
}
