const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

pub const BibleReference = struct {
    book: BibleBook,
    chapter: u8,
    from_verse: u8,
    to_verse: ?u8 = null,

    pub fn toString(self: BibleReference, allocator: mem.Allocator) ![]const u8 {
        if (self.to_verse) |to_verse| {
            return try fmt.allocPrint(
                allocator, "{s} {d}:{d}-{d}",
                .{ self.book.toString(), self.chapter, self.from_verse, to_verse }
            );
        } else {
            return try fmt.allocPrint(
                allocator, "{s} {d}:{d}",
                .{ self.book.toString(), self.chapter, self.from_verse }
            );
        }
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

