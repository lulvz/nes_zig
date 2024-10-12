# NES PPU Memory Map and Address Decoding

The PPU has its own bus separate from the main bus.

It also has 8 registers, which are not actual registers but addresses used for the CPU to communicate with the PPU.

## NES CPU Memory Regions

| Address Range | Size   | Description             | Mapped by         |
|---------------|--------|-------------------------|-------------------|
| $0000-$0FFF   | $1000  | Pattern table 0          | Cartridge         |
| $1000-$1FFF   | $1000  | Pattern table 1          | Cartridge         |
| $2000-$23BF   | $0400  | Nametable 0              | Cartridge         |
| $2400-$27FF   | $0400  | Nametable 1              | Cartridge         |
| $2800-$2BFF   | $0400  | Nametable 2              | Cartridge         |
| $2C00-$2FFF   | $0400  | Nametable 3              | Cartridge         |
| $3000-$3EFF   | $0F00  | Unused                   | Cartridge         |
| $3F00-$3F1F   | $0020  | Palette RAM indexes      | Internal to PPU   |
| $3F20-$3FFF   | $00E0  | Mirrors of $3F00-$3F1F   | Internal to PPU   |
