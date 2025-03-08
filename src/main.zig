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
    const args = try collectArgsIntoSlice(allocator, &args_it);

    const bible_reference = try ArgumentParser.parse(args);

    // Open the file
    const json_bible_file = try std.fs.cwd().openFile("./KJVA.json", .{ .mode = .read_only });
    defer json_bible_file.close();

    const json_bible_raw = try json_bible_file.readToEndAlloc(allocator, try json_bible_file.getEndPos());

    const json_bible_parsed = try json.parseFromSlice(Bible, allocator, json_bible_raw, .{});
    defer json_bible_parsed.deinit();

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

const Verse = struct {
    verse: u8,
    chapter: u8,
    name: []const u8,
    text: []const u8,
};

const Chapter = struct { chapter: u8, name: []const u8, verses: []const Verse };

const Bible = struct {
    genesis: []const Chapter,
    exodus: []const Chapter,
    leviticus: []const Chapter,
    numbers: []const Chapter,
    deuteronomy: []const Chapter,
    joshua: []const Chapter,
    judges: []const Chapter,
    ruth: []const Chapter,
    first_samuel: []const Chapter,
    second_samuel: []const Chapter,
    first_kings: []const Chapter,
    second_kings: []const Chapter,
    first_chronicles: []const Chapter,
    second_chronicles: []const Chapter,
    ezra: []const Chapter,
    nehemiah: []const Chapter,
    esther: []const Chapter,
    job: []const Chapter,
    psalms: []const Chapter,
    proverbs: []const Chapter,
    ecclesiastes: []const Chapter,
    song_of_solomon: []const Chapter,
    isaiah: []const Chapter,
    jeremiah: []const Chapter,
    lamentations: []const Chapter,
    ezekiel: []const Chapter,
    daniel: []const Chapter,
    hosea: []const Chapter,
    joel: []const Chapter,
    amos: []const Chapter,
    obadiah: []const Chapter,
    jonah: []const Chapter,
    micah: []const Chapter,
    nahum: []const Chapter,
    habakkuk: []const Chapter,
    zephaniah: []const Chapter,
    haggai: []const Chapter,
    zechariah: []const Chapter,
    malachi: []const Chapter,
    first_esdras: []const Chapter,
    second_esdras: []const Chapter,
    tobit: []const Chapter,
    judith: []const Chapter,
    additions_to_esther: []const Chapter,
    wisdom: []const Chapter,
    sirach: []const Chapter,
    baruch: []const Chapter,
    prayer_of_azariah: []const Chapter,
    susanna: []const Chapter,
    bel_and_the_dragon: []const Chapter,
    prayer_of_manasseh: []const Chapter,
    first_maccabees: []const Chapter,
    second_maccabees: []const Chapter,
    matthew: []const Chapter,
    mark: []const Chapter,
    luke: []const Chapter,
    john: []const Chapter,
    acts: []const Chapter,
    romans: []const Chapter,
    first_corinthians: []const Chapter,
    second_corinthians: []const Chapter,
    galatians: []const Chapter,
    ephesians: []const Chapter,
    philippians: []const Chapter,
    colossians: []const Chapter,
    first_thessalonians: []const Chapter,
    second_thessalonians: []const Chapter,
    first_timothy: []const Chapter,
    second_timothy: []const Chapter,
    titus: []const Chapter,
    philemon: []const Chapter,
    hebrews: []const Chapter,
    james: []const Chapter,
    first_peter: []const Chapter,
    second_peter: []const Chapter,
    first_john: []const Chapter,
    second_john: []const Chapter,
    third_john: []const Chapter,
    jude: []const Chapter,
    revelation_of_john: []const Chapter,
};
