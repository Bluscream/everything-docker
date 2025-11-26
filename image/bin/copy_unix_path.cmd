@echo off
REM Convert Windows path (Z:\mnt\...) to Unix path (/mnt/...) and copy to clipboard
REM Usage: copy_unix_path.cmd "Z:\mnt\user\appdata"

setlocal enabledelayedexpansion

REM Get the path from first argument
set "winpath=%~1"

REM Remove Z:\ prefix and convert backslashes to forward slashes
set "unixpath=!winpath:Z:\=!"
set "unixpath=!unixpath:\=/!"

REM Add leading slash if path doesn't start with /
if not "!unixpath:~0,1!"=="/" set "unixpath=/!unixpath!"

REM Copy to clipboard using clip.exe (Windows built-in utility)
echo !unixpath!| clip.exe

endlocal
