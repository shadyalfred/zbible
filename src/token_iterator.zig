pub const TokenIterator = struct {
    buffer: []const u8,
    delimiter: u8,
    index: usize = 0,
    previous_index: ?usize = null,

    pub fn next(self: *TokenIterator) ?[]const u8 {
        const result = self.peek() orelse return null;
        self.previous_index = self.index;
        self.index += result.len;
        return result;
    }

    pub fn peek(self: *TokenIterator) ?[]const u8 {
        while (self.index < self.buffer.len and self.isDelimiter(self.index)) : (self.index += 1) {}
        const start = self.index;
        if (start == self.buffer.len) {
            return null;
        }

        var end = start;
        while (end < self.buffer.len and !self.isDelimiter(end)) : (end += 1) {}

        return self.buffer[start..end];
    }

    pub fn peekBackwards(self: TokenIterator) ?[]const u8 {
        if (self.previous_index) |previous_index| {
            return self.buffer[previous_index..self.index];
        } else {
            return null;
        }
    }

    fn isDelimiter(self: TokenIterator, i: usize) bool {
        return self.buffer[i] == self.delimiter;
    }
};
