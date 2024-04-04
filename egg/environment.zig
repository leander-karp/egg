const std = @import("std");
const NodeId = @import("tree.zig").NodeId;

pub const FunctionValue = struct { args: NodeId, body: NodeId };
pub const EnvironmentValues = union(enum) { string: []const u8, node_id: NodeId, function: FunctionValue };

pub const Environment = struct {
    const Self = @This();
    const Context = std.StringHashMap(EnvironmentValues);

    maps: std.ArrayList(Context),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .maps = std.ArrayList(Context).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.maps.items) |*map| {
            map.deinit();
        }

        self.maps.deinit();
    }

    pub fn createContext(self: *Self) !void {
        try self.maps.insert(0, Context.init(self.allocator));
    }

    pub fn deleteContext(self: *Self) void {
        if (self.maps.items.len > 0) {
            var map = self.maps.orderedRemove(0);

            map.deinit();
        }
    }

    pub fn isFunction(self: *Self, key: []const u8) bool {
        if (self.get(key)) |value| {
            return switch (value) {
                .function => true,
                else => false,
            };
        }
        return false;
    }

    pub fn get(self: *Self, key: []const u8) ?EnvironmentValues {
        for (self.maps.items) |*map| {
            if (map.contains(key)) {
                return map.get(key).?;
            }
        }

        return null;
    }

    pub fn set(self: *Self, key: []const u8, value: EnvironmentValues) !void {
        if (self.maps.items.len == 0) {
            try self.createContext();
        }

        try self.maps.items[0].put(key, value);
    }
};
