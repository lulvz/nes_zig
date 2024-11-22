# NES emulator written in Zig

This project is an emulator of the NES console, right now only background rendering is implemented, I will have to come back and implement sprite rendering in the future. The CPU and controllers, however, work completely.
The code is divided into the multiple components that make up the NES console.

![Screenshot](/images/sc.png)

## 6502 CPU
The 6502 is fully implemented, all memory modes and instructions are working fine.

### Technical Points
- Implemented all official CPU instructions and addressing modes
- Built the CPU's core architecture including registers, status flags, and memory interactions
- Created efficient interrupt handling system (IRQ/NMI) matching original hardware behavior
- Used Zig's packed structs for optimal memory layout of CPU status flags

### Future Improvements
- Cycle-accurate timing implementation
- More detailed logging capabilities
- Performance optimizations
- Additional test coverage for edge cases

## Bus
The bus connects all the components of the console and provides methods for easy memory access/manipulation.

## PPU
The PPU is partially implemented with current support for:

- Background rendering using pattern tables
- Nametable mirroring
- Basic palette handling
- PPU register interface

### Future work includes:
- Sprite rendering implementation
- Cycle-accurate timing
- Advanced effects support (sprite 0 hit, etc.)

## PPU_BUS
This is the bus just for the ppu.

## Cartridge
The cartridge uses a union that can have a single implementation of the mapper, making it easily expandable, as right now it only supports mapper 0.