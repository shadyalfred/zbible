Uses the [World English Bible](https://worldenglish.bible/). Thanks to [eBible.org](https://ebible.org/) for providing the WEB in USFM format.

# Installation
```sh
zig build -Doptimize=ReleaseSafe
```
```sh
sudo mkdir /usr/share/zbible
```
```sh
sudo cp -r ./eng-web-usfm /usr/share/zbible/
```
```sh
sudo cp ./zig-out/bin/zbible /usr/bin/
```

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
