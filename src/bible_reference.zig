const std = @import("std");
const fmt = std.fmt;

pub const BibleReference = struct {
    book: []const u8,
    chapter: u8,
    from_verse: u8,
    to_verse: ?u8 = null,

    pub fn toString(self: BibleReference) ![]const u8 {
        var buffer: [32]u8 = undefined;
        if (self.to_verse) |to_verse| {
            return try fmt.bufPrint(buffer[0..], "{s} {d}:{d}-{d}", .{ self.book, self.chapter, self.from_verse, to_verse });
        } else {
            return try fmt.bufPrint(buffer[0..], "{s} {d}:{d}", .{ self.book, self.chapter, self.from_verse });
        }
    }
};
