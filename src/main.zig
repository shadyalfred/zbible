const std = @import("std");
const heap = std.heap;
const process = std.process;
const io = std.io;

const ArgumentParser = @import("./argument_parser.zig").ArgumentParser;
const BibleReference = @import("./bible_reference.zig").BibleReference;
const collectArgsIntoSlice = @import("./argument_parser.zig").collectArgsIntoSlice;
const WEBParser = @import("web_bible.zig").WEBParser;

pub fn main() !void {
    const buffer = try heap.page_allocator.alloc(u8, 1024 * 1024);
    defer heap.page_allocator.free(buffer);
    var backing_allocator = heap.FixedBufferAllocator.init(buffer);

    var arena = heap.ArenaAllocator.init(backing_allocator.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    const argument = try collectArgsIntoSlice(allocator, &args_it);
    if (argument.len == 0) {
        try io.getStdErr().writer().print("specify a book chapter:verse\n", .{});
        std.process.exit(1);
    }

    var argument_parser = ArgumentParser{ .allocator = allocator, .argument = argument };
    const bible_reference = try argument_parser.parse();

    const web_bible = WEBParser.init(allocator);

    const verses = try web_bible.getBibleVerses(bible_reference);
    if (verses.len > 0 and verses[verses.len - 1] == '\n') {
        try io.getStdOut().writer().print("{s}\n[{s}]\n", .{verses, try bible_reference.toString(allocator)});
    } else {
        try io.getStdOut().writer().print("{s}\n\n[{s}]\n", .{verses, try bible_reference.toString(allocator)});
    }
}
