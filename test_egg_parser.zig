const std = @import("std");
const egg = @import("egg.zig");
const expect = std.testing.expect;

fn childrenOf(tree: egg.Tree, node: egg.Node) !std.ArrayList(egg.Node) {
    var result = std.ArrayList(egg.Node).init(tree.allocator);

    if (!node.isLeaf()) {
        for (node.children()) |child_id| {
            try result.append(tree.nodes.get(child_id).?);
        }
    }

    return result;
}

test "parse single atomic value" {
    var tree = try egg.parse("(atomic)", std.testing.allocator);
    defer tree.deinit();

    try expect(tree.nodes.count() == 2);

    var root = tree.root().?;

    try expect(root.parent_id == null);
    try expect(root.children().len == 1);
    try expect(root.children()[0] == 1);
    try expect(std.mem.eql(u8, tree.nodes.get(1).?.value.leaf, "atomic"));
}

test "parse empty list" {
    var tree = try egg.parse("()", std.testing.allocator);
    defer tree.deinit();

    try expect(tree.nodes.count() == 1);

    var root = tree.root().?;

    try expect(root.value.children.items.len == 0);
}

test "parse multiple atomic values" {
    var tree = try egg.parse("(\natomic1\tatomic2\ratomic3 atomic4)\n\n", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;
    var children = try childrenOf(tree, root);
    defer children.deinit();

    try expect(tree.nodes.count() == 5);
    try expect(std.mem.eql(u8, children.items[0].leaf(), "atomic1"));
    try expect(std.mem.eql(u8, children.items[1].leaf(), "atomic2"));
    try expect(std.mem.eql(u8, children.items[2].leaf(), "atomic3"));
    try expect(std.mem.eql(u8, children.items[3].leaf(), "atomic4"));
}

test "parse nested lists" {
    var tree = try egg.parse("(atomic1 ((atomic2) atomic3))", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;
    var children = try childrenOf(tree, root);
    errdefer children.deinit();

    try expect(tree.nodes.count() == 6);
    try expect(children.items.len == 2);
    try expect(std.mem.eql(u8, children.items[0].leaf(), "atomic1"));

    root = children.items[1];
    children.deinit();
    children = try childrenOf(tree, root);

    try expect(children.items.len == 2);
    try expect(std.mem.eql(u8, children.items[1].leaf(), "atomic3"));

    root = children.items[0];
    children.deinit();
    children = try childrenOf(tree, root);

    try expect(children.items.len == 1);
    try expect(std.mem.eql(u8, children.items[0].leaf(), "atomic2"));

    children.deinit();
}

test "parse empty string" {
    _ = egg.parse("", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingLeftParenthesis);
        return;
    };
    unreachable;
}

test "parse with missing lparen" {
    _ = egg.parse(")", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingLeftParenthesis);
        return;
    };
    unreachable;
}

test "parse atomic with missing lparen" {
    _ = egg.parse("atomic)", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingLeftParenthesis);
        return;
    };
    unreachable;
}

test "parse with missing rparen" {
    _ = egg.parse("(", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingRightParenthesis);
        return;
    };
    unreachable;
}

test "parse with multiple missing rparen" {
    _ = egg.parse("(((", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingRightParenthesis);
        return;
    };
    unreachable;
}

test "parse multiple atomics with missing rparen" {
    _ = egg.parse("(let ((a b (c d", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingRightParenthesis);
        return;
    };
    unreachable;
}

test "parse multiline lisp" {
    var tree = try egg.parse("(a)\n(b c)\n(d e)", std.testing.allocator);
    defer tree.deinit();

    var root = tree.root().?;
    var root_children = try childrenOf(tree, root);
    defer root_children.deinit();

    try expect(tree.nodes.count() == 9);
    try expect(root.children().len == 3);

    // (a)
    var child = root_children.items[0];

    try expect(child.children().len == 1);

    child = tree.nodes.get(child.children()[0]).?;

    try expect(std.mem.eql(u8, child.leaf(), "a"));

    // (b c)
    child = root_children.items[1];
    var children = try childrenOf(tree, child);

    try expect(std.mem.eql(u8, children.items[0].leaf(), "b"));
    try expect(std.mem.eql(u8, children.items[1].leaf(), "c"));

    children.deinit();

    // (d e)
    child = root_children.items[2];
    children = try childrenOf(tree, child);

    defer children.deinit();

    try expect(std.mem.eql(u8, children.items[0].leaf(), "d"));
    try expect(std.mem.eql(u8, children.items[1].leaf(), "e"));
}

test "parse multiline lisp with missing lparen" {
    _ = egg.parse("(a)\n(b c)\nd e)", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingLeftParenthesis);
        return;
    };
    unreachable;
}

test "parse multiline lisp with missing rparen" {
    _ = egg.parse("()\n(b c", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingRightParenthesis);
        return;
    };
    unreachable;
}

test "parse single comment line" {
    var tree = try egg.parse("# comment 1\n()", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;

    try expect(root.children().len == 0);
}

test "parse single comment line at the end" {
    var tree = try egg.parse("()# comment 1", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;

    try expect(root.children().len == 0);
}

test "parse comment lines" {
    var tree = try egg.parse("# comment 1\n#comment 2\n#\n#comment3\n()###\n#a b", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;

    try expect(root.children().len == 0);
}

test "parse interwoven spaces and comments" {
    var tree = try egg.parse("   # comment 1\n\t\t\n  \n#comment 2#comment3\n  ( # blah\n ) ", std.testing.allocator);
    defer tree.deinit();
    var root = tree.root().?;

    try expect(root.children().len == 0);
}

test "parse fails on interwoven spaces and comments without code" {
    _ = egg.parse("   # comment 1\n  \n  \n#comment 2#comment3\n   ", std.testing.allocator) catch |e| {
        try expect(e == egg.ParseErrors.MissingLeftParenthesis);
        return;
    };

    unreachable;
}

test "Tree#toString" {
    const program =
        \\ # The function assoc
        \\
        \\ (defun assoc (var lst)
        \\   (cond ((eq (caar lst) var) (cadar lst))
        \\ ((quote (t (assoc var (cdr lst)))))))
    ;
    var tree = try egg.parse(program, std.testing.allocator);
    defer tree.deinit();
    var string = try tree.toString();
    defer string.deinit();

    try expect(std.mem.eql(u8, string.items, "(defun assoc (var lst) (cond ((eq (caar lst) var) (cadar lst)) ((quote (t (assoc var (cdr lst)))))))"));
}

test "Tree#clone" {
    const program = "(a (b c d) (e (f)))";
    var tree = try egg.parse(program, std.testing.allocator);
    var copy = try tree.clone();
    defer copy.deinit();
    var string = try copy.toString();
    defer string.deinit();

    tree.deinit();

    try expect(std.mem.eql(u8, string.items, program));
}
