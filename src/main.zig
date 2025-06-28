const std = @import("std");
const heap = std.heap;
const process = std.process;
const io = std.io;

const ArgumentParser = @import("./argument_parser.zig").ArgumentParser;
const BibleReference = @import("./bible_reference.zig").BibleReference;
const collectArgsIntoSlice = @import("./argument_parser.zig").collectArgsIntoSlice;
const WEBParser = @import("web_bible.zig").WEBParser;

pub fn main() !void {
    var arena_impl = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena_impl.deinit();

    var gpa_impl: heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa_impl.deinit();

    const gpa = gpa_impl.allocator();

    var args_it = try process.argsWithAllocator(gpa);
    defer args_it.deinit();
    const argument = try collectArgsIntoSlice(gpa, &args_it);
    defer gpa.free(argument);

    if (argument.len == 0) {
        try io.getStdErr().writer().print("specify a book chapter:verse\n", .{});
        std.process.exit(1);
    }

    var argument_parser = ArgumentParser{ .allocator = gpa, .argument = argument };
    const bible_reference = try argument_parser.parse();
    defer bible_reference.deinit(gpa);

    var web_bible = WEBParser.init(gpa, &arena_impl);

    const passage = try web_bible.getBibleVerses(bible_reference);
    defer gpa.free(passage);

    _ = arena_impl.reset(.retain_capacity);

    const bible_reference_str = try bible_reference.toString(gpa);
    defer gpa.free(bible_reference_str);

    const std_out = io.getStdOut().writer();
    if (passage.len > 0 and passage[passage.len - 1] == '\n') {
        try std_out.print("{s}\n[{s}]\n", .{ passage, bible_reference_str });
    } else {
        try std_out.print("{s}\n\n[{s}]\n", .{ passage, bible_reference_str });
    }
}
