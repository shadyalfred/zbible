const std = @import("std");
const fmt = std.fmt;
const debug = std.debug;
const mem = std.mem;
const process = std.process;
const ascii = std.ascii;

const BibleReference = @import("bible_reference.zig").BibleReference;
const BibleBook = @import("bible_reference.zig").BibleBook;

const ParsingError = error{
    UnexpectedToken,
    OutOfBounds,
    BibleBookNotFound,
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

    fn parseBook(self: *ArgumentParser) !BibleBook {
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
            try book.append(' ');
        } else {
            if (self.parseCardinal()) |cardinal| {
                try book.appendSlice(cardinal);
                try book.append(' ');
            }
        }

        const book_name = try self.parseBookName();
        try book.appendSlice(book_name);

        const maybe_bible_book = getBibleBookEnum(book.items);
        if (maybe_bible_book == null) {
            return ParsingError.BibleBookNotFound;
        }

        return maybe_bible_book.?;
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

        const maybe_name = expandAbbreviation(slice);
        if (maybe_name) |name| {
            return name;
        }

        return slice;
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
    if (list.items.len == 0) {
        return list.toOwnedSlice();
    }
    _ = list.pop();
    return list.toOwnedSlice();
}

fn expandAbbreviation(abbreviation: []const u8) ?[]const u8 {
    const abbreviations = std.StaticStringMap([]const u8).initComptime(.{
        .{ "gn", "genesis" },
        .{ "gen", "genesis" },

        .{ "ex", "exodus" },
        .{ "exod", "exodus" },

        .{ "lev", "leviticus" },

        .{ "num", "numbers" },

        .{ "dt", "deuteronomy" },
        .{ "deut", "deuteronomy" },

        .{ "jos", "joshua" },
        .{ "josh", "joshua" },

        .{ "jdg", "judges" },
        .{ "jgs", "judges" },
        .{ "judg", "judges" },

        .{ "ru", "ruth" },

        .{ "sam", "samuel" },

        .{ "kg", "kings" },
        .{ "kgs", "kings" },
        .{ "kngs", "kings" },

        .{ "ch", "chronicles" },
        .{ "chr", "chronicles" },

        .{ "ezr", "ezra" },

        .{ "neh", "nehemiah" },

        .{ "es", "esther" },
        .{ "est", "esther" },
        .{ "esth", "esther" },

        .{ "jb", "job" },
        .{ "job", "job" },

        .{ "ps", "psalms" },
        .{ "pss", "psalms" },
        .{ "psa", "psalms" },
        .{ "psalm", "psalms" },

        .{ "pr", "proverbs" },
        .{ "prv", "proverbs" },
        .{ "prov", "proverbs" },

        .{ "ec", "ecclesiastes" },
        .{ "eccl", "ecclesiastes" },
        .{ "eccles", "ecclesiastes" },
        .{ "qoh", "ecclesiastes" },
        .{ "qoheleth", "ecclesiastes" },

        .{ "song", "song of solomon" },
        .{ "song of songs", "song of solomon" },

        .{ "is", "isaiah" },
        .{ "isa", "isaiah" },

        .{ "je", "jeremiah" },
        .{ "jer", "jeremiah" },

        .{ "lam", "lamentations" },

        .{ "ez", "ezekiel" },
        .{ "ezk", "ezekiel" },
        .{ "ezek", "ezekiel" },

        .{ "da", "daniel" },
        .{ "dn", "daniel" },
        .{ "dan", "daniel" },

        .{ "add dan", "greek daniel" },
        .{ "additions dan", "greek daniel" },
        .{ "grk dan", "greek daniel" },
        .{ "greek dan", "greek daniel" },
        .{ "grk daniel", "greek daniel" },

        .{ "ho", "hosea" },
        .{ "hos", "hosea" },

        .{ "jl", "joel" },
        .{ "joe", "joel" },

        .{ "am", "amos" },

        .{ "ob", "obadiah" },
        .{ "obad", "obadiah" },

        .{ "jon", "jonah" },

        .{ "mic", "micah" },

        .{ "nah", "nahum" },

        .{ "hab", "habakkuk" },

        .{ "zep", "zephaniah" },
        .{ "zeph", "zephaniah" },

        .{ "hag", "haggai" },

        .{ "zec", "zechariah" },
        .{ "zech", "zechariah" },

        .{ "ml", "malachi" },
        .{ "mal", "malachi" },

        .{ "esd", "esdras" },

        .{ "tb", "tobit" },
        .{ "tob", "tobit" },

        .{ "jth", "judith" },
        .{ "jdt", "judith" },

        .{ "add esth", "greek esther" },
        .{ "additions esth", "greek esther" },
        .{ "grk esth", "greek esther" },
        .{ "greek esth", "greek esther" },

        .{ "wi", "wisdom of solomon" },
        .{ "wis", "wisdom of solomon" },
        .{ "wisdom", "wisdom of solomon" },
        .{ "wis solomon", "wisdom of solomon" },
        .{ "wis of solomon", "wisdom of solomon" },
        .{ "wisdom solomon", "wisdom of solomon" },

        .{ "sir", "sirach" },
        .{ "ecclus", "sirach" },
        .{ "ecclesiasticus", "sirach" },

        .{ "ba", "baruch" },
        .{ "bar", "baruch" },

        .{ "pr azar", "prayer of azariah" },

        .{ "sus", "susanna" },

        .{ "bel", "bel and the dragon" },

        .{ "pr man", "prayer of manasseh" },

        .{ "mc", "maccabees" },
        .{ "ma", "maccabees" },
        .{ "macc", "maccabees" },

        .{ "mt", "matthew" },
        .{ "mat", "matthew" },
        .{ "matt", "matthew" },

        .{ "mk", "mark" },
        .{ "mar", "mark" },

        .{ "lu", "luke" },
        .{ "lk", "luke" },

        .{ "jo", "john" },
        .{ "jn", "john" },

        .{ "ac", "acts" },

        .{ "ro", "romans" },
        .{ "rm", "romans" },
        .{ "rom", "romans" },

        .{ "co", "corinthians" },
        .{ "cor", "corinthians" },

        .{ "ga", "galatians" },
        .{ "gal", "galatians" },

        .{ "ep", "ephesians" },
        .{ "eph", "ephesians" },

        .{ "php", "philippians" },
        .{ "phil", "philippians" },

        .{ "col", "colossians" },

        .{ "th", "thessalonians" },
        .{ "thes", "thessalonians" },
        .{ "thess", "thessalonians" },

        .{ "tm", "timothy" },
        .{ "ti", "timothy" },
        .{ "tim", "timothy" },

        .{ "tit", "titus" },

        .{ "phm", "philemon" },
        .{ "phlm", "philemon" },
        .{ "philem", "philemon" },

        .{ "he", "hebrews" },
        .{ "heb", "hebrews" },

        .{ "ja", "james" },
        .{ "jas", "james" },

        .{ "pt", "peter" },
        .{ "pet", "peter" },

        .{ "ju", "jude" },

        .{ "ap", "revelation of john" },
        .{ "apoc", "revelation of john" },
        .{ "apocalypse", "revelation of john" },
        .{ "rv", "revelation of john" },
        .{ "rev", "revelation of john" },
        .{ "revelation", "revelation of john" },
        .{ "revelation to john", "revelation of john" }
    });

    return abbreviations.get(abbreviation);
}

fn getBibleBookEnum(bible_book_name: []const u8) ?BibleBook {
    const bible_book_name_enum_map = std.StaticStringMap(BibleBook).initComptime(.{
        .{ "genesis", .Genesis },
        .{ "exodus", .Exodus },
        .{ "leviticus", .Leviticus },
        .{ "numbers", .Numbers },
        .{ "deuteronomy", .Deuteronomy },
        .{ "joshua", .Joshua },
        .{ "judges", .Judges },
        .{ "ruth", .Ruth },
        .{ "first samuel", .FirstSamuel },
        .{ "second samuel", .SecondSamuel },
        .{ "first kings", .FirstKings },
        .{ "second kings", .SecondKings },
        .{ "first chronicles", .FirstChronicles },
        .{ "second chronicles", .SecondChronicles },
        .{ "ezra", .Ezra },
        .{ "nehemiah", .Nehemiah },
        .{ "esther", .Esther },
        .{ "job", .Job },
        .{ "psalms", .Psalms },
        .{ "proverbs", .Proverbs },
        .{ "ecclesiastes", .Ecclesiastes },
        .{ "song of solomon", .SongOfSolomon },
        .{ "isaiah", .Isaiah },
        .{ "jeremiah", .Jeremiah },
        .{ "lamentations", .Lamentations },
        .{ "ezekiel", .Ezekiel },
        .{ "daniel", .Daniel },
        .{ "hosea", .Hosea },
        .{ "joel", .Joel },
        .{ "amos", .Amos },
        .{ "obadiah", .Obadiah },
        .{ "jonah", .Jonah },
        .{ "micah", .Micah },
        .{ "nahum", .Nahum },
        .{ "habakkuk", .Habakkuk },
        .{ "zephaniah", .Zephaniah },
        .{ "haggai", .Haggai },
        .{ "zechariah", .Zechariah },
        .{ "malachi", .Malachi },

        .{ "tobit", .Tobit },
        .{ "judith", .Judith },
        .{ "greek esther", .GreekEsther },
        .{ "wisdom of solomon", .Wisdom },
        .{ "sirach", .Sirach },
        .{ "baruch", .Baruch },
        .{ "first maccabees", .FirstMaccabees },
        .{ "second maccabees", .SecondMaccabees },
        .{ "first esdras", .FirstEsdras },
        .{ "prayer of manasseh", .PrayerOfManasseh },
        .{ "third maccabees", .ThirdMaccabees },
        .{ "second esdras", .SecondEsdras },
        .{ "fourth maccabees", .FourthMaccabees },
        .{ "greek daniel", .GreekDaniel },

        .{ "matthew", .Matthew },
        .{ "mark", .Mark },
        .{ "luke", .Luke },
        .{ "john", .John },
        .{ "acts", .Acts },
        .{ "romans", .Romans },
        .{ "first corinthians", .FirstCorinthians },
        .{ "second corinthians", .SecondCorinthians },
        .{ "galatians", .Galatians },
        .{ "ephesians", .Ephesians },
        .{ "philippians", .Philippians },
        .{ "colossians", .Colossians },
        .{ "first thessalonians", .FirstThessalonians },
        .{ "second thessalonians", .SecondThessalonians },
        .{ "first timothy", .FirstTimothy },
        .{ "second timothy", .SecondTimothy },
        .{ "titus", .Titus },
        .{ "philemon", .Philemon },
        .{ "hebrews", .Hebrews },
        .{ "james", .James },
        .{ "first peter", .FirstPeter },
        .{ "second peter", .SecondPeter },
        .{ "first john", .FirstJohn },
        .{ "second john", .SecondJohn },
        .{ "third john", .ThirdJohn },
        .{ "jude", .Jude },
        .{ "revelation of john", .Revelation },
    });

    return bible_book_name_enum_map.get(bible_book_name);
}

test "parse" {
    const testing = std.testing;
    const heap = std.heap;

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
