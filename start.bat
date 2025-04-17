@echo off
REM ── Determine the folder where this .bat lives:
SET SCRIPT_DIR=%~dp0

REM ── Run the shell script under Git Bash:
"C:\Program Files\Git\bin\bash.exe" "%SCRIPT_DIR%start.sh"

REM ── Keep the window open so you can read any output:
pause