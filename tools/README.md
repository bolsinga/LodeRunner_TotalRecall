# tools/

Offline utilities for extracting Lode Runner levels from original disk
images. Not loaded by the web game (lodeRunner.html never references
this folder).

| Piece | Role |
|-------|------|
| `LodeRunnerDiskParser.cpp` | Apple II disk to level maps (nibble format documented in the `.cpp` header) |
| `pzlDiskParser.cpp` | Related disk / puzzle parser |
| `cmpDate.cpp` | Small file mtime compare helper |
| `apple2.dsk/` | Source Apple II disk images |
| `c64.dsk/` | Source C64 disk images |

Build the parsers from source as needed; the disk image trees are
input data only.
