const std = @import("std");
const TokenIterator = @import("token_iterator.zig").TokenIterator;
const t = @import("tree.zig");

const LPAREN = TokenIterator.LPAREN;
const RPAREN = TokenIterator.RPAREN;

const SyntaxErrors = error{ MissingLeftParenthesis, MissingRightParenthesis };
pub const ParseErrors = SyntaxErrors || std.mem.Allocator.Error || t.Node.Error;

pub fn parse(program: []const u8, allocator: std.mem.Allocator) ParseErrors!t.Tree {
    var tokens = TokenIterator{ .program = program };
    var id_generator = t.NodeIdGenerator{};
    var tree = t.Tree.init(allocator);
    errdefer tree.deinit();
    var result: ParseErrors!t.Tree = undefined;
    var is_multiline_root_inserted = false;
    var lparen_counter: i64 = 0;
    var new_node: t.Node = undefined;
    var parent: t.Node = undefined;
    var parent_node_id: ?t.NodeId = null;

    while (tokens.next()) |token| {
        if (std.mem.eql(u8, token, LPAREN)) {
            if (!is_multiline_root_inserted and tree.nodes.count() > 0 and lparen_counter == 0) {
                // there have been lists before, but all are closed
                new_node = t.Node.init(t.NodeValue{
                    .children = std.ArrayList(t.NodeId).init(allocator),
                }, id_generator.next(), null);
                // the previous tree must be a child of the new root
                parent = tree.nodes.get(parent_node_id.?).?;
                parent.parent_id = new_node.id;

                try tree.addNode(parent);
                try new_node.addChild(parent_node_id.?);
                try tree.addNode(new_node);

                tree.root_id = new_node.id;
                parent_node_id = new_node.id;

                is_multiline_root_inserted = true;
            }

            new_node = t.Node.init(t.NodeValue{
                .children = std.ArrayList(t.NodeId).init(allocator),
            }, id_generator.next(), parent_node_id);
            try tree.addNode(new_node);

            if (parent_node_id == null) {
                // root node
                tree.root_id = new_node.id;
            } else {
                // update parent
                parent = tree.nodes.get(parent_node_id.?).?;
                try parent.addChild(new_node.id);
                try tree.addNode(parent);
            }

            parent_node_id = new_node.id;
            lparen_counter += 1;
        } else if (parent_node_id != null) {
            if (std.mem.eql(u8, token, RPAREN)) {
                lparen_counter -= 1;

                parent = tree.nodes.get(parent_node_id.?).?;

                if (parent.parent_id) |parent_id| {
                    parent_node_id = parent_id;
                }
            } else {
                parent = tree.nodes.get(parent_node_id.?).?;
                new_node = t.Node.init(t.NodeValue{ .leaf = token }, id_generator.next(), parent_node_id);
                try tree.addNode(new_node);
                try parent.addChild(new_node.id);
                try tree.addNode(parent);
            }
        } else {
            result = SyntaxErrors.MissingLeftParenthesis;
            break;
        }
    }

    if (lparen_counter < 0 or tree.nodes.count() == 0) {
        result = SyntaxErrors.MissingLeftParenthesis;
    } else if (lparen_counter > 0) {
        result = SyntaxErrors.MissingRightParenthesis;
    } else {
        result = tree;
    }

    return result;
}
