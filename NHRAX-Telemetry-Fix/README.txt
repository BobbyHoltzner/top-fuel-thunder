NHRA Drag Racing: Top Fuel Thunder - End-of-Run Crash Fix
==========================================================
For NHRAX v1.0 Build 365 (Dec 4 2003) on Windows Vista, 7, 8, 10 and 11.


THE PROBLEM
-----------
On anything newer than Windows XP the game exits at the end of every run.
Logs\exceptions.txt shows:

    RacePakFileDataLoggerTmFile::Write_to_disk: TM_ERROR__FILE_NOT_OPENED

The Racepak telemetry code opens its data file with the C runtime call
fopen() using the mode strings "wbf" and "rbf". The trailing "f" is not a
valid mode letter. Windows XP's msvcrt.dll silently ignored it. The
msvcrt.dll that ships with Vista and later checks mode strings and rejects
unknown letters, so the file never opens, the game throws an error nothing
catches, and it shuts down.

The msvcrt.dll in the game folder does not help: msvcrt is a protected
system DLL and Windows always loads its own copy.


THE FIX
-------
Three bytes are changed from "f" to a NUL, so the modes become "wb"/"rb":

    NHRAX.exe               offset 0x819C92   "wbf" -> "wb"   (write telemetry - the crash)
    NHRAX.exe               offset 0x819DBA   "rbf" -> "rb"   (read telemetry back)
    RacePak\TMConvert.exe   offset 0x92F6     "rbf" -> "rb"   (Racepak converter)

Nothing else is touched. No game files are included in this package; the
patcher modifies your own installed copy.


HOW TO INSTALL
--------------
1. Close the game.
2. Double-click Apply-Fix.bat.
   - It finds the game automatically (installer registry entry or the
     default C:\Program Files (x86)\Emotorsports\NHRAX).
   - If the game is in Program Files, Windows asks for administrator
     permission once - this is only to change the two files.
   - Other location:  Apply-Fix.bat -GameDir "D:\Games\NHRAX"
3. Start the game normally and finish a run. The game may minimize for a
   moment while TMConvert builds the Racepak file - that is expected.
   Converted runs are written to C:\RacePakData\MotorSims\TopFuel\ (or
   ProStock\).

The patcher checks each file before changing it:
  - Known retail Build 365 files are patched and verified by SHA-256.
  - Other copies are patched only if the exact bytes are where expected.
  - Anything else is left untouched with an error message.
Running it twice is harmless.

TO UNDO: double-click Restore-Original.bat. The originals were saved as
NHRAX.exe.pre-fopen-fix and TMConvert.exe.pre-fopen-fix.


SHA-256 (retail Build 365)
--------------------------
NHRAX.exe       original  892793F0EBC1118EC232BBC8040247E9F01C8DA3E1C0D8AA863ED09FFDF3EAE8
NHRAX.exe       patched   943D5F473D852EB833B42121445EB1011B3C0D5D579AA5D792FBF5DE931ACD5D
TMConvert.exe   original  6BB4FD0B100467B4A0EAE5B23B7938B164E3639C5D8435543253637483E3120C
TMConvert.exe   patched   5546EDED0F1846ECAEF55C46332378B41835706B8287417CA82FEC3FE52104AA


OTHER PROBLEMS ON MODERN WINDOWS
--------------------------------
Game asks for administrator permission every time it starts
  Usually caused by compatibility settings applied to NHRAX.exe (for
  example "Windows XP (Service Pack 3)" mode). Right-click NHRAX.exe ->
  Properties -> Compatibility and clear those options, including under
  "Change settings for all users". Running as administrator makes the game
  ignore your normal settings, so it is worth fixing.

Black screen, then the game drops back to the desktop (still running)
  The game's fullscreen 16-bit mode does not work well on modern displays.
  Use windowed mode: close the game, open
      %LOCALAPPDATA%\VirtualStore\Program Files (x86)\Emotorsports\NHRAX\UserData\profile\settings.cfg
  (or UserData\profile\settings.cfg in the game folder if the game is not
  in Program Files) and change
      Mode = FULL;   ->   Mode = WINDOWED;

Window is tiny
  In the same settings.cfg, set the Window block to your desktop size as
  the game sees it (on a scaled 4K screen at 150% that is 2560 x 1440):
      Window = {
          Width = 2560;
          Height = 1440;
          bpp = 16;
      }
  The title bar will hang slightly off-screen. A DirectDraw wrapper such as
  dgVoodoo2 can give true borderless fullscreen if you prefer.
