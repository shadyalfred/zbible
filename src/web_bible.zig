const std = @import("std");
const heap = std.heap;
const fmt = std.fmt;
const mem = std.mem;
const ascii = std.ascii;
const fs = std.fs;

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
    has_multiple_chapters: bool = false,

    pub fn init(gpa: mem.Allocator, arena_impl: *heap.ArenaAllocator) WEBParser {
        return WEBParser{
            .gpa = gpa,
            .arena_impl = arena_impl,
            .arena = arena_impl.allocator(),
        };
    }

    pub fn deinit(self: WEBParser) void {
        _ = self.arena_impl.reset(.free_all);
    }

    pub fn getBiblePassage(self: *WEBParser, bible_reference: BibleReference) ![]const u8 {
        self.has_multiple_chapters = hasMultipleChapters(bible_reference);

        defer _ = self.arena_impl.reset(.free_all);

        var passage = try std.ArrayList(u8).initCapacity(self.gpa, 4 * 1024);
        defer passage.deinit();

        var footnotes = try std.ArrayList(u8).initCapacity(self.gpa, 2 * 1024);
        defer footnotes.deinit();

        const bible_book =
            if (bible_reference.book == .Psalms and bible_reference.verse_ranges[0].from_chapter == 151)
                @embedFile("./eng-web-usfm/56_PS2eng_web.usfm")
            else
                getBibleBook(bible_reference.book);

        var lines_it = TokenIterator{ .buffer = bible_book, .delimiter = '\n' };

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
                            if (passage.getLastOrNull()) |last_char| {
                                if (last_char == '\n' and parsed_line[0] == last_char) {
                                    try passage.appendSlice(parsed_line[1..]);
                                } else {
                                    try passage.appendSlice(parsed_line[1..]);
                                }
                            }
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
                            if (!(last_char == '\n' or last_char == '\t') and
                                !(parsed_line[0] == '\t' or parsed_line[0] == '\n'))
                            {
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

        if (mem.indexOfScalar(u8, word, '\\')) |r| {
            return word[0..r];
        }

        var r = word.len - 1;
        while (
            r > 0 and
            (ascii.isWhitespace(word[r]) or !ascii.isAlphabetic(word[r]))
        ) {
            r -= 1;
        }

        return word[0..(r + 1)];
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
                        if (line[i + 2] == 's') {
                            if (line[i + 3] == '*') {
                                i += 5;
                            } else {
                                i += 4;
                            }

                            try parsed_line.append('\n');

                            continue;
                        }
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

                        const fr_begin = mem.indexOfScalarPos(u8, line, i, ':').? + 1;
                        const fr_end = mem.indexOfScalarPos(u8, line, fr_begin, ' ').?;
                        const verse_number = line[fr_begin..fr_end];

                        const ft_begin = mem.indexOfScalarPos(u8, line, fr_end + 1, ' ').? + 1;
                        const ft_end = mem.indexOfPosLinear(u8, line, ft_begin, "\\f*").?;
                        const ft_raw = line[ft_begin..ft_end];

                        if (ascii.isAlphabetic(line[ft_end + 3]) or i <= 6) {
                            var word_begin = ft_end + 3;
                            if (line[word_begin] == ' ') {
                                word_begin += 1;
                            }
                            var word_end = mem.indexOfScalarPos(u8, line, word_begin, ' ').?;

                            if (word_end - word_begin <= 3) {
                                const temp = mem.indexOfScalarPos(u8, line, word_end + 1, ' ');
                                if (temp != null) {
                                    word_end = temp.?;
                                }
                            }

                            maybe_word = cleanUpWord(line[word_begin..word_end]);
                            if (maybe_word.?.len <= 1) {
                                maybe_word = null;
                            }
                        }

                        const ft = self.parseFootnote(ft_raw);

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
                        } else {
                            try footnotes.appendSlice(try fmt.allocPrint(self.arena, "({s}) ", .{getLastWord(parsed_line)}));
                        }
                        try footnotes.appendSlice(ft);

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
                    'd', 'c', 's' => {
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

    fn getLastWord(parsed_line: std.ArrayList(u8)) []const u8 {
        var r = parsed_line.items.len - 1;
        while (r > 0 and parsed_line.items[r] == ' ') {
            r -= 1;
        }

        var l = r;
        while (l > 0 and parsed_line.items[l] != ' ') {
            l -= 1;
        }

        if (r - l <= 3) {
            l -= 1;

            while (l > 0 and parsed_line.items[l] != ' ') {
                l -= 1;
            }
        }

        l += 1;
        while (l < r and !ascii.isAlphabetic(parsed_line.items[l])) {
            l += 1;
        }

        while (r > l and !ascii.isAlphabetic(parsed_line.items[r])) {
            r -= 1;
        }
        r += 1;

        return parsed_line.items[l..r];
    }

    fn parseFootnote(self: WEBParser, ft_raw: []const u8) []const u8 {
        var ft = std.ArrayList(u8).initCapacity(self.arena, 4 * 1024) catch unreachable;
        defer ft.deinit();

        var i: usize = 0;
        while (i < ft_raw.len) {
            if (ft_raw[i] == '\\') {
                if (ft_raw[i + 1] == '+') {
                    if (ft_raw[i + 2] == 'b' and ft_raw[i + 3] == 'k') {
                        if (ft_raw[i + 4] == '*') {
                            ft.appendSlice("”") catch unreachable;
                        } else {
                            ft.appendSlice("“") catch unreachable;
                        }
                    }
                    i += 5;
                } else {
                    if (ft_raw[i + 1] == 'f') {
                        if (ft_raw[i + 2] == 'q') {
                            i += 5;
                        } else {
                            i += 4;
                        }
                    }
                }
            } else {
                ft.append(ft_raw[i]) catch unreachable;
                i += 1;
            }
        }

        if (ft.getLastOrNull()) |last_char| {
            if (last_char == ' ') {
                _ = ft.pop();
            }
        }

        return ft.toOwnedSlice() catch unreachable;
    }
};

fn getBibleBook(bible_book: BibleBook) []const u8 {
    return switch (bible_book) {
        .Genesis => @embedFile("./eng-web-usfm/02_GENeng_web.usfm"),
        .Exodus => @embedFile("./eng-web-usfm/03_EXOeng_web.usfm"),
        .Leviticus => @embedFile("./eng-web-usfm/04_LEVeng_web.usfm"),
        .Numbers => @embedFile("./eng-web-usfm/05_NUMeng_web.usfm"),
        .Deuteronomy => @embedFile("./eng-web-usfm/06_DEUeng_web.usfm"),
        .Joshua => @embedFile("./eng-web-usfm/07_JOSeng_web.usfm"),
        .Judges => @embedFile("./eng-web-usfm/08_JDGeng_web.usfm"),
        .Ruth => @embedFile("./eng-web-usfm/09_RUTeng_web.usfm"),
        .FirstSamuel => @embedFile("./eng-web-usfm/10_1SAeng_web.usfm"),
        .SecondSamuel => @embedFile("./eng-web-usfm/11_2SAeng_web.usfm"),
        .FirstKings => @embedFile("./eng-web-usfm/12_1KIeng_web.usfm"),
        .SecondKings => @embedFile("./eng-web-usfm/13_2KIeng_web.usfm"),
        .FirstChronicles => @embedFile("./eng-web-usfm/14_1CHeng_web.usfm"),
        .SecondChronicles => @embedFile("./eng-web-usfm/15_2CHeng_web.usfm"),
        .Ezra => @embedFile("./eng-web-usfm/16_EZReng_web.usfm"),
        .Nehemiah => @embedFile("./eng-web-usfm/17_NEHeng_web.usfm"),
        .Esther => @embedFile("./eng-web-usfm/18_ESTeng_web.usfm"),
        .Job => @embedFile("./eng-web-usfm/19_JOBeng_web.usfm"),
        .Psalms => @embedFile("./eng-web-usfm/20_PSAeng_web.usfm"),
        .Proverbs => @embedFile("./eng-web-usfm/21_PROeng_web.usfm"),
        .Ecclesiastes => @embedFile("./eng-web-usfm/22_ECCeng_web.usfm"),
        .SongOfSolomon => @embedFile("./eng-web-usfm/23_SNGeng_web.usfm"),
        .Isaiah => @embedFile("./eng-web-usfm/24_ISAeng_web.usfm"),
        .Jeremiah => @embedFile("./eng-web-usfm/25_JEReng_web.usfm"),
        .Lamentations => @embedFile("./eng-web-usfm/26_LAMeng_web.usfm"),
        .Ezekiel => @embedFile("./eng-web-usfm/27_EZKeng_web.usfm"),
        .Daniel => @embedFile("./eng-web-usfm/28_DANeng_web.usfm"),
        .Hosea => @embedFile("./eng-web-usfm/29_HOSeng_web.usfm"),
        .Joel => @embedFile("./eng-web-usfm/30_JOLeng_web.usfm"),
        .Amos => @embedFile("./eng-web-usfm/31_AMOeng_web.usfm"),
        .Obadiah => @embedFile("./eng-web-usfm/32_OBAeng_web.usfm"),
        .Jonah => @embedFile("./eng-web-usfm/33_JONeng_web.usfm"),
        .Micah => @embedFile("./eng-web-usfm/34_MICeng_web.usfm"),
        .Nahum => @embedFile("./eng-web-usfm/35_NAMeng_web.usfm"),
        .Habakkuk => @embedFile("./eng-web-usfm/36_HABeng_web.usfm"),
        .Zephaniah => @embedFile("./eng-web-usfm/37_ZEPeng_web.usfm"),
        .Haggai => @embedFile("./eng-web-usfm/38_HAGeng_web.usfm"),
        .Zechariah => @embedFile("./eng-web-usfm/39_ZECeng_web.usfm"),
        .Malachi => @embedFile("./eng-web-usfm/40_MALeng_web.usfm"),

        .Tobit => @embedFile("./eng-web-usfm/41_TOBeng_web.usfm"),
        .Judith => @embedFile("./eng-web-usfm/42_JDTeng_web.usfm"),
        .GreekEsther => @embedFile("./eng-web-usfm/43_ESGeng_web.usfm"),
        .Wisdom => @embedFile("./eng-web-usfm/45_WISeng_web.usfm"),
        .Sirach => @embedFile("./eng-web-usfm/46_SIReng_web.usfm"),
        .Baruch => @embedFile("./eng-web-usfm/47_BAReng_web.usfm"),
        .FirstMaccabees => @embedFile("./eng-web-usfm/52_1MAeng_web.usfm"),
        .SecondMaccabees => @embedFile("./eng-web-usfm/53_2MAeng_web.usfm"),
        .FirstEsdras => @embedFile("./eng-web-usfm/54_1ESeng_web.usfm"),
        .PrayerOfManasseh => @embedFile("./eng-web-usfm/55_MANeng_web.usfm"),
        .ThirdMaccabees => @embedFile("./eng-web-usfm/57_3MAeng_web.usfm"),
        .SecondEsdras => @embedFile("./eng-web-usfm/58_2ESeng_web.usfm"),
        .FourthMaccabees => @embedFile("./eng-web-usfm/59_4MAeng_web.usfm"),
        .GreekDaniel => @embedFile("./eng-web-usfm/66_DAGeng_web.usfm"),

        .PrayerOfAzariah => @panic("look up Greek Daniel"),
        .Susanna => @panic("look up Greek Daniel"),
        .BelAndTheDragon => @panic("look up Greek Daniel"),

        .Matthew => @embedFile("./eng-web-usfm/70_MATeng_web.usfm"),
        .Mark => @embedFile("./eng-web-usfm/71_MRKeng_web.usfm"),
        .Luke => @embedFile("./eng-web-usfm/72_LUKeng_web.usfm"),
        .John => @embedFile("./eng-web-usfm/73_JHNeng_web.usfm"),
        .Acts => @embedFile("./eng-web-usfm/74_ACTeng_web.usfm"),
        .Romans => @embedFile("./eng-web-usfm/75_ROMeng_web.usfm"),
        .FirstCorinthians => @embedFile("./eng-web-usfm/76_1COeng_web.usfm"),
        .SecondCorinthians => @embedFile("./eng-web-usfm/77_2COeng_web.usfm"),
        .Galatians => @embedFile("./eng-web-usfm/78_GALeng_web.usfm"),
        .Ephesians => @embedFile("./eng-web-usfm/79_EPHeng_web.usfm"),
        .Philippians => @embedFile("./eng-web-usfm/80_PHPeng_web.usfm"),
        .Colossians => @embedFile("./eng-web-usfm/81_COLeng_web.usfm"),
        .FirstThessalonians => @embedFile("./eng-web-usfm/82_1THeng_web.usfm"),
        .SecondThessalonians => @embedFile("./eng-web-usfm/83_2THeng_web.usfm"),
        .FirstTimothy => @embedFile("./eng-web-usfm/84_1TIeng_web.usfm"),
        .SecondTimothy => @embedFile("./eng-web-usfm/85_2TIeng_web.usfm"),
        .Titus => @embedFile("./eng-web-usfm/86_TITeng_web.usfm"),
        .Philemon => @embedFile("./eng-web-usfm/87_PHMeng_web.usfm"),
        .Hebrews => @embedFile("./eng-web-usfm/88_HEBeng_web.usfm"),
        .James => @embedFile("./eng-web-usfm/89_JASeng_web.usfm"),
        .FirstPeter => @embedFile("./eng-web-usfm/90_1PEeng_web.usfm"),
        .SecondPeter => @embedFile("./eng-web-usfm/91_2PEeng_web.usfm"),
        .FirstJohn => @embedFile("./eng-web-usfm/92_1JNeng_web.usfm"),
        .SecondJohn => @embedFile("./eng-web-usfm/93_2JNeng_web.usfm"),
        .ThirdJohn => @embedFile("./eng-web-usfm/94_3JNeng_web.usfm"),
        .Jude => @embedFile("./eng-web-usfm/95_JUDeng_web.usfm"),
        .Revelation => @embedFile("./eng-web-usfm/96_REVeng_web.usfm"),
    };
}
