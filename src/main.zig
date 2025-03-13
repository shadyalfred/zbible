const std = @import("std");
const heap = std.heap;
const process = std.process;
const json = std.json;

const ArgumentParser = @import("./argument_parser.zig").ArgumentParser;
const BibleReference = @import("./bible_reference.zig").BibleReference;
const collectArgsIntoSlice = @import("./argument_parser.zig").collectArgsIntoSlice;
const getBibleVerses = @import("web_bible.zig").getBibleVerses;

pub fn main() !void {
    const buffer = try heap.page_allocator.alloc(u8, 1024 * 1024);
    defer heap.page_allocator.free(buffer);
    var backing_allocator = heap.FixedBufferAllocator.init(buffer);

    var arena = heap.ArenaAllocator.init(backing_allocator.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    const argument = try collectArgsIntoSlice(allocator, &args_it);

    var argument_parser = ArgumentParser{ .allocator = allocator, .argument = argument };
    const bible_reference = try argument_parser.parse();

    const verses = try getBibleVerses(allocator, bible_reference);
    std.debug.print("{s}\n", .{verses});
}
