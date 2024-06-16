const std = @import("std");

pub const NodeId = u64;
const Leaf = []const u8;
pub const NodeValue = union(enum) { leaf: Leaf, children: std.ArrayList(NodeId) };

pub const NodeIdGenerator = struct {
    const Self = @This();

    current_id: ?NodeId = null,

    pub fn next(self: *Self) NodeId {
        if (self.current_id == null) {
            self.current_id = 0;
        } else {
            self.current_id.? += 1;
        }

        return self.current_id.?;
    }
};

pub const Node = struct {
    const Self = @This();
    pub const Error = error{LeafNodeError};

    value: NodeValue,
    id: NodeId,
    parent_id: ?NodeId = null,

    pub fn init(value: NodeValue, id: NodeId, parent_id: ?NodeId) Self {
        return .{ .value = value, .id = id, .parent_id = parent_id };
    }

    pub fn deinit(self: *Self) void {
        switch (self.value) {
            .children => self.value.children.deinit(),
            else => {},
        }
    }

    pub fn isLeaf(self: *const Self) bool {
        return switch (self.value) {
            .leaf => true,
            else => false,
        };
    }

    pub fn setValue(self: *Self, value: NodeValue) void {
        self.deinit();
        self.value = value;
    }

    pub fn leaf(self: *const Self) Leaf {
        const empty = [_]u8{};

        return switch (self.value) {
            .leaf => self.value.leaf,
            else => &empty,
        };
    }

    pub fn children(self: *const Self) []const NodeId {
        const empty = [_]NodeId{};

        return switch (self.value) {
            .children => self.value.children.items,
            else => &empty,
        };
    }

    pub fn addChild(self: *Self, child_id: NodeId) !void {
        if (self.isLeaf()) {
            return Error.LeafNodeError;
        }

        try self.value.children.append(child_id);
    }

    pub fn clone(self: *Self) !Self {
        const value: NodeValue = switch (self.value) {
            .children => NodeValue{ .children = try self.value.children.clone() },
            else => self.value,
        };

        return .{ .id = self.id, .parent_id = self.parent_id, .value = value };
    }
};

pub const Tree = struct {
    const Self = @This();

    nodes: std.AutoHashMap(NodeId, Node),
    allocator: std.mem.Allocator,
    root_id: ?NodeId = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .nodes = std.AutoHashMap(NodeId, Node).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.nodes.valueIterator();
        while (iterator.next()) |node| {
            node.*.deinit();
        }
        self.nodes.deinit();
    }

    pub fn addNode(self: *Self, node: Node) !void {
        try self.nodes.put(node.id, node);
    }

    pub fn removeNode(self: *Self, node: Node) void {
        var old_node: Node = undefined;

        if (self.nodes.fetchRemove(node.id)) |item| {
            old_node = item.value;
            old_node.deinit();
        }
    }

    pub fn root(self: *Self) ?Node {
        if (self.root_id == null)
            return null;

        return self.nodes.get(self.root_id.?);
    }

    pub fn clone(self: *Self) !Self {
        var copy = std.AutoHashMap(NodeId, Node).init(self.allocator);
        var iterator = self.nodes.iterator();
        var node: *Node = undefined;

        while (iterator.next()) |entry| {
            node = entry.value_ptr;

            try copy.put(node.*.id, try node.*.clone());
        }

        return .{ .nodes = copy, .allocator = self.allocator, .root_id = self.root_id };
    }

    pub fn toString(self: *Self) std.mem.Allocator.Error!std.ArrayList(u8) {
        var i: usize = undefined;
        var result = std.ArrayList(u8).init(self.allocator);
        // NOTE: The null value in the queue is used to denote a ')'
        var stack = std.ArrayList(?Node).init(self.allocator);
        defer stack.deinit();

        try stack.append(self.nodes.get(self.root_id.?).?);

        while (stack.items.len > 0) {
            if (stack.pop()) |current_node| {
                if (current_node.isLeaf()) {
                    try result.appendSlice(current_node.leaf());
                    if (stack.items.len != 0 and stack.getLast() != null)
                        try result.append(' ');
                } else {
                    try result.append('(');
                    try stack.append(null);

                    // Add children in reverse order
                    const children = current_node.children();
                    i = children.len;
                    while (i > 0) : (i -= 1) {
                        try stack.append(self.nodes.get(children[i - 1]).?);
                    }
                }
            } else {
                try result.append(')');
                if (stack.items.len != 0 and stack.getLast() != null)
                    try result.append(' ');
            }
        }

        return result;
    }
};
