const std = @import("std");
const parser = @import("parser.zig");
const t = @import("tree.zig");
const env = @import("environment.zig");

pub const EvaluationErrors = error{
    UndefinedAtom,
    TooManyArguments,
    MissingArguments,
    ListArgumentExpected,
    InvalidVariableName,
    InvalidFunctionDefinition,
};

pub const Interpreter = struct {
    const Self = @This();

    program: []const u8,
    environment: env.Environment,
    allocator: std.mem.Allocator,
    stack: std.ArrayList(t.NodeId),
    evaluated_nodes: std.ArrayList(t.NodeId),
    current_node: t.Node = undefined,
    result: t.Tree = undefined,
    original_result: ?t.Tree = null,

    pub fn init(program: []const u8, allocator: std.mem.Allocator) Self {
        return .{
            .program = program,
            .allocator = allocator,
            .environment = env.Environment.init(allocator),
            .stack = std.ArrayList(t.NodeId).init(allocator),
            .evaluated_nodes = std.ArrayList(t.NodeId).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.environment.deinit();
        self.stack.deinit();
        self.evaluated_nodes.deinit();
    }

    pub fn run(self: *Self) !std.ArrayList(u8) {
        self.result = try parser.parse(self.program, self.allocator);
        defer self.result.deinit();

        try self.stack.append(self.result.root_id.?);

        while (self.stack.items.len > 0) {
            self.current_node = self.result.nodes.get(self.stack.pop()).?;
            const children = self.current_node.children();

            if (self.current_node.isLeaf()) {
                try self.handle_variables();
            } else if (children.len == 0) {
                try self.handle_nil();
            } else {
                try self.handle_keywords(children);
            }
        }

        return self.result.toString();
    }

    fn handle_variables(self: *Self) !void {
        if (self.environment.get(self.current_node.leaf())) |env_value| {
            switch (env_value) {
                .string => self.current_node.value = t.NodeValue{ .leaf = env_value.string },
                .node_id => {
                    const node = self.result.nodes.get(env_value.node_id).?;
                    self.current_node.value = t.NodeValue{ .children = try node.value.children.clone() };
                },
                .function => {
                    // NOTE: Functions are handled in another code path
                },
            }

            try self.result.addNode(self.current_node);
        } else {
            return EvaluationErrors.UndefinedAtom;
        }
    }

    fn handle_keywords(self: *Self, children: []const t.NodeId) !void {
        const keyword = self.get_child(0).leaf();

        if (std.mem.eql(u8, keyword, "quote")) {
            try self.handle_quote();
        } else if (std.mem.eql(u8, keyword, "eq")) {
            try self.handle_eq();
        } else if (std.mem.eql(u8, keyword, "car")) {
            try self.handle_car();
        } else if (std.mem.eql(u8, keyword, "cdr")) {
            try self.handle_cdr();
        } else if (std.mem.eql(u8, keyword, "cons")) {
            try self.handle_cons();
        } else if (std.mem.eql(u8, keyword, "if")) {
            try self.handle_if();
        } else if (std.mem.eql(u8, keyword, "atom")) {
            try self.handle_atom();
        } else if (std.mem.eql(u8, keyword, "let")) {
            try self.handle_let();
        } else if (std.mem.eql(u8, keyword, "def")) {
            try self.handle_def();
        } else if (self.environment.isFunction(keyword)) {
            try self.handle_function_call();
        } else {
            // Add children in reversed order
            var index: usize = undefined;

            for (0..children.len) |i| {
                index = children.len - i - 1;
                try self.stack.append(children[index]);
            }
        }
    }

    fn get_child(self: *Self, index: usize) t.Node {
        return self.result.nodes.get(self.current_node.children()[index]).?;
    }

    fn check_list_lengths(actual_length: usize, expected_length: usize) !void {
        if (actual_length > expected_length) {
            return EvaluationErrors.TooManyArguments;
        } else if (actual_length < expected_length) {
            return EvaluationErrors.MissingArguments;
        }
    }

    fn handle_nil(self: *Self) !void {
        const nil = t.Node.init(t.NodeValue{ .leaf = "nil" }, self.current_node.id, self.current_node.parent_id);

        self.result.removeNode(self.current_node);
        try self.result.addNode(nil);
    }

    fn handle_quote(self: *Self) !void {
        try check_list_lengths(self.current_node.children().len, 2);

        self.result.removeNode(self.get_child(0));
        const second_child_id = self.current_node.children()[1];

        if (self.current_node.parent_id == null) {
            self.result.root_id = second_child_id;
            self.result.removeNode(self.current_node);
        } else {
            var second_child = self.get_child(1);

            second_child.id = self.current_node.id;

            self.result.removeNode(self.current_node);

            _ = self.result.nodes.remove(second_child_id);
            try self.result.addNode(second_child);
        }
    }

    fn handle_eq(self: *Self) !void {
        // The eq function is defined as t if the value of its two arguments evaluates to the same atom.
        const children = self.current_node.children();

        try check_list_lengths(children.len, 3);

        if (self.contains(self.current_node.id)) {
            const a = self.get_child(1);
            const b = self.get_child(2);
            const value = t.NodeValue{ .leaf = if (a.isLeaf() and std.mem.eql(u8, a.leaf(), b.leaf())) "t" else "f" };

            try self.result.addNode(t.Node.init(value, self.current_node.id, self.current_node.parent_id));
            self.result.removeNode(self.get_child(0));
            self.result.removeNode(a);
            self.result.removeNode(b);
            self.current_node.deinit();
        } else {
            try self.stack.append(self.current_node.id);
            // add children in reverse order, except for the first one (the 'eq' leaf)
            for (0..(children.len - 1)) |i| {
                try self.stack.append(children[children.len - i - 1]);
            }
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_car(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 2);

        if (self.contains(self.current_node.id)) {
            const list = self.result.nodes.get(children[1]).?;
            if (list.isLeaf()) {
                return EvaluationErrors.ListArgumentExpected;
            } else if (list.children().len == 0) {
                try self.handle_nil();
            } else {
                const item = self.result.nodes.get(list.children()[0]).?;

                try self.result.addNode(t.Node.init(item.value, self.current_node.id, self.current_node.parent_id));
                self.result.removeNode(self.get_child(0));
                self.result.removeNode(list);
                self.current_node.deinit();
            }
        } else {
            try self.stack.append(self.current_node.id);
            try self.stack.append(children[1]);
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_cdr(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 2);

        if (self.contains(self.current_node.id)) {
            var second_child = self.get_child(1);

            if (second_child.isLeaf()) {
                return EvaluationErrors.ListArgumentExpected;
            } else if (second_child.children().len <= 1) {
                try self.handle_nil();
            } else {
                const item = self.result.nodes.get(second_child.value.children.orderedRemove(0)).?;

                try self.result.addNode(t.Node.init(t.NodeValue{ .children = try second_child.value.children.clone() }, self.current_node.id, self.current_node.parent_id));
                self.result.removeNode(self.get_child(0));
                self.result.removeNode(item);
                self.result.removeNode(second_child);
                self.current_node.deinit();
            }
        } else {
            try self.stack.append(self.current_node.id);
            try self.stack.append(children[1]);
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_cons(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 3);

        if (self.contains(self.current_node.id)) {
            const a = self.get_child(1);
            const b = self.get_child(2);

            self.result.removeNode(self.get_child(0));
            _ = self.current_node.value.children.orderedRemove(0);

            if (!a.isLeaf() or std.mem.eql(u8, a.leaf(), "nil")) {
                _ = self.current_node.value.children.orderedRemove(std.mem.indexOfScalar(
                    t.NodeId,
                    self.current_node.value.children.items,
                    a.id,
                ).?);
                for (a.children()) |child_id| {
                    try self.current_node.addChild(child_id);
                    var child = self.result.nodes.get(child_id).?;
                    child.parent_id = self.current_node.id;
                    try self.result.addNode(child);
                }
                self.result.removeNode(a);
            }
            if (!b.isLeaf() or std.mem.eql(u8, b.leaf(), "nil")) {
                _ = self.current_node.value.children.orderedRemove(std.mem.indexOfScalar(
                    t.NodeId,
                    self.current_node.value.children.items,
                    b.id,
                ).?);
                for (b.children()) |child_id| {
                    try self.current_node.addChild(child_id);
                    var child = self.result.nodes.get(child_id).?;
                    child.parent_id = self.current_node.id;
                    try self.result.addNode(child);
                }
                self.result.removeNode(b);
            }

            if (self.current_node.children().len == 0) {
                try self.handle_nil();
            } else {
                try self.result.addNode(self.current_node);
            }
        } else {
            try self.stack.append(self.current_node.id);
            // add children in reverse order, except for the first one (the 'cons' leaf)
            for (0..(children.len - 1)) |i| {
                try self.stack.append(children[children.len - i - 1]);
            }
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_if(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 4);

        var condition = self.get_child(1);
        var a = self.get_child(2);
        var b = self.get_child(3);
        const evaluation_count = self.count(self.current_node.id);

        if (evaluation_count < 2) {
            if (evaluation_count == 0) {
                // first roundtrip: evaluate condition
                try self.stack.append(self.current_node.id);
                try self.stack.append(condition.id);
                try self.evaluated_nodes.append(self.current_node.id);
            } else {
                // second roundtrip: evaluate based on condition
                try self.stack.append(self.current_node.id);
                if (std.mem.eql(u8, condition.leaf(), "t")) {
                    try self.stack.append(a.id);
                } else {
                    try self.stack.append(b.id);
                }
                try self.evaluated_nodes.append(self.current_node.id);
            }
        } else {
            var new_node: t.Node = undefined;

            if (std.mem.eql(u8, condition.leaf(), "t")) {
                new_node = try a.clone();
            } else {
                new_node = try b.clone();
            }
            new_node.id = self.current_node.id;
            new_node.parent_id = self.current_node.parent_id;

            try self.result.addNode(new_node);
            self.result.removeNode(a);
            self.result.removeNode(b);
            self.result.removeNode(self.get_child(0));
            self.result.removeNode(condition);
            self.current_node.deinit();
        }
    }

    fn handle_atom(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 2);
        const second_child = self.get_child(1);

        if (self.contains(self.current_node.id)) {
            const result_node = t.Node.init(t.NodeValue{ .leaf = if (second_child.isLeaf()) "t" else "f" }, self.current_node.id, self.current_node.parent_id);

            self.result.removeNode(self.get_child(0));
            self.result.removeNode(self.current_node);
            self.result.removeNode(second_child);

            try self.result.addNode(result_node);
        } else {
            try self.stack.append(self.current_node.id);
            try self.stack.append(second_child.id);
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_let(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 3);

        if (self.contains(self.current_node.id)) {
            const varname = self.get_child(1);

            if (!varname.isLeaf()) return EvaluationErrors.InvalidVariableName;

            const varvalue = self.get_child(2);
            var value: env.EnvironmentValues = undefined;

            if (varvalue.isLeaf()) {
                value = env.EnvironmentValues{ .string = varvalue.leaf() };
                self.result.removeNode(varvalue);
            } else {
                value = env.EnvironmentValues{ .node_id = varvalue.id };
            }

            try self.environment.set(varname.leaf(), value);

            self.result.removeNode(self.get_child(0));
            self.result.removeNode(varname);

            if (self.current_node.parent_id == null) {
                try self.handle_nil();
            } else {
                var parent = self.result.nodes.get(self.current_node.parent_id.?).?;
                var index = std.mem.indexOfScalar(t.NodeId, parent.children(), self.current_node.id).?;

                _ = parent.value.children.orderedRemove(index);

                self.result.removeNode(self.current_node);
                try self.result.addNode(parent);
            }
        } else {
            try self.stack.append(self.current_node.id);
            try self.stack.append(children[1]);
            try self.stack.append(children[2]);
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn handle_def(self: *Self) !void {
        const children = self.current_node.children();

        try check_list_lengths(children.len, 4);

        const name = children[1];
        const args = children[2];
        const body = children[3];
        const is_invalid = (!self.result.nodes.get(name).?.isLeaf() or
            self.result.nodes.get(args).?.isLeaf() or
            !self.are_all_children_leaves(self.result.nodes.get(args).?.children()));

        if (is_invalid) {
            return EvaluationErrors.InvalidFunctionDefinition;
        }

        try self.environment.set(
            self.result.nodes.get(name).?.leaf(),
            env.EnvironmentValues{
                .function = env.FunctionValue{ .args = args, .body = body },
            },
        );

        if (self.current_node.parent_id == null) {
            try self.handle_nil();
        } else {
            var parent = self.result.nodes.get(self.current_node.parent_id.?).?;
            var index = std.mem.indexOfScalar(t.NodeId, parent.children(), self.current_node.id).?;

            _ = parent.value.children.orderedRemove(index);

            self.result.removeNode(self.current_node);
            try self.result.addNode(parent);
        }
    }

    fn handle_function_call(self: *Self) !void {
        const children = self.current_node.children();
        const function = self.environment.get(self.result.nodes.get(children[0]).?.leaf()).?.function;
        var index: usize = undefined;

        if (self.count(self.current_node.id) == 3) {
            // set result
            self.current_node = self.original_result.?.nodes.get(self.current_node.id).?;
            self.current_node.setValue(self.result.nodes.get(function.body).?.value);
            self.result.deinit();
            self.result = self.original_result.?;
            // delete context
            self.environment.deleteContext();
            try self.result.addNode(self.current_node);
            // remove body from evaluated nodes
        } else if (self.count(self.current_node.id) == 2) {
            // execute body in context
            self.original_result = self.result;
            self.result = try self.original_result.?.clone();

            try self.stack.append(self.current_node.id);
            try self.stack.append(function.body);
            try self.evaluated_nodes.append(self.current_node.id);
        } else if (self.count(self.current_node.id) == 1) {
            // bind arg values in new context
            try self.environment.createContext();
            const value_node_ids = children[1..];
            const argument_node_ids = self.result.nodes.get(function.args).?.children();
            var node: t.Node = undefined;
            var value: env.EnvironmentValues = undefined;

            try check_list_lengths(value_node_ids.len, argument_node_ids.len);

            for (argument_node_ids, 0..) |arg_node_id, i| {
                node = self.result.nodes.get(value_node_ids[i]).?;
                value = switch (node.value) {
                    .leaf => env.EnvironmentValues{ .string = node.leaf() },
                    .children => env.EnvironmentValues{ .node_id = node.id },
                };
                try self.environment.set(
                    self.result.nodes.get(arg_node_id).?.leaf(),
                    value,
                );
            }
            try self.stack.append(self.current_node.id);
            try self.evaluated_nodes.append(self.current_node.id);
        } else {
            // eval arg values
            try self.stack.append(self.current_node.id);
            for (0..children.len) |i| {
                index = children.len - i - 1;
                try self.stack.append(children[index]);
            }
            try self.evaluated_nodes.append(self.current_node.id);
        }
    }

    fn are_all_children_leaves(self: *Self, children: []const t.NodeId) bool {
        for (children) |child| {
            if (!self.result.nodes.get(child).?.isLeaf()) return false;
        }
        return true;
    }

    fn contains(self: *Self, search_item: t.NodeId) bool {
        return std.mem.indexOfScalar(t.NodeId, self.evaluated_nodes.items, search_item) != null;
    }

    fn count(self: *Self, search_item: t.NodeId) u64 {
        var item_index: ?usize = undefined;
        var current_index: usize = 0;
        var occurrences: u64 = 0;
        const len = self.evaluated_nodes.items.len;

        while (current_index < len) {
            item_index = std.mem.indexOfScalarPos(t.NodeId, self.evaluated_nodes.items, current_index, search_item);

            current_index = (item_index orelse len) + 1;
            occurrences += @intFromBool(item_index != null);
        }

        return occurrences;
    }
};
