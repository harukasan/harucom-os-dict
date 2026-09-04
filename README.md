# harucom-os-dict

Dictionary data for [Harucom OS](https://github.com/harukasan/harucom-os)
Japanese input methods (SKK and T-Code).

This repository is distributed separately from the Harucom OS firmware because
the dictionary data is licensed under GPL-2.0. The firmware reads the dictionary
from a dedicated flash region via XIP, without linking it into the firmware
binary.

## Data sources

- **SKK dictionary**: [SKK-JISYO](https://github.com/skk-dev/dict) (GPL-2.0-or-later)
- **T-Code table**: [tc](https://github.com/kanchoku/tc) (GPL-2.0-or-later)

## Build

Dictionary sources are included as git submodules:

- `data/skk-dev-dict/` ([skk-dev/dict](https://github.com/skk-dev/dict))
- `data/tc/` ([kanchoku/tc](https://github.com/kanchoku/tc))

Initialize submodules and build:

```sh
git submodule update --init
rake
```

This produces `build/dict.uf2`.

### Flash

Write the dictionary to the Harucom Board. The dictionary occupies a 2 MB
region at flash offset `0x00600000`, separate from the firmware.

Via picotool (BOOTSEL mode):

```sh
picotool load build/dict.uf2
```

Via openocd (picoprobe/CMSIS-DAP):

```sh
rake flashocd
```

## Binary format

The UF2 writes to XIP address `0x10600000` with the following layout:

| Offset | Field | Description |
|--------|-------|-------------|
| 0 | magic | `0x4B444348` ("HCDK") |
| 4 | version | Format version (currently 2) |
| 8 | section_count | Number of sections |
| 12 | sections[] | Section descriptors (type, offset, size) |
| ... | section data | SKK hash table, T-Code lookup table |

### SKK section (type 1)

Hash table with FNV-1a hashing. Each entry contains a reading (UTF-8) and
its conversion candidates.

### T-Code section (type 2)

40x40 array of uint16 Unicode codepoints for two-stroke direct kanji input,
indexed as `table[first stroke * 40 + second stroke]`. A zero means the pair
carries no character.

## License

Copyright © 2026 Shunsuke Michii

Licensed under the [GNU General Public License v2.0 or later](LICENSE.txt).
