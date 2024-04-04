const std = @import("std");
const egg = @import("egg.zig");
const expect = std.testing.expect;

// quote
test "interpret axiom quote with atom" {
    var interpreter = egg.Interpreter.init("(quote a)", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "a"));
}

test "interpret axiom quote with list" {
    var interpreter = egg.Interpreter.init("(quote (a (b (c) d)))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(a (b (c) d))"));
}

test "interpret quotes with atoms" {
    var interpreter = egg.Interpreter.init("((quote a) (quote b))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(a b)"));
}

test "interpret axiom quote without argument" {
    var interpreter = egg.Interpreter.init("(quote)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };

    unreachable;
}

test "interpret axiom quote with too many arguments" {
    var interpreter = egg.Interpreter.init("(quote a b)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };

    unreachable;
}

// eq tests
test "interpret axiom eq" {
    const program =
        \\((eq (quote a) (quote a))
        \\ (eq (quote a) (quote b))
        \\ (eq (eq (quote c) (quote c)) (quote t))
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(t f t)"));
}

test "interpret axiom eq as root" {
    var interpreter = egg.Interpreter.init("(eq (quote a) (quote a))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "t"));
}

test "interpret eq with too many arguments" {
    var interpreter = egg.Interpreter.init("(eq (quote a) (quote a) (quote a))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

test "interpret eq with missing arguments" {
    var interpreter = egg.Interpreter.init("(eq)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "eq is f with list arguments" {
    var interpreter = egg.Interpreter.init("(eq (quote (x y)) (quote (x, y)))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "f"));
}

// test nil
test "nil" {
    var interpreter = egg.Interpreter.init("()", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "nil"));
}

test "nil equality" {
    var interpreter = egg.Interpreter.init("(eq () (quote nil))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "t"));
}

// test car
test "car" {
    var interpreter = egg.Interpreter.init("(car (quote (a b c)))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "a"));
}

test "car with no first item" {
    var interpreter = egg.Interpreter.init("(car (quote ()))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "nil"));
}

test "car with missing arguments" {
    var interpreter = egg.Interpreter.init("(car)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "car with too many arguments" {
    var interpreter = egg.Interpreter.init("(car (quote (a)) (quote (b)))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

test "car with atom value" {
    var interpreter = egg.Interpreter.init("(car (quote a))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.ListArgumentExpected);
        return;
    };
    unreachable;
}

// cdr
test "cdr" {
    var interpreter = egg.Interpreter.init("((cdr (quote (a b c))) (cdr (quote (a))) (cdr (quote ())))", std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "((b c) nil nil)"));
}

test "cdr with wrong argument" {
    var interpreter = egg.Interpreter.init("(cdr (quote a))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.ListArgumentExpected);
        return;
    };
    unreachable;
}

test "cdr with too few arguments" {
    var interpreter = egg.Interpreter.init("(cdr)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "cdr with too many arguments" {
    var interpreter = egg.Interpreter.init("(cdr (quote (a)) (quote (b)))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

// cons
test "cons" {
    const program =
        \\((cons (quote a) (quote (b c)))
        \\ (cons (quote a) (quote nil))
        \\ (cons (quote (a b)) (quote nil))
        \\ (cons (quote (a b)) (quote (c d)))
        \\ (cons (quote a) (quote b))
        \\ (cons (quote nil) (quote nil))
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();
    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "((a b c) (a) (a b) (a b c d) (a b) nil)"));
}

test "cons with too few arguments" {
    var interpreter = egg.Interpreter.init("(cons)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "cons with too many arguments" {
    var interpreter = egg.Interpreter.init("(cons (quote (a)) (quote (b)) (quote (c)))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

// (if condition if-true if-false)
test "if" {
    const program =
        \\((if (eq (quote a) (quote a)) (quote (a b)) (quote nil))
        \\ (if (quote f) (quote (b c)) (quote (c d)))
        \\ (if (quote (wtf)) (quote (b c)) (quote (e f)))
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "((a b) (c d) (e f))"));
}

test "if as root expression" {
    const program = "(if (eq (quote a) (quote a)) (quote (a b)) (quote nil))";
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(a b)"));
}

test "if with too few arguments" {
    var interpreter = egg.Interpreter.init("(if)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "if with too many arguments" {
    var interpreter = egg.Interpreter.init("(if (quote a) (quote b) (quote c) (quote d))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

// atom
test "atom" {
    const program =
        \\((atom (quote a))
        \\ (atom (quote (a b c)))
        \\)
    ;

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(t f)"));
}

test "atom as root expression" {
    const program = "(atom (quote a))";

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "t"));
}

test "atom with too few arguments" {
    var interpreter = egg.Interpreter.init("(atom)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };
    unreachable;
}

test "atom with too many arguments" {
    var interpreter = egg.Interpreter.init("(atom (quote a) (quote b))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };
    unreachable;
}

test "let" {
    const program =
        \\(
        \\ (let (quote year) (quote 1618))
        \\ (let (quote first-year) year)
        \\ (let (quote year) (quote 1619))
        \\ (let (quote years) (first-year year (quote year)))
        \\ first-year
        \\ year
        \\ years
        \\)
    ;

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(1618 1619 (1618 1619 year))"));
}

test "let as root" {
    const program = "(let (quote year) (quote 1618)) ";
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "nil"));
}

test "undefined atoms" {
    const program = "(i)";
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.UndefinedAtom);
        return;
    };

    unreachable;
}

test "let with too few arguments" {
    var interpreter = egg.Interpreter.init("(let)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };

    unreachable;
}

test "let with too many arguments" {
    var interpreter = egg.Interpreter.init("(let a b c)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };

    unreachable;
}

test "let with list as variable name" {
    var interpreter = egg.Interpreter.init("(let (quote (a b)) (quote c))", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.InvalidVariableName);
        return;
    };

    unreachable;
}

// def: (def name (args) (body))
test "def" {
    const program = "(def f (x y) (cons x (cdr y)))";

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "nil"));
}

test "def with atom as argument" {
    const program = "((def f x (cons x (cdr y))))";

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.InvalidFunctionDefinition);
        return;
    };

    unreachable;
}

test "def with list as name" {
    const program = "((def (f1 f2) x (cons x (cdr y))))";

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.InvalidFunctionDefinition);
        return;
    };

    unreachable;
}

test "def with list as argument name" {
    const program = "((def f (x y (z)) (cons x (cdr y))))";

    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.InvalidFunctionDefinition);
        return;
    };

    unreachable;
}

test "def with too few arguments" {
    var interpreter = egg.Interpreter.init("(def)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };

    unreachable;
}

test "def with too many arguments" {
    var interpreter = egg.Interpreter.init("(def f (a b c) (b c) error)", std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };

    unreachable;
}

test "function call" {
    const program =
        \\(
        \\ (def f (x) x)
        \\ (def g (x) (quote 1234))
        \\ (f (quote 42))
        \\ (f (quote 41))
        \\ (f (quote 40))
        \\ (g (quote 40))
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();
    const result = try interpreter.run();
    defer result.deinit();

    try expect(std.mem.eql(u8, result.items, "(42 41 40 1234)"));
}

test "function call with too many arguments" {
    const program =
        \\(
        \\ (def f () (quote x))
        \\ (f (quote 42) (quote 43) (quote 44))
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.TooManyArguments);
        return;
    };

    unreachable;
}

test "function call with too few arguments" {
    const program =
        \\(
        \\ (def f (x) x)
        \\ (f)
        \\)
    ;
    var interpreter = egg.Interpreter.init(program, std.testing.allocator);
    defer interpreter.deinit();

    _ = interpreter.run() catch |e| {
        try expect(e == egg.EvaluationErrors.MissingArguments);
        return;
    };

    unreachable;
}
