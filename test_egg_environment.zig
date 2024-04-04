const std = @import("std");
const egg = @import("egg.zig");
const expect = std.testing.expect;

test "createContext" {
    var env = egg.Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.createContext();
    try env.createContext();

    try expect(env.maps.items.len == 2);
}

test "deleteContext" {
    var env = egg.Environment.init(std.testing.allocator);
    defer env.deinit();

    env.deleteContext();

    try env.createContext();

    env.deleteContext();
    try expect(env.maps.items.len == 0);
}

test "set" {
    var env = egg.Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.set("a", egg.EnvironmentValues{ .string = "silence" });

    try expect(std.mem.eql(u8, env.get("a").?.string, "silence"));
}

test "get" {
    var env = egg.Environment.init(std.testing.allocator);
    defer env.deinit();

    try expect(env.get("a") == null);

    try env.set("a", egg.EnvironmentValues{ .string = "silence" });
    try expect(std.mem.eql(u8, env.get("a").?.string, "silence"));

    try env.createContext();

    try env.set("a", egg.EnvironmentValues{ .string = "sky" });
    try expect(std.mem.eql(u8, env.get("a").?.string, "sky"));

    env.deleteContext();
    try expect(std.mem.eql(u8, env.get("a").?.string, "silence"));
}

test "isFunction" {
    var env = egg.Environment.init(std.testing.allocator);
    defer env.deinit();

    try env.set("a", egg.EnvironmentValues{ .string = "silence" });
    try env.set("b", egg.EnvironmentValues{ .function = egg.FunctionValue{ .args = 4, .body = 5 } });

    try expect(false == env.isFunction("a"));
    try expect(true == env.isFunction("b"));
    try expect(false == env.isFunction("c"));
}
