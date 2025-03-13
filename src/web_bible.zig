const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const hash = std.hash;
const mem = std.mem;

const BibleReference = @import("bible_reference.zig").BibleReference;

const Error = error{BibleBookNotFound};

pub fn getBibleVerses(allocator: mem.Allocator, bible_reference: BibleReference) ![]const u8 {
    const maybe_bible_file_name = getBibleBookFileName(bible_reference.book);

    if (maybe_bible_file_name == null) {
        return Error.BibleBookNotFound;
    }

    var verses = try std.ArrayList(u8).initCapacity(allocator, 1024);
    defer verses.deinit();

    const bible_file_name = maybe_bible_file_name.?;
    var buffer: [64]u8 = undefined;
    const web_usfm_file = try std.fs.cwd().openFile(try fmt.bufPrint(buffer[0..], "./eng-web-usfm/{s}", .{bible_file_name}), .{ .mode = .read_only });
    defer web_usfm_file.close();

    var buffered_reader = io.bufferedReader(web_usfm_file.reader());
    var file_reader = buffered_reader.reader();

    while (try file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024 * 1024)) |line| {
        defer allocator.free(line);
        if (mem.startsWith(u8, line, "\\c")) {
            var it = mem.tokenizeScalar(u8, line, ' ');
            // skip `\c`
            _ = it.next();
            const chapter = try fmt.parseInt(u8, it.next().?, 10);
            if (chapter == bible_reference.chapter) {
                break;
            }
        }
    }

    while (try file_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024 * 1024)) |line| {
        defer allocator.free(line);
        if (mem.startsWith(u8, line, "\\v")) {
            var it = mem.tokenizeScalar(u8, line, ' ');
            // skip `\v`
            _ = it.next();
            const verse = try fmt.parseInt(u8, it.next().?, 10);
            if (verse == bible_reference.from_verse) {
                var i = mem.indexOf(u8, line, "w").?;
                // skip whitespace
                i += 2;
                while (i < line.len) : (i += 1) {
                    // skip `|strong="H####"\w*`
                    if (line[i] == '|') {
                        i += 17;
                        continue;
                    }

                    // skip `\w `
                    if (line[i] == '\\' and line[i+1] == 'w') {
                        i += 3;
                    }

                    try verses.append(line[i]);
                }
                break;
            }
        }
    }

    return verses.toOwnedSlice();
}

fn getBibleBookFileName(bible_book_name: []const u8) ?[]const u8 {
    if (mem.eql(u8, bible_book_name, "genesis")) {
        return "02_GENeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "exodus")) {
        return "03_EXOeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "leviticus")) {
        return "04_LEVeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "numbers")) {
        return "05_NUMeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "deuteronomy")) {
        return "06_DEUeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "joshua")) {
        return "07_JOSeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "judges")) {
        return "08_JDGeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "ruth")) {
        return "09_RUTeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_samuel")) {
        return "10_1SAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_samuel")) {
        return "11_2SAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_kings")) {
        return "12_1KIeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_kings")) {
        return "13_2KIeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_chronicles")) {
        return "14_1CHeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_chronicles")) {
        return "15_2CHeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "ezra")) {
        return "16_EZReng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "nehemiah")) {
        return "17_NEHeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "esther")) {
        return "18_ESTeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "job")) {
        return "19_JOBeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "psalms")) {
        return "20_PSAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "proverbs")) {
        return "21_PROeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "ecclesiastes")) {
        return "22_ECCeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "song_of_solomon")) {
        return "23_SNGeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "isaiah")) {
        return "24_ISAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "jeremiah")) {
        return "25_JEReng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "lamentations")) {
        return "26_LAMeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "ezekiel")) {
        return "27_EZKeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "daniel")) {
        return "28_DANeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "hosea")) {
        return "29_HOSeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "joel")) {
        return "30_JOLeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "amos")) {
        return "31_AMOeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "obadiah")) {
        return "32_OBAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "jonah")) {
        return "33_JONeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "micah")) {
        return "34_MICeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "nahum")) {
        return "35_NAMeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "habakkuk")) {
        return "36_HABeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "zephaniah")) {
        return "37_ZEPeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "haggai")) {
        return "38_HAGeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "zechariah")) {
        return "39_ZECeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "malachi")) {
        return "40_MALeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "tobit")) {
        return "41_TOBeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "judith")) {
        return "42_JDTeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "greek_esther")) {
        return "43_ESGeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "wisdom")) {
        return "45_WISeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "sirach")) {
        return "46_SIReng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "baruch")) {
        return "47_BAReng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_maccabees")) {
        return "52_1MAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_maccabees")) {
        return "53_2MAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_esdras")) {
        return "54_1ESeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "prayer_of_manasseh")) {
        return "55_MANeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "third_maccabees")) {
        return "57_3MAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_esdras")) {
        return "58_2ESeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "fourth_maccabees")) {
        return "59_4MAeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "greek_daniel")) {
        return "66_DAGeng_web.usfm";

    } else if (mem.eql(u8, bible_book_name, "matthew")) {
        return "70_MATeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "mark")) {
        return "71_MRKeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "luke")) {
        return "72_LUKeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "john")) {
        return "73_JHNeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "acts")) {
        return "74_ACTeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "romans")) {
        return "75_ROMeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_corinthians")) {
        return "76_1COeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_corinthians")) {
        return "77_2COeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "galatians")) {
        return "78_GALeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "ephesians")) {
        return "79_EPHeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "philippians")) {
        return "80_PHPeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "colossians")) {
        return "81_COLeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_thessalonians")) {
        return "82_1THeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_thessalonians")) {
        return "83_2THeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_timothy")) {
        return "84_1TIeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_timothy")) {
        return "85_2TIeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "titus")) {
        return "86_TITeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "philemon")) {
        return "87_PHMeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "hebrews")) {
        return "88_HEBeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "james")) {
        return "89_JASeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_peter")) {
        return "90_1PEeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_peter")) {
        return "91_2PEeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "first_john")) {
        return "92_1JNeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "second_john")) {
        return "93_2JNeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "third_john")) {
        return "94_3JNeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "jude")) {
        return "95_JUDeng_web.usfm";
    } else if (mem.eql(u8, bible_book_name, "revelation_of_john")) {
        return "96_REVeng_web.usfm";
    } else {
        return null;
    }
}
