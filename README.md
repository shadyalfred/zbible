Uses the [World English Bible](https://worldenglish.bible/). Thanks to [eBible.org](https://ebible.org/) for providing the WEB in USFM format.

# Usage

https://github.com/user-attachments/assets/5db90161-d014-442a-af06-5e68c5ebf082

## Whole chapter
`zbible book_name chapter`
## Consecutive verses from the same chapter
`zbible book_name chapter:verse-to_verse`
## Multiple verses from the same chapter
`zbible book_name chapter:verse,verse,verse`
## Multiple verses from different chapters
`zbible book_name chapter:verse,chapter:verse,chapter:verse`
## Consecutive verses from consecutive chapters
`zbible book_name from_chapter:verse-to_chapter:verse`

### N.B. `Psalm 151` is considered a different book from Psalms, do not mix them together.

# Installation
```sh
zig build -Doptimize=ReleaseFast
```
```sh
sudo cp ./zig-out/bin/zbible /usr/bin/
```
```sh
sudo mkdir /usr/share/zbible
```
```sh
sudo cp -r ./eng-web-usfm /usr/share/zbible/
```
Or you can use another location and set the `ZBIBLE_WEB_DIR` environment variable to point to it.

# List of available books
## Old Testament
- Genesis
- Exodus
- Leviticus
- Numbers
- Deuteronomy
- Joshua
- Judges
- Ruth
- First Samuel
- Second Samuel
- First Kings
- Second Kings
- First Chronicles
- Second Chronicles
- Ezra
- Nehemiah
- Esther
- Job
- Psalm
- Proverbs
- Ecclesiastes
- Song of Solomon
- Isaiah
- Jeremiah
- Lamentations
- Ezekiel
- Daniel
- Hosea
- Joel
- Amos
- Obadiah
- Jonah
- Micah
- Nahum
- Habakkuk
- Zephaniah
- Haggai
- Zechariah
- Malachi

## Deuterocanon
- First Esdras
- Second Esdras
- Tobit
- Judith
- Greek Esther
- Greek Daniel
- Wisdom
- Sirach
- Baruch
- Prayer of Manasseh
- First Maccabees
- Second Maccabees
- Third Maccabees
- Fourth Maccabees

## New Testament
- Matthew
- Mark
- Luke
- John
- Acts
- Romans
- First Corinthians
- Second Corinthians
- Galatians
- Ephesians
- Philippians
- Colossians
- First Thessalonians
- Second Thessalonians
- First Timothy
- Second Timothy
- Titus
- Philemon
- Hebrews
- James
- First Peter
- Second Peter
- First John
- Second John
- Third John
- Jude
- Revelation
