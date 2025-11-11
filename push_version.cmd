@echo off
setlocal

if "%~1"=="" (
    echo Error: Please provide a version number
    echo Usage: push_version.cmd version "Your version message here"
    exit /b 1
)

if "%~2"=="" (
    echo Error: Please provide a version message
    echo Usage: push_version.cmd version "Your version message here"
    exit /b 1
)

set VERSION=%~1
set MESSAGE=%~2

REM Remove 'v' prefix if present
if "%VERSION:~0,1%"=="v" set VERSION=%VERSION:~1%

echo Pushing changes to git...
git add .
git commit -m "feat: Version %VERSION%: %MESSAGE%"
git tag -a v%VERSION% -m "Version %VERSION%: %MESSAGE%"
git push origin main
git push origin v%VERSION%
echo Done.
pause
