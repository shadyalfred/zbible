const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

pub const VerseRange = struct {
    from_chapter: u8,
    to_chapter: ?u8 = null,
    from_verse: ?u8 = null,
    to_verse: ?u8 = null
};

pub const BibleReference = struct {
    book: BibleBook,
    verse_ranges: []const VerseRange,

    pub fn toString(self: BibleReference, allocator: mem.Allocator) ![]const u8 {
        var sb = try std.ArrayList(u8).initCapacity(allocator, 1024);
        defer sb.deinit();

        var buffer: [1024]u8 = undefined;

        try sb.appendSlice(self.book.toString());
        try sb.append(' ');

        for (self.verse_ranges) |verse_range| {
            try sb.appendSlice(try fmt.bufPrint(&buffer, "{d}", .{verse_range.from_chapter}));

            if (verse_range.from_verse) |from_verse| {
                try sb.appendSlice(try fmt.bufPrint(&buffer, ":{d}", .{from_verse}));
            }

            if (verse_range.to_chapter) |to_chapter| {
                try sb.appendSlice(try fmt.bufPrint(&buffer, "-{d}:{d}", .{to_chapter, verse_range.to_verse.?}));
            } else if (verse_range.to_verse) |to_verse| {
                try sb.appendSlice(try fmt.bufPrint(&buffer, "-{d}", .{to_verse}));
            }

            try sb.appendSlice(", ");
        }

        _ = sb.pop();
        _ = sb.pop();

        return try sb.toOwnedSlice();
    }

    pub fn deinit(self: BibleReference, allocator: mem.Allocator) void {
        allocator.free(self.verse_ranges);
    }
};

pub const BibleBook = enum {
    Genesis,
    Exodus,
    Leviticus,
    Numbers,
    Deuteronomy,
    Joshua,
    Judges,
    Ruth,
    FirstSamuel,
    SecondSamuel,
    FirstKings,
    SecondKings,
    FirstChronicles,
    SecondChronicles,
    Ezra,
    Nehemiah,
    Esther,
    Job,
    Psalms,
    Proverbs,
    Ecclesiastes,
    SongOfSolomon,
    Isaiah,
    Jeremiah,
    Lamentations,
    Ezekiel,
    Daniel,
    Hosea,
    Joel,
    Amos,
    Obadiah,
    Jonah,
    Micah,
    Nahum,
    Habakkuk,
    Zephaniah,
    Haggai,
    Zechariah,
    Malachi,

    FirstEsdras,
    SecondEsdras,
    Tobit,
    Judith,
    GreekEsther,
    GreekDaniel,
    Wisdom,
    Sirach,
    Baruch,
    PrayerOfAzariah,
    Susanna,
    BelAndTheDragon,
    PrayerOfManasseh,
    FirstMaccabees,
    SecondMaccabees,
    ThirdMaccabees,
    FourthMaccabees,

    Matthew,
    Mark,
    Luke,
    John,
    Acts,
    Romans,
    FirstCorinthians,
    SecondCorinthians,
    Galatians,
    Ephesians,
    Philippians,
    Colossians,
    FirstThessalonians,
    SecondThessalonians,
    FirstTimothy,
    SecondTimothy,
    Titus,
    Philemon,
    Hebrews,
    James,
    FirstPeter,
    SecondPeter,
    FirstJohn,
    SecondJohn,
    ThirdJohn,
    Jude,
    Revelation,

    fn toString(self: BibleBook) []const u8 {
        return switch (self) {
            .Genesis => "Genesis",
            .Exodus => "Exodus",
            .Leviticus => "Leviticus",
            .Numbers => "Numbers",
            .Deuteronomy => "Deuteronomy",
            .Joshua => "Joshua",
            .Judges => "Judges",
            .Ruth => "Ruth",
            .FirstSamuel => "First Samuel",
            .SecondSamuel => "Second Samuel",
            .FirstKings => "First Kings",
            .SecondKings => "Second Kings",
            .FirstChronicles => "First Chronicles",
            .SecondChronicles => "Second Chronicles",
            .Ezra => "Ezra",
            .Nehemiah => "Nehemiah",
            .Esther => "Esther",
            .Job => "Job",
            .Psalms => "Psalm",
            .Proverbs => "Proverbs",
            .Ecclesiastes => "Ecclesiastes",
            .SongOfSolomon => "Song of Solomon",
            .Isaiah => "Isaiah",
            .Jeremiah => "Jeremiah",
            .Lamentations => "Lamentations",
            .Ezekiel => "Ezekiel",
            .Daniel => "Daniel",
            .Hosea => "Hosea",
            .Joel => "Joel",
            .Amos => "Amos",
            .Obadiah => "Obadiah",
            .Jonah => "Jonah",
            .Micah => "Micah",
            .Nahum => "Nahum",
            .Habakkuk => "Habakkuk",
            .Zephaniah => "Zephaniah",
            .Haggai => "Haggai",
            .Zechariah => "Zechariah",
            .Malachi => "Malachi",

            .FirstEsdras => "First Esdras",
            .SecondEsdras => "Second Esdras",
            .Tobit => "Tobit",
            .Judith => "Judith",
            .GreekEsther => "Greek Esther",
            .GreekDaniel => "Greek Daniel",
            .Wisdom => "Wisdom",
            .Sirach => "Sirach",
            .Baruch => "Baruch",
            .PrayerOfAzariah => "Prayer of Azariah",
            .Susanna => "Susanna",
            .BelAndTheDragon => "Bel and the Dragon",
            .PrayerOfManasseh => "Prayer of Manasseh",
            .FirstMaccabees => "First Maccabees",
            .SecondMaccabees => "Second Maccabees",
            .ThirdMaccabees => "Third Maccabees",
            .FourthMaccabees => "Fourth Maccabees",

            .Matthew => "Matthew",
            .Mark => "Mark",
            .Luke => "Luke",
            .John => "John",
            .Acts => "Acts",
            .Romans => "Romans",
            .FirstCorinthians => "First Corinthians",
            .SecondCorinthians => "Second Corinthians",
            .Galatians => "Galatians",
            .Ephesians => "Ephesians",
            .Philippians => "Philippians",
            .Colossians => "Colossians",
            .FirstThessalonians => "First Thessalonians",
            .SecondThessalonians => "Second Thessalonians",
            .FirstTimothy => "First Timothy",
            .SecondTimothy => "Second Timothy",
            .Titus => "Titus",
            .Philemon => "Philemon",
            .Hebrews => "Hebrews",
            .James => "James",
            .FirstPeter => "First Peter",
            .SecondPeter => "Second Peter",
            .FirstJohn => "First John",
            .SecondJohn => "Second John",
            .ThirdJohn => "Third John",
            .Jude => "Jude",
            .Revelation => "Revelation"
        };
    }
};

test "print bible references" {
    const debug = std.debug;
    const testing = std.testing;
    const log = std.log;
    const allocator = testing.allocator;

    const bible_references = [_]BibleReference {
        BibleReference {
            .book = .Genesis,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 1,
                }
            }
        },
        BibleReference {
            .book = .Genesis,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 1,
                    .from_verse = 1,
                }
            }
        },
        BibleReference {
            .book = .Genesis,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 1,
                    .from_verse = 1,
                    .to_verse = 2,
                }
            }
        },
        BibleReference {
            .book = .Genesis,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 1,
                    .from_verse = 1,
                    .to_chapter = 2,
                    .to_verse = 1,
                }
            }
        },
        BibleReference {
            .book = .SecondEsdras,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 1,
                },
                VerseRange {
                    .from_chapter = 2,
                    .from_verse = 1,
                },
                VerseRange {
                    .from_chapter = 2,
                    .from_verse = 3,
                    .to_verse = 5,
                },
                VerseRange {
                    .from_chapter = 3,
                    .from_verse = 1,
                    .to_chapter = 4,
                    .to_verse = 1,
                },
            }
        },
        BibleReference {
            .book = .John,
            .verse_ranges = &[_]VerseRange{
                VerseRange {
                    .from_chapter = 3,
                },
                VerseRange {
                    .from_chapter = 4,
                    .from_verse = 2,
                },
                VerseRange {
                    .from_chapter = 5,
                    .from_verse = 10,
                    .to_verse = 12,
                },
                VerseRange {
                    .from_chapter = 6,
                    .from_verse = 1,
                    .to_chapter = 7,
                    .to_verse = 15,
                },
            }
        },
    };

    const expected_values = [_][]const u8 {
        "Genesis 1",
        "Genesis 1:1",
        "Genesis 1:1-2",
        "Genesis 1:1-2:1",
        "Second Esdras 1, 2:1, 2:3-5, 3:1-4:1",
        "John 3, 4:2, 5:10-12, 6:1-7:15",
    };

    for (bible_references, 0..) |bible_reference, i| {
        const bible_reference_str = try bible_reference.toString(allocator);
        defer allocator.free(bible_reference_str);
        if (!mem.eql(u8, bible_reference_str, expected_values[i])) {
            log.err("expected `{s}`", .{expected_values[i]});
            log.err("found `{s}`\n", .{bible_reference_str});
            debug.assert(false);
        }
    }
    debug.assert(true);
}
