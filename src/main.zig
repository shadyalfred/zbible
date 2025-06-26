const std = @import("std");
const heap = std.heap;
const process = std.process;
const io = std.io;

const ArgumentParser = @import("./argument_parser.zig").ArgumentParser;
const BibleReference = @import("./bible_reference.zig").BibleReference;
const collectArgsIntoSlice = @import("./argument_parser.zig").collectArgsIntoSlice;
const WEBParser = @import("web_bible.zig").WEBParser;

pub fn main() !void {
    var scratch_arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer scratch_arena.deinit();

    var gpa = heap.GeneralPurposeAllocator(.{});
    defer gpa.deinit();

    const allocator = gpa.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    const argument = try collectArgsIntoSlice(allocator, &args_it);
    if (argument.len == 0) {
        try io.getStdErr().writer().print("specify a book chapter:verse\n", .{});
        std.process.exit(1);
    }

    var argument_parser = ArgumentParser{ .allocator = allocator, .argument = argument };
    const bible_reference = try argument_parser.parse();

    const web_bible = WEBParser.init(allocator, &scratch_arena);

    const verses = try web_bible.getBibleVerses(bible_reference);
    if (verses.len > 0 and verses[verses.len - 1] == '\n') {
        try io.getStdOut().writer().print("{s}\n[{s}]\n", .{verses, try bible_reference.toString(allocator)});
    } else {
        try io.getStdOut().writer().print("{s}\n\n[{s}]\n", .{verses, try bible_reference.toString(allocator)});
    }
}
