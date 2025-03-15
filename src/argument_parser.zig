const std = @import("std");
const heap = std.heap;
const fmt = std.fmt;
const debug = std.debug;
const mem = std.mem;
const process = std.process;
const ascii = std.ascii;
const fs = std.fs;
const json = std.json;

const BibleReference = @import("bible_reference.zig").BibleReference;

const ParsingError = error{
    UnexpectedToken,
    OutOfBounds,
};

pub const ArgumentParser = struct {
    allocator: mem.Allocator,
    argument: []const u8,
    i: usize = 0,

    pub fn parse(self: *ArgumentParser) !BibleReference {
        const book = try self.parseBook();
        const chapter = try self.parseChapter();
        const from_verse = try self.parseVerse();

        if (self.i != self.argument.len) {
            if (self.argument[self.i] == '-') {
                // skip `-`
                _ = self.eatChar();
            }
            const to_verse = try self.parseVerse();
            return BibleReference{ .book = book, .chapter = chapter, .from_verse = from_verse, .to_verse = to_verse };
        }

        return BibleReference{ .book = book, .chapter = chapter, .from_verse = from_verse };
    }

    fn parseVerse(self: *ArgumentParser) !u8 {
        if (self.i >= self.argument.len) {
            return ParsingError.OutOfBounds;
        }

        if (self.argument[self.i] == ':') {
            _ = self.eatChar();
        }

        var j = self.i;
        while (j < self.argument.len and ascii.isDigit(self.peekCharAt(j))) : (j += 1) {}
        const verse = try fmt.parseInt(u8, self.argument[self.i..j], 10);
        self.i = j;
        _ = self.eatWhitespace();
        return verse;
    }

    fn parseChapter(self: *ArgumentParser) !u8 {
        if (self.i >= self.argument.len) {
            return ParsingError.OutOfBounds;
        }

        var j = self.i;
        while (j < self.argument.len and ascii.isDigit(self.peekCharAt(j))) : (j += 1) {}
        const chapter = try fmt.parseInt(u8, self.argument[self.i..j], 10);
        self.i = j;
        _ = self.eatWhitespace();
        return chapter;
    }

    fn parseBook(self: *ArgumentParser) ![]const u8 {
        var book = try std.ArrayList(u8).initCapacity(self.allocator, 32);
        defer book.deinit();

        // parse book number if it exists
        if (self.parseDigit()) |digit| {
            const book_number = switch (digit) {
                1 => "first",
                2 => "second",
                3 => "third",
                else => return ParsingError.UnexpectedToken,
            };
            try book.appendSlice(book_number);
            try book.append('_');
        } else {
            if (self.parseCardinal()) |cardinal| {
                try book.appendSlice(cardinal);
                try book.append('_');
            }
        }

        const book_name = try self.parseBookName();
        try book.appendSlice(book_name);

        return book.toOwnedSlice();
    }

    fn parseBookName(self: *ArgumentParser) ![]const u8 {
        var j = self.i;

        if (j >= self.argument.len) {
            return ParsingError.OutOfBounds;
        }

        while (j < self.argument.len) : (j += 1) {
            const current_char = self.argument[j];
            if (ascii.isAlphabetic(current_char)) {
                continue;
            } else if (ascii.isWhitespace(current_char)) {
                if (ascii.isAlphabetic(self.peekCharAt(j + 1))) {
                    continue;
                } else {
                    break;
                }
            } else {
                break;
            }
        }

        const slice = self.argument[self.i..j];
        self.i = j;
        _ = self.eatWhitespace();

        const maybe_name = try self.expandAbbreviation(slice);
        if (maybe_name) |name| {
            return name;
        }

        return slice;
    }

    fn expandAbbreviation(self: *ArgumentParser, abbreviation: []const u8) !?[]const u8 {
        const abbreviations_json_file = try fs.cwd().openFile("./bible-books-abbreviations.json", .{ .mode = .read_only });
        defer abbreviations_json_file.close();

        const abbreviations_json = try abbreviations_json_file.readToEndAlloc(self.allocator, try abbreviations_json_file.getEndPos());

        var abbreviations_json_root = try json.parseFromSliceLeaky(json.Value, self.allocator, abbreviations_json, .{});

        if (abbreviations_json_root.object.get(abbreviation)) |book_name| {
            return book_name.string;
        }

        return null;
    }

    fn parseCardinal(self: *ArgumentParser) ?[]const u8 {
        if (self.i >= self.argument.len) {
            return null;
        }

        var j = self.i;

        while (j < self.argument.len and ascii.isAlphabetic(self.argument[j])) : (j += 1) {}

        const slice = self.argument[self.i..j];

        if (mem.eql(u8, slice, "first") or
            mem.eql(u8, slice, "second") or
            mem.eql(u8, slice, "third") or
            mem.eql(u8, slice, "fourth"))
        {
            self.i = j;
            _ = self.eatWhitespace();
            return slice;
        }

        return null;
    }

    fn peekNextChar(self: ArgumentParser) u8 {
        if (self.i + 1 < self.argument.len) {
            return self.argument[self.i + 1];
        }
        return 0;
    }

    fn peekCharAt(self: ArgumentParser, i: usize) u8 {
        if (i < self.argument.len) {
            return self.argument[i];
        }
        return 0;
    }

    fn parseDigit(self: *ArgumentParser) ?u8 {
        if (self.i >= self.argument.len) {
            return null;
        }

        const char = self.argument[self.i];
        if (ascii.isDigit(char)) {
            self.i += 1;
            _ = self.eatWhitespace();
            return char - '0';
        }

        return null;
    }

    fn eatChar(self: *ArgumentParser) bool {
        if (self.i >= self.argument.len) {
            return false;
        }
        self.i += 1;
        return true;
    }

    fn eatWhitespace(self: *ArgumentParser) bool {
        if (self.i >= self.argument.len) {
            return false;
        }

        if (!ascii.isWhitespace(self.argument[self.i])) {
            return false;
        }

        self.i += 1;
        return true;
    }
};

pub fn collectArgsIntoSlice(allocator: mem.Allocator, args: *process.ArgIterator) ![]const u8 {
    var list = try std.ArrayList(u8).initCapacity(allocator, 32);
    defer list.deinit();

    // skip first arg (program's name)
    debug.assert(args.skip());

    while (args.next()) |arg| {
        const arg_trimmed = mem.trim(u8, arg, " ");
        for (arg_trimmed) |char| {
            try list.append(ascii.toLower(char));
        }
        try list.append(' ');
    }
    _ = list.pop();
    return list.toOwnedSlice();
}

test "parse" {
    const testing = std.testing;

    const arguments = [_][]const u8{
        "1 kngs 2:3",
        "genesis 1:1",
        "john 1:1",
        "ex 10:11",
        "psalms 1:1",
        "psalm 110:5",
    };

    const bible_references = [_]BibleReference{
        BibleReference{ .book = "first_kings", .chapter = 2, .from_verse = 3, .to_verse = null },
        BibleReference{ .book = "genesis", .chapter = 1, .from_verse = 1, .to_verse = null },
        BibleReference{ .book = "john", .chapter = 1, .from_verse = 1, .to_verse = null },
        BibleReference{ .book = "exodus", .chapter = 10, .from_verse = 11, .to_verse = null },
        BibleReference{ .book = "psalms", .chapter = 1, .from_verse = 1, .to_verse = null },
        BibleReference{ .book = "psalms", .chapter = 110, .from_verse = 5, .to_verse = null },
    };

    for (arguments, bible_references) |argument, bible_reference| {
        var arena = heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        debug.print("parsing:\t`{s}`\n", .{argument});
        var argument_parser = ArgumentParser{ .argument = argument, .allocator = allocator };
        const parsed_bible_ref = try argument_parser.parse();
        debug.print("parsed:\t\t`{s}`\n", .{try parsed_bible_ref.toString()});
        debug.assert(mem.eql(u8, parsed_bible_ref.book, bible_reference.book));
        debug.assert(parsed_bible_ref.chapter == bible_reference.chapter);
        debug.assert(parsed_bible_ref.from_verse == bible_reference.from_verse);
        debug.assert(parsed_bible_ref.to_verse == bible_reference.to_verse);
    }
}
