const std = @import("std");

pub const TokenIterator = struct {
    const COMMENT = "#";
    pub const LPAREN = "(";
    pub const RPAREN = ")";
    const SPACES = "\n\r\t ";
    const NON_ATOMICS = COMMENT ++ LPAREN ++ RPAREN ++ SPACES;
    program: []const u8,
    index: usize = 0,

    pub fn next(self: *TokenIterator) ?[]const u8 {
        var result: ?[]const u8 = undefined;

        self.skipCommentsAndSpaces();

        if (self.isEndReached()) {
            result = null;
        } else if (self.isAtomic(self.program[self.index])) {
            result = self.atomicToken();
        } else {
            result = self.expressionToken();
        }

        return result;
    }

    fn skipCommentsAndSpaces(self: *TokenIterator) void {
        while (!self.isEndReached() and (self.isSpace(self.program[self.index]) or self.isComment(self.program[self.index]))) {
            self.skipSpaces();
            self.skipCommentLines();
        }
    }

    fn isEndReached(self: *TokenIterator) bool {
        return self.index >= self.program.len;
    }

    fn skipSpaces(self: *TokenIterator) void {
        while (!self.isEndReached() and self.isSpace(self.program[self.index])) {
            self.index += 1;
        }
    }

    fn skipCommentLines(self: *TokenIterator) void {
        while (!self.isEndReached() and self.isComment(self.program[self.index])) {
            self.skipCommentLine();
        }
    }

    fn skipCommentLine(self: *TokenIterator) void {
        const comment_end = std.mem.indexOfScalarPos(u8, self.program, self.index, '\n') orelse self.program.len;

        self.index = comment_end + 1;
    }

    fn atomicToken(self: *TokenIterator) ?[]const u8 {
        const atomic_begin = self.index;
        // find atomic end
        var atomic_end = self.index;
        while (atomic_end < self.program.len and self.isAtomic(self.program[atomic_end])) {
            atomic_end += 1;
        }

        self.index = atomic_end;

        // check if atomic is empty
        if (atomic_end == atomic_begin) {
            return null;
        }

        return self.program[atomic_begin..atomic_end];
    }

    fn expressionToken(self: *TokenIterator) []const u8 {
        const begin = self.index;
        const end = begin + 1;

        self.index = end;

        return self.program[begin..end];
    }

    fn isAtomic(self: *TokenIterator, char: u8) bool {
        return !self.contains(NON_ATOMICS, char);
    }

    fn isSpace(self: *TokenIterator, char: u8) bool {
        return self.contains(SPACES, char);
    }

    fn isComment(self: *TokenIterator, char: u8) bool {
        return self.contains(COMMENT, char);
    }

    fn contains(_: *TokenIterator, collection: []const u8, item: u8) bool {
        return std.mem.indexOfScalar(u8, collection, item) != null;
    }
};
