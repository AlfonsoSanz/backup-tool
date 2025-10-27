@echo off

:: Set file or folder to copy (without ending \)
set source=C:\Users\test1
set destination=C:\Users\Backups

:: Extract file path and name
for %%F in ("%source%") do (
    set "source_location=%%~dpF"
    set "source_name=%%~nxF"
)

:: Delay in seconds
set period=600

:loop
    :: Replace ':' with '.'
    set t=%time::=.%
    :: Remove miliseconds
    set t=%t:~0,8%
    :: Replace space with leading 0
    set t=%t: =0%
    :: Reorder date to DD_MM_YYYY
    set d=%date:~0,2%_%date:~3,2%_%date:~6,4%

    if exist "%source%\" (
        echo Copying folder %source_name% %d% %t% ...
        :: For folders: /E for recursive, /I for directory, /H hidden files, /Y for overwrite
        xcopy "%source%" "%destination%\%source_name% %d% %t%" /E /I /H /Y 1>nul
    ) else if exist "%source%" (
        echo Copying file %source_name% %d% %t% ...
        :: For files: pipe F to indicate it is a file
        echo F | xcopy "%source%" "%destination%\%source_name% %d% %t%" 1>nul
    ) else (
        echo "%source_location%\%source_name%" does not exist
    )

    timeout /t %period% /nobreak 1>nul
goto loop
