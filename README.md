# NHRA Drag Racing: Top Fuel Thunder - fixes for modern Windows

## End-of-run crash fix

On Windows Vista and later, NHRA Top Fuel Thunder (NHRAX v1.0 Build 365) exits
at the end of every run. `Logs\exceptions.txt` shows:

    RacePakFileDataLoggerTmFile::Write_to_disk: TM_ERROR__FILE_NOT_OPENED

The game's Racepak telemetry code opens its data file with the invalid C
runtime mode strings `"wbf"` / `"rbf"`. Windows XP ignored the stray `f`;
newer versions of `msvcrt.dll` reject it, so the file never opens and the game
shuts down.

The patcher changes three bytes (`f` -> NUL) in your installed copy of the game:

| File | Offset | Change |
|---|---|---|
| `NHRAX.exe` | `0x819C92` | `"wbf"` -> `"wb"` (writing telemetry: the crash) |
| `NHRAX.exe` | `0x819DBA` | `"rbf"` -> `"rb"` (reading it back) |
| `RacePak\TMConvert.exe` | `0x92F6` | `"rbf"` -> `"rb"` (Racepak converter) |

No game files are distributed here.

### Install

1. Download `NHRAX-Telemetry-Fix-v1.0.zip` from the
   [latest release](https://github.com/BobbyHoltzner/top-fuel-thunder/releases/latest)
   and extract it.
2. Close the game and double-click `Apply-Fix.bat`. It finds the game
   automatically. If the game is somewhere else, run it with a path:
   `Apply-Fix.bat -GameDir "D:\Games\NHRAX"`.
3. Start the game and finish a run.

The patcher verifies each file before and after patching (SHA-256 for the
retail Build 365 files) and leaves anything unrecognised untouched. Running it
twice is harmless. To undo, double-click `Restore-Original.bat`.

See [`NHRAX-Telemetry-Fix/README.txt`](NHRAX-Telemetry-Fix/README.txt) for
checksums and tips for other modern-Windows problems (admin prompts, black
screen, windowed mode).
