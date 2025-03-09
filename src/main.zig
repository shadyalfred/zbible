const std = @import("std");
const heap = std.heap;
const process = std.process;
const json = std.json;

const ap = @import("./argument_parser.zig");
const ArgumentParser = ap.ArgumentParser;
const BibleReference = ap.BibleReference;
const collectArgsIntoSlice = @import("./argument_parser.zig").collectArgsIntoSlice;

pub fn main() !void {
    var arena = heap.ArenaAllocator.init(heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var args_it = try process.argsWithAllocator(allocator);
    const argument = try collectArgsIntoSlice(allocator, &args_it);

    var argument_parser = ArgumentParser{ .allocator = allocator, .argument = argument };
    const bible_reference = try argument_parser.parse();

    const json_bible_file = try std.fs.cwd().openFile("./KJVA.json", .{ .mode = .read_only });
    defer json_bible_file.close();

    const json_bible_raw = try json_bible_file.readToEndAlloc(allocator, try json_bible_file.getEndPos());

    var json_bible_root = try json.parseFromSliceLeaky(json.Value, allocator, json_bible_raw, .{});

    const verse = getBibleVerses(bible_reference, &json_bible_root).?;

    std.debug.print("{s}\n", .{verse});
}

fn getBibleVerses(bible_reference: BibleReference, json_bible_root: *json.Value) ?[]const u8 {
    const book = json_bible_root.object.get(bible_reference.book).?;
    const chapter = book.array.items[bible_reference.chapter - 1];
    const verses = chapter.object.get("verses").?;
    const verse = verses.array.items[bible_reference.from_verse - 1];
    return verse.object.get("text").?.string;
}
