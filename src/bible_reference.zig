const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

pub const BibleReference = struct {
    book: []const u8,
    chapter: u8,
    from_verse: u8,
    to_verse: ?u8 = null,

    pub fn toString(self: BibleReference, allocator: mem.Allocator) ![]const u8 {
        if (self.to_verse) |to_verse| {
            return try fmt.allocPrint(allocator, "{s} {d}:{d}-{d}", .{ self.book, self.chapter, self.from_verse, to_verse });
        } else {
            return try fmt.allocPrint(allocator, "{s} {d}:{d}", .{ self.book, self.chapter, self.from_verse });
        }
    }
};
