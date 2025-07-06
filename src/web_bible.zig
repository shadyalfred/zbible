const std = @import("std");
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const fs = std.fs;
const process = std.process;

const BibleBook = @import("bible_reference.zig").BibleBook;
const BibleReference = @import("bible_reference.zig").BibleReference;
const TokenIterator = @import("token_iterator.zig").TokenIterator;

const Error = error{
    BibleBookNotFound,
    ChapterNotFound,
    VerseNotFound,
};

pub const WEBParser = struct {
    gpa: mem.Allocator,
    arena_impl: *heap.ArenaAllocator,
    arena: mem.Allocator,
    web_dir: []const u8,
    has_multiple_chapters: bool = false,

    pub fn init(gpa: mem.Allocator, arena_impl: *heap.ArenaAllocator) WEBParser {
        const web_dir = process.getEnvVarOwned(gpa, "ZBIBLE_WEB_DIR") catch blk: {
            break :blk gpa.dupe(u8, "/usr/share/zbible/eng-web-usfm") catch unreachable;
        };

        return WEBParser{
            .gpa = gpa,
            .arena_impl = arena_impl,
            .arena = arena_impl.allocator(),
            .web_dir = web_dir,
        };
    }

    pub fn deinit(self: WEBParser) void {
        self.gpa.free(self.web_dir);
        _ = self.arena_impl.reset(.free_all);
    }

    pub fn getBiblePassage(self: *WEBParser, bible_reference: BibleReference) ![]const u8 {
        self.has_multiple_chapters = hasMultipleChapters(bible_reference);

        defer _ = self.arena_impl.reset(.free_all);

        const maybe_bible_file_name = getBibleBookFileName(bible_reference.book);

        if (maybe_bible_file_name == null) {
            return Error.BibleBookNotFound;
        }

        var passage = try std.ArrayList(u8).initCapacity(self.gpa, 4 * 1024);
        defer passage.deinit();

        var footnotes = try std.ArrayList(u8).initCapacity(self.gpa, 2 * 1024);
        defer footnotes.deinit();

        const bible_file_name = if (bible_reference.book == .Psalms and bible_reference.verse_ranges[0].from_chapter == 151) "56_PS2eng_web.usfm" else maybe_bible_file_name.?;

        const web_usfm_file_path = try fs.path.join(self.gpa, &[_][]const u8{self.web_dir, bible_file_name});
        defer self.gpa.free(web_usfm_file_path);

        const web_usfm_file = try fs.openFileAbsolute(web_usfm_file_path, .{ .mode = .read_only });
        defer web_usfm_file.close();

        var buffered_reader = std.io.bufferedReader(web_usfm_file.reader());
        var file_reader = buffered_reader.reader();

        const file = try file_reader.readAllAlloc(self.gpa, 1024 * 1024);
        defer self.gpa.free(file);

        var lines_it = TokenIterator{ .buffer = file, .delimiter = '\n' };

        for (bible_reference.verse_ranges) |verse_range| {
            _ = self.arena_impl.reset(.retain_capacity);
            defer lines_it.reset();

            var should_print_chapter_number = self.has_multiple_chapters;

            if (!findChapter(verse_range.from_chapter, &lines_it)) {
                return Error.ChapterNotFound;
            }

            defer if (passage.getLastOrNull()) |last_char| {
                if (!(last_char == '\n' or last_char == ' ' or last_char == '\t')) {
                    passage.append(' ') catch unreachable;
                }
            };

            if (!findVerse(verse_range.from_verse orelse 1, &lines_it)) {
                return Error.VerseNotFound;
            }

            // Must check previous line after locating the verse,
            // because sometimes it is perceded by an indentation.
            if (lines_it.peekBackwards()) |previous_line| {
                if (mem.startsWith(u8, previous_line, "\\q")) {
                    if (try self.parseLine(
                        previous_line,
                        &footnotes,
                        verse_range.from_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        if (passage.items.len == 0 and parsed_line[0] == '\n') {
                            try passage.appendSlice(parsed_line[1..]);
                        } else {
                            try passage.appendSlice(parsed_line);
                        }
                    }
                }
            }

            if (verse_range.from_verse != null and verse_range.to_chapter == null and verse_range.to_verse == null) {
                // single verse
                // example: gen 1:1

                const from_verse = verse_range.from_verse.?;
                while (lines_it.next()) |line| {
                    if (parseChapter(line)) |_| {
                        break;
                    }

                    if (parseVerseNumber(line)) |current_verse_number| {
                        if (current_verse_number != from_verse) {
                            break;
                        }
                    }

                    if (try self.parseLine(
                        line,
                        &footnotes,
                        verse_range.from_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        try passage.appendSlice(parsed_line);
                        _ = self.arena_impl.reset(.retain_capacity);
                    }
                }
            } else if (verse_range.from_verse == null and verse_range.to_chapter == null) {
                // a whole chapter
                // example: psa 1

                while (lines_it.next()) |line| {
                    defer _ = self.arena_impl.reset(.retain_capacity);

                    if (parseChapter(line)) |_| {
                        break;
                    }

                    if (try self.parseLine(
                        line,
                        &footnotes,
                        verse_range.from_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        if (passage.getLastOrNull()) |last_char| {
                            if (last_char != '\n' and !(parsed_line[0] == '\t' or parsed_line[0] == '\n')) {
                                try passage.append(' ');
                            }
                        }

                        try passage.appendSlice(parsed_line);
                    }
                }
            } else if (verse_range.from_verse == null and verse_range.to_chapter != null and verse_range.to_verse == null) {
                // whole chapters range
                // example: gen 2-5

                var current_chapter = verse_range.from_chapter;

                while (lines_it.next()) |line| {
                    defer _ = self.arena_impl.reset(.retain_capacity);

                    if (parseChapter(line)) |current_chapter_number| {
                        if (current_chapter_number > verse_range.to_chapter.?) {
                            break;
                        }

                        current_chapter = current_chapter_number;
                        should_print_chapter_number = true;
                    }

                    if (try self.parseLine(
                        line,
                        &footnotes,
                        current_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        if (passage.getLastOrNull()) |last_char| {
                            if (last_char != '\n' and !(parsed_line[0] == '\t' or parsed_line[0] == '\n')) {
                                try passage.append(' ');
                            }
                        }

                        try passage.appendSlice(parsed_line);
                    }
                }
            } else if (verse_range.to_chapter) |to_chapter| {
                // chapter range
                // example: gen 1:1-2:1, gen 1-2:1

                var current_chapter = verse_range.from_chapter;

                while (lines_it.next()) |line| {
                    defer _ = self.arena_impl.reset(.retain_capacity);

                    if (parseChapter(line)) |current_chapter_number| {
                        if (current_chapter > to_chapter) {
                            break;
                        }

                        current_chapter = current_chapter_number;

                        should_print_chapter_number = true;
                        continue;
                    } else if (parseVerseNumber(line)) |current_verse_number| {
                        if (current_chapter == to_chapter and
                            current_verse_number > verse_range.to_verse.?)
                        {
                            break;
                        }
                    }

                    if (try self.parseLine(
                        line,
                        &footnotes,
                        current_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        if (passage.getLastOrNull()) |last_char| {
                            if (last_char != '\n' and !(parsed_line[0] == '\t' or parsed_line[0] == '\n')) {
                                try passage.append(' ');
                            }
                        }

                        try passage.appendSlice(parsed_line);
                    }
                }
            } else {
                // verse range in the same chapter
                // example: gen 1:1-2

                while (lines_it.next()) |line| {
                    defer _ = self.arena_impl.reset(.retain_capacity);

                    if (parseChapter(line)) |_| {
                        break;
                    } else if (parseVerseNumber(line)) |verse_number| {
                        if (verse_number > verse_range.to_verse.?) {
                            break;
                        }
                    }

                    if (try self.parseLine(
                        line,
                        &footnotes,
                        verse_range.from_chapter,
                        &should_print_chapter_number,
                    )) |parsed_line| {
                        if (passage.getLastOrNull()) |last_char| {
                            if (last_char != '\n' and !(parsed_line[0] == '\t' or parsed_line[0] == '\n')) {
                                try passage.append(' ');
                            }
                        }

                        try passage.appendSlice(parsed_line);
                    }
                }
            }
        }

        while (passage.getLastOrNull()) |last_char| {
            if (last_char == '\t' or last_char == '\n' or last_char == ' ') {
                _ = passage.pop();
            } else {
                break;
            }
        }

        if (footnotes.items.len != 0) {
            try passage.append('\n');
            try passage.appendSlice(footnotes.items);
        }

        return passage.toOwnedSlice();
    }

    fn hasMultipleChapters(bible_reference: BibleReference) bool {
        const first_chapter = bible_reference.verse_ranges[0].from_chapter;

        for (bible_reference.verse_ranges) |verse_range| {
            if (verse_range.from_chapter != first_chapter) {
                return true;
            }

            if (verse_range.to_chapter) |_| {
                return true;
            }
        }

        return false;
    }

    fn findChapter(chapter: u8, lines_it: *TokenIterator) bool {
        while (lines_it.next()) |line| {
            if (parseChapter(line)) |parsed_chapter| {
                if (parsed_chapter == chapter) {
                    return true;
                } else if (parsed_chapter > chapter) {
                    return false;
                }
            }
        }
        return false;
    }

    fn findVerse(verse_number: u8, lines_it: *TokenIterator) bool {
        while (lines_it.peek()) |line| : (_ = lines_it.next()) {
            if (parseVerseNumber(line)) |parsed_verse_number| {
                if (parsed_verse_number == verse_number) {
                    return true;
                } else if (parsed_verse_number > verse_number) {
                    return false;
                }
            }
        }
        return false;
    }

    fn toSuperscript(self: WEBParser, number: u8) ![]const u8 {
        var buffer: [16]u8 = undefined;
        const num = try fmt.bufPrint(&buffer, "{d}", .{number});

        var ss_number = try std.ArrayList(u8).initCapacity(self.arena, 16);
        defer ss_number.deinit();

        for (num) |digit| {
            const ss = switch (digit) {
                '0' => "⁰",
                '1' => "¹",
                '2' => "²",
                '3' => "³",
                '4' => "⁴",
                '5' => "⁵",
                '6' => "⁶",
                '7' => "⁷",
                '8' => "⁸",
                '9' => "⁹",
                else => @panic("not a digit"),
            };
            try ss_number.appendSlice(ss);
        }

        return ss_number.toOwnedSlice();
    }

    fn parseChapter(line: []const u8) ?u8 {
        if (!(mem.startsWith(u8, line, "\\c ") or mem.startsWith(u8, line, "\\cp"))) {
            return null;
        }

        var it = mem.tokenizeScalar(u8, line, ' ');
        // skip `\c`
        _ = it.next();
        const chapter = fmt.parseInt(u8, it.next().?, 10) catch unreachable;
        return chapter;
    }

    fn parseVerseNumber(line: []const u8) ?u8 {
        if (!mem.startsWith(u8, line, "\\v")) {
            return null;
        }
        var it = mem.tokenizeScalar(u8, line, ' ');
        // skip `\v`
        _ = it.next();
        return fmt.parseInt(u8, it.next().?, 10) catch unreachable;
    }

    fn cleanUpWord(word: []const u8) []const u8 {
        if (mem.indexOfScalar(u8, word, '|')) |r| {
            return word[0..r];
        }

        var r = word.len - 1;
        while (!ascii.isAlphabetic(word[r])) {
            r -= 1;
        }

        if (r == word.len - 1) {
            return word;
        }

        r += 1;

        return word[0..r];
    }

    fn parseLine(
        self: WEBParser,
        line: []const u8,
        footnotes: *std.ArrayList(u8),
        current_chapter_number: u8,
        should_print_chapter_number: *bool,
    ) !?[]const u8 {
        var i: usize = 0;
        var parsed_line = try std.ArrayList(u8).initCapacity(self.arena, 4 * 1024);
        defer parsed_line.deinit();
        while (i < line.len) {
            if (line[i] == '\\') {
                if (line[i + 1] == '+') {
                    i += 1;
                }
                switch (line[i + 1]) {
                    'w' => {
                        // skip `\wj`
                        if (line[i + 2] == 'j') {
                            i += 4;
                            continue;
                        }

                        i = mem.indexOfScalarPos(u8, line, i, ' ').?;

                        if (line[i - 1] == '*') {
                            // skip `\w*`
                            i += 1;
                            continue;
                        }

                        // skip the whitespace char in `\w `
                        //                                ^
                        i += 1;

                        const word_end_i = mem.indexOfScalarPos(u8, line, i, '\\').?;
                        const maybe_strong = mem.indexOfScalarPos(u8, line, i, '|');
                        if (maybe_strong) |strong_idx| {
                            try parsed_line.appendSlice(line[i..strong_idx]);
                        } else {
                            try parsed_line.appendSlice(line[i..word_end_i]);
                        }

                        i = mem.indexOfScalarPos(u8, line, i, '*').? + 1;
                    },
                    'q' => {
                        var indentation_level = line[i + 2] - '0';
                        try parsed_line.append('\n');
                        while (indentation_level > 1) : (indentation_level -= 1) {
                            try parsed_line.append('\t');
                        }
                        i += 4;
                    },
                    'v' => {
                        i += 3;
                        const start = i;
                        while (ascii.isDigit(line[i])) {
                            i += 1;
                        }

                        if (should_print_chapter_number.*) {
                            const current_chapter_number_ss = try self.toSuperscript(current_chapter_number);
                            defer self.arena.free(current_chapter_number_ss);

                            try parsed_line.appendSlice(current_chapter_number_ss);
                            try parsed_line.appendSlice("𐞁");

                            should_print_chapter_number.* = false;
                        }

                        const verse_number = fmt.parseInt(u8, line[start..i], 10) catch unreachable;
                        const verse_number_ss = try self.toSuperscript(verse_number);
                        defer self.arena.free(verse_number_ss);

                        try parsed_line.appendSlice(verse_number_ss);

                        // skip whitespace
                        i = mem.indexOfScalarPos(u8, line, i, ' ').? + 1;
                    },
                    'f' => {
                        var maybe_word: ?[]const u8 = null;

                        if (line[i - 1] != ' ') {
                            maybe_word = cleanUpWord(line[(mem.lastIndexOfScalar(u8, line[0..i], ' ').? + 1)..i]);
                        }

                        const fr_begin = mem.indexOfScalarPos(u8, line, i, ':').? + 1;
                        const fr_end = mem.indexOfScalarPos(u8, line, fr_begin, ' ').?;
                        const verse_number = line[fr_begin..fr_end];

                        const ft_begin = mem.indexOfScalarPos(u8, line, fr_end + 1, ' ').? + 1;
                        const ft_end = mem.indexOfPosLinear(u8, line, ft_begin, "\\f*").?;
                        const ft_raw = line[ft_begin..ft_end];

                        var temp = try mem.replaceOwned(u8, self.arena, ft_raw, "\\+wh ", "");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\+wh*", "");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\+bk ", "“");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\+bk*", "”");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\fqa ", "");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\fl ", "");
                        temp = try mem.replaceOwned(u8, self.arena, temp, "\\ft ", "");

                        try footnotes.append('\n');
                        if (self.has_multiple_chapters) {
                            try footnotes.appendSlice(
                                try fmt.allocPrint(self.arena, "{d}:", .{current_chapter_number}),
                            );
                        }
                        try footnotes.appendSlice(verse_number);
                        try footnotes.appendSlice(": ");
                        if (maybe_word) |word| {
                            try footnotes.appendSlice(try fmt.allocPrint(self.arena, "({s}) ", .{word}));
                        }
                        try footnotes.appendSlice(mem.trimRight(u8, temp[0..], " "));

                        i = ft_end + 3;
                    },
                    'b' => {
                        if (line[i + 2] == 'k') {
                            if (line[i + 3] == '*') {
                                try parsed_line.appendSlice("”");
                            } else {
                                try parsed_line.appendSlice("“");
                            }
                        }
                        i += 4;
                        continue;
                    },
                    'p' => {
                        try parsed_line.append('\n');

                        if (i + 2 < line.len and ascii.isDigit(line[i + 2])) {
                            var p_i: u8 = line[i + 2] - '0';
                            while (p_i > 1) : (p_i -= 1) {
                                try parsed_line.append('\t');
                            }
                        }

                        i = mem.indexOfScalarPos(u8, line, i, ' ') orelse line.len;
                        i += 1;
                    },
                    'x' => {
                        // skip `\x...\x*`
                        i = mem.indexOfScalarPos(u8, line, i, '*').? + 1;
                        if (line[i] == ' ') {
                            i += 1;
                        }
                    },
                    'm' => {
                        if (i + 2 < line.len and line[i + 2] != ' ') {
                            break;
                        }
                        try parsed_line.append('\n');
                        i = mem.indexOfScalarPos(u8, line, i, ' ') orelse line.len;
                        i += 1;
                    },
                    'd', 'c' => {
                        break;
                    },
                    else => {
                        if (mem.indexOfScalarPos(u8, line, i, ' ')) |j| {
                            i = j + 1;
                        } else {
                            break;
                        }
                    },
                }
            } else if (line[i] == ' ') {
                if (i + 1 < line.len and line[i] == line[i + 1]) {
                    i += 3;
                    continue;
                }

                if (parsed_line.getLastOrNull()) |last_char| {
                    if (last_char != ' ') {
                        try parsed_line.append(line[i]);
                    }
                }

                i += 1;
            } else {
                try parsed_line.append(line[i]);
                i += 1;
            }
        }

        while (parsed_line.getLastOrNull()) |last_char| {
            if (last_char == ' ') {
                _ = parsed_line.pop();
            } else {
                break;
            }
        }

        if (parsed_line.items.len == 0) {
            return null;
        }

        return try parsed_line.toOwnedSlice();
    }
};

fn getBibleBookFileName(bible_book: BibleBook) ?[]const u8 {
    return switch (bible_book) {
        .Genesis => "02_GENeng_web.usfm",
        .Exodus => "03_EXOeng_web.usfm",
        .Leviticus => "04_LEVeng_web.usfm",
        .Numbers => "05_NUMeng_web.usfm",
        .Deuteronomy => "06_DEUeng_web.usfm",
        .Joshua => "07_JOSeng_web.usfm",
        .Judges => "08_JDGeng_web.usfm",
        .Ruth => "09_RUTeng_web.usfm",
        .FirstSamuel => "10_1SAeng_web.usfm",
        .SecondSamuel => "11_2SAeng_web.usfm",
        .FirstKings => "12_1KIeng_web.usfm",
        .SecondKings => "13_2KIeng_web.usfm",
        .FirstChronicles => "14_1CHeng_web.usfm",
        .SecondChronicles => "15_2CHeng_web.usfm",
        .Ezra => "16_EZReng_web.usfm",
        .Nehemiah => "17_NEHeng_web.usfm",
        .Esther => "18_ESTeng_web.usfm",
        .Job => "19_JOBeng_web.usfm",
        .Psalms => "20_PSAeng_web.usfm",
        .Proverbs => "21_PROeng_web.usfm",
        .Ecclesiastes => "22_ECCeng_web.usfm",
        .SongOfSolomon => "23_SNGeng_web.usfm",
        .Isaiah => "24_ISAeng_web.usfm",
        .Jeremiah => "25_JEReng_web.usfm",
        .Lamentations => "26_LAMeng_web.usfm",
        .Ezekiel => "27_EZKeng_web.usfm",
        .Daniel => "28_DANeng_web.usfm",
        .Hosea => "29_HOSeng_web.usfm",
        .Joel => "30_JOLeng_web.usfm",
        .Amos => "31_AMOeng_web.usfm",
        .Obadiah => "32_OBAeng_web.usfm",
        .Jonah => "33_JONeng_web.usfm",
        .Micah => "34_MICeng_web.usfm",
        .Nahum => "35_NAMeng_web.usfm",
        .Habakkuk => "36_HABeng_web.usfm",
        .Zephaniah => "37_ZEPeng_web.usfm",
        .Haggai => "38_HAGeng_web.usfm",
        .Zechariah => "39_ZECeng_web.usfm",
        .Malachi => "40_MALeng_web.usfm",

        .Tobit => "41_TOBeng_web.usfm",
        .Judith => "42_JDTeng_web.usfm",
        .GreekEsther => "43_ESGeng_web.usfm",
        .Wisdom => "45_WISeng_web.usfm",
        .Sirach => "46_SIReng_web.usfm",
        .Baruch => "47_BAReng_web.usfm",
        .FirstMaccabees => "52_1MAeng_web.usfm",
        .SecondMaccabees => "53_2MAeng_web.usfm",
        .FirstEsdras => "54_1ESeng_web.usfm",
        .PrayerOfManasseh => "55_MANeng_web.usfm",
        .ThirdMaccabees => "57_3MAeng_web.usfm",
        .SecondEsdras => "58_2ESeng_web.usfm",
        .FourthMaccabees => "59_4MAeng_web.usfm",
        .GreekDaniel => "66_DAGeng_web.usfm",

        .PrayerOfAzariah => @panic("look up Greek Daniel"),
        .Susanna => @panic("look up Greek Daniel"),
        .BelAndTheDragon => @panic("look up Greek Daniel"),

        .Matthew => "70_MATeng_web.usfm",
        .Mark => "71_MRKeng_web.usfm",
        .Luke => "72_LUKeng_web.usfm",
        .John => "73_JHNeng_web.usfm",
        .Acts => "74_ACTeng_web.usfm",
        .Romans => "75_ROMeng_web.usfm",
        .FirstCorinthians => "76_1COeng_web.usfm",
        .SecondCorinthians => "77_2COeng_web.usfm",
        .Galatians => "78_GALeng_web.usfm",
        .Ephesians => "79_EPHeng_web.usfm",
        .Philippians => "80_PHPeng_web.usfm",
        .Colossians => "81_COLeng_web.usfm",
        .FirstThessalonians => "82_1THeng_web.usfm",
        .SecondThessalonians => "83_2THeng_web.usfm",
        .FirstTimothy => "84_1TIeng_web.usfm",
        .SecondTimothy => "85_2TIeng_web.usfm",
        .Titus => "86_TITeng_web.usfm",
        .Philemon => "87_PHMeng_web.usfm",
        .Hebrews => "88_HEBeng_web.usfm",
        .James => "89_JASeng_web.usfm",
        .FirstPeter => "90_1PEeng_web.usfm",
        .SecondPeter => "91_2PEeng_web.usfm",
        .FirstJohn => "92_1JNeng_web.usfm",
        .SecondJohn => "93_2JNeng_web.usfm",
        .ThirdJohn => "94_3JNeng_web.usfm",
        .Jude => "95_JUDeng_web.usfm",
        .Revelation => "96_REVeng_web.usfm",
    };
}
