const std = @import("std");
const heap = std.heap;
const fmt = std.fmt;
const io = std.io;
const hash = std.hash;
const mem = std.mem;
const ascii = std.ascii;

const BibleReference = @import("bible_reference.zig").BibleReference;
const BibleBook = @import("bible_reference.zig").BibleBook;

const TokenIterator = @import("token_iterator.zig").TokenIterator;

const Error = error{
    BibleBookNotFound,
    ChapterNotFound,
    VerseNotFound,
};

pub const WEBParser = struct {
    allocator: mem.Allocator,
    scratch_arena: *heap.ArenaAllocator,
    scratch_allocator: mem.Allocator,

    pub fn init(allocator: mem.Allocator, scratch_arena: *heap.ArenaAllocator) WEBParser {
        return WEBParser{
            .allocator = allocator,
            .scratch_arena = scratch_arena,
        };
    }

    pub fn getBibleVerses(self: WEBParser, bible_reference: BibleReference) ![]const u8 {
        defer self.scratch_arena.deinit();
        self.scratch_allocator = self.scratch_arena.allocator();

        const maybe_bible_file_name = getBibleBookFileName(bible_reference.book);

        if (maybe_bible_file_name == null) {
            return Error.BibleBookNotFound;
        }

        var passage = try std.ArrayList(u8).initCapacity(self.allocator, 4 * 1024);
        defer passage.deinit();

        var footnotes = try std.ArrayList(u8).initCapacity(self.allocator, 2 * 1024);
        defer footnotes.deinit();

        const bible_file_name = if (bible_reference.book == .Psalms and bible_reference.chapter == 151) "56_PS2eng_web.usfm" else maybe_bible_file_name.?;

        const web_usfm_file = try std.fs.openFileAbsolute(
            try fmt.allocPrint(self.scratch_allocator, "/usr/share/zbible/eng-web-usfm/{s}", .{bible_file_name}),
            .{ .mode = .read_only }
        );
        defer web_usfm_file.close();

        var buffered_reader = io.bufferedReader(web_usfm_file.reader());
        var file_reader = buffered_reader.reader();

        const file = try file_reader.readAllAlloc(self.scratch_allocator, 1024 * 1024);
        defer self.scratch_allocator.free(file);

        var lines_it = TokenIterator{ .buffer = file, .delimeter = '\n' };

        for (bible_reference.verse_ranges) |verse_range| {
            if (!self.findChapter(verse_range.from_chapter, &lines_it)) {
                return Error.ChapterNotFound;
            }

            if (verse_range.from_verse) |from_verse| {
                if (!self.findVerse(from_verse, &lines_it)) {
                    return Error.VerseNotFound;
                }
            } else {
                while (lines_it.next()) |line| {
                    if (self.parseChapter(line)) {
                        break;
                    }

                    passage.appendSlice(try self.parseLine(line, &footnotes));
                }
            }
        }

        // while (lines_it.next()) |line| {
        //     const maybe_chapter = parseChapter(line);
        //     if (maybe_chapter) |chapter| {
        //         if (
        //             chapter == bible_reference.chapter or
        //             (bible_reference.book == .Psalms and bible_reference.chapter == 151)
        //         ) {
        //             found_chapter = true;
        //             break;
        //         }
        //     }
        // }
        //
        // if (!found_chapter) {
        //     return Error.ChapterNotFound;
        // }
        //
        // var found_verse = false;
        // while (lines_it.peek()) |line| : (_ = lines_it.next()) {
        //     const maybe_chapter = parseChapter(line);
        //     if (maybe_chapter) |chapter| {
        //         if (chapter != bible_reference.chapter) {
        //             break;
        //         }
        //     }
        //     const maybe_verse_number = parseVerseNumber(line);
        //     if (maybe_verse_number) |verse_number| {
        //         if (verse_number == bible_reference.from_verse) {
        //             const previous_line = lines_it.buffer[lines_it.index-4..lines_it.index];
        //             if (mem.startsWith(u8, previous_line, "\\q")) {
        //                 var i = previous_line[2] - '0';
        //                 while (i > 0) : (i -= 1) {
        //                     try verses.append('\t');
        //                 }
        //             }
        //             found_verse = true;
        //             break;
        //         }
        //     }
        // }
        //
        // if (!found_verse) {
        //     return Error.VerseNotFound;
        // }
        //
        // while (lines_it.next()) |line| {
        //     const maybe_chapter = parseChapter(line);
        //     if (maybe_chapter) |chapter| {
        //         if (chapter != bible_reference.chapter) {
        //             break;
        //         }
        //     }
        //
        //     const maybe_verse_number = parseVerseNumber(line);
        //     var maybe_verse_number_ss: ?[]const u8 = null;
        //     if (maybe_verse_number) |verse_number| {
        //         if (bible_reference.to_verse) |to_verse| {
        //             if (verse_number > to_verse) {
        //                 break;
        //             }
        //         } else {
        //             if (verse_number != bible_reference.from_verse) {
        //                 break;
        //             }
        //         }
        //         maybe_verse_number_ss = try self.toSuperscript(verse_number);
        //     }
        //     if (mem.startsWith(u8, line, "\\s")) {
        //         continue;
        //     }
        //
        //     const parsed_line = try self.parseLine(line, &footnotes);
        //     if (parsed_line.len == 0) {
        //         continue;
        //     }
        //
        //     if (verses.items.len > 0) {
        //         const last_char = verses.getLast();
        //         if (
        //             ! (last_char == '\n' or last_char == ' ') and
        //             ! (parsed_line[0] == '\n' or parsed_line[0] == ' ' or parsed_line[0] == '\t')
        //         ) {
        //             try verses.append(' ');
        //         } else if (last_char == ' ' and last_char == parsed_line[0]) {
        //             _ = verses.pop();
        //         }
        //     }
        //
        //     if (maybe_verse_number_ss) |verse_number_ss| {
        //         try verses.appendSlice(verse_number_ss);
        //     }
        //     try verses.appendSlice(parsed_line);
        // }
        //
        // if (verses.getLastOrNull()) |last_char| {
        //     if (last_char == ' ') {
        //         _ = verses.pop();
        //     }
        // }
        //
        // if (footnotes.items.len != 0) {
        //     try verses.append('\n');
        //     try verses.appendSlice(try footnotes.toOwnedSlice());
        // }

        return passage.toOwnedSlice();
    }

    fn findChapter(self: WEBParser, chapter: u8, lines_it: *TokenIterator) bool {
        for (lines_it.next()) |line| {
            if (self.parseChapter(line)) |parsed_chapter| {
                if (parsed_chapter == chapter) {
                    return true;
                } else if (parsed_chapter > chapter) {
                    return false;
                }
            }
        }
        return false;
    }

    fn findVerse(self: WEBParser, verse_number: u8, lines_it: *TokenIterator) bool {
        while (lines_it.peek()) |line| : (_ = lines_it.next()) {
            if (self.parseVerseNumber(line)) |parsed_verse_number| {
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

        var ss_number = try std.ArrayList(u8).initCapacity(self.allocator, 16);
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
        if (!mem.startsWith(u8, line, "\\c ")) {
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

    fn parseLine(self: WEBParser, line: []const u8, footnotes: *std.ArrayList(u8)) ![]const u8 {
        var i: usize = 0;
        var verse = try std.ArrayList(u8).initCapacity(self.allocator, 4 * 1024);
        defer verse.deinit();
        var previous_indentation_level: u8 = 1;
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

                        // skip `\w `
                        i += 3;

                        if (line[i - 1] == '*') {
                            // skip `\w*`
                            continue;
                        }

                        const word_end_i = mem.indexOfScalarPos(u8, line, i, ' ').?;
                        const maybe_strong = mem.indexOfScalarPos(u8, line, i, '|');
                        if (maybe_strong) |strong_idx| {
                            try verse.appendSlice(line[i..strong_idx]);
                            i = strong_idx + 15;
                        } else {
                            try verse.appendSlice(line[i..word_end_i]);
                            i = word_end_i + 1;
                        }
                    },
                    'q' => {
                        var indentation_level = line[i + 2] - '0';
                        try verse.append('\n');
                        while (indentation_level > 0) : (indentation_level -= 1) {
                            try verse.append('\t');
                        }
                        previous_indentation_level = indentation_level;
                        i += 4;
                    },
                    'v' => {
                        i += 3;
                        while (std.ascii.isDigit(line[i])) {
                            i += 1;
                        }
                        i += 1;
                    },
                    'f' => {
                        const fr_begin = mem.indexOfScalarPos(u8, line, i, ':').? + 1;
                        const fr_end = mem.indexOfScalarPos(u8, line, fr_begin, ' ').?;
                        const verse_number = line[fr_begin..fr_end];

                        const ft_begin = mem.indexOfScalarPos(u8, line, fr_end + 1, ' ').? + 1;
                        const ft_end = mem.indexOfPosLinear(u8, line, ft_begin, "\\f*").?;
                        const ft_raw = line[ft_begin..ft_end];

                        var temp = try mem.replaceOwned(u8, self.allocator, ft_raw, "\\+wh ", "");
                        defer self.allocator.free(temp);
                        var temp2 = try mem.replaceOwned(u8, self.allocator, temp, "\\+wh*", "");
                        defer self.allocator.free(temp2);

                        self.allocator.free(temp);
                        temp = try mem.replaceOwned(u8, self.allocator, temp2, "\\+bk ", "“");
                        self.allocator.free(temp2);
                        temp2 = try mem.replaceOwned(u8, self.allocator, temp, "\\+bk*", "”");

                        self.allocator.free(temp);
                        temp = try mem.replaceOwned(u8, self.allocator, temp2, "\\fqa ", "");
                        self.allocator.free(temp2);
                        temp2 = try mem.replaceOwned(u8, self.allocator, temp, "\\fl ", "");

                        self.allocator.free(temp);
                        temp = try mem.replaceOwned(u8, self.allocator, temp2, "\\ft ", "");

                        try footnotes.append('\n');
                        try footnotes.appendSlice(verse_number);
                        try footnotes.appendSlice(": ");
                        try footnotes.appendSlice(mem.trimRight(u8, temp[0..], " "));

                        i = ft_end + 3;
                    },
                    'b' => {
                        if (line[i + 2] == 'k') {
                            if (line[i + 3] == '*') {
                                try verse.appendSlice("”");
                            } else {
                                try verse.appendSlice("“");
                            }
                        }
                        i += 4;
                        continue;
                    },
                    'p' => {
                        if (i + 2 < line.len and line[i + 2] == 'i') {
                            // `\pi `
                            try verse.append('\t');
                            i += 4;
                        } else {
                            if (verse.getLastOrNull()) |last_char| {
                                if (last_char != ' ') {
                                    try verse.append(' ');
                                }
                            } else {
                                try verse.append(' ');
                            }
                            // `\p`
                            i += 3;
                        }
                    },
                    'x' => {
                        // skip `\x...\x*`
                        i = mem.indexOfPos(u8, line, i, "\\x*").? + 3;
                    },
                    'd' => {
                        break;
                    },
                    else => {
                        if (mem.indexOfScalarPos(u8, line, i, ' ')) |j| {
                            i = j + 1;
                        } else {
                            i += 3;
                        }
                    },
                }
            } else if (line[i] == ' ') {
                if (i == line.len - 1 or line[i] == line[i + 1]) {
                    i += 1;
                    continue;
                }
                if (verse.getLastOrNull()) |last_char| {
                    if (last_char != ' ') {
                        try verse.append(line[i]);
                    }
                }
                i += 1;
            } else {
                try verse.append(line[i]);
                i += 1;
            }
        }
        if (verse.getLastOrNull()) |last_char| {
            if (last_char == ' ') {
                _ = verse.pop();
            }
        }
        return try verse.toOwnedSlice();
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
        .Revelation => "96_REVeng_web.usfm"
    };
}
