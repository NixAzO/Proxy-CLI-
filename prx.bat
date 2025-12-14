@echo off
setlocal enabledelayedexpansion

:: Proxy Generator CLI v2 - Windows

set "QUALITY=medium"
set "SUFFIX=_Proxy"
set "OUTPUT_DIR="
set "CODEC=auto"
set "INFO_MODE=0"

if "%~1"=="" goto :usage
if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage

:parse_args
if "%~1"=="" goto :main
if "%~1"=="-o" (set "OUTPUT_DIR=%~2" & shift & shift & goto :parse_args)
if "%~1"=="-q" (set "QUALITY=%~2" & shift & shift & goto :parse_args)
if "%~1"=="-s" (set "SUFFIX=%~2" & shift & shift & goto :parse_args)
if "%~1"=="-c" (set "CODEC=%~2" & shift & shift & goto :parse_args)
if "%~1"=="-i" (set "INFO_MODE=1" & shift & goto :parse_args)
set "INPUT=%~1"
shift
goto :parse_args

:main
if "%INFO_MODE%"=="1" goto :show_info

:: Detect encoder
if "%CODEC%"=="auto" call :detect_gpu
if "%CODEC%"=="cpu" set "ENCODER=libx264"
if "%CODEC%"=="nvenc" set "ENCODER=h264_nvenc"
if "%CODEC%"=="amf" set "ENCODER=h264_amf"
if "%CODEC%"=="qsv" set "ENCODER=h264_qsv"
if "%CODEC%"=="prores" set "ENCODER=prores_ks"

:: Quality settings
if "%QUALITY%"=="low" (set "SCALE=scale=-2:360" & set "CRF=28" & set "PRORES_PROFILE=0")
if "%QUALITY%"=="medium" (set "SCALE=scale=-2:720" & set "CRF=23" & set "PRORES_PROFILE=1")
if "%QUALITY%"=="high" (set "SCALE=scale=-2:1080" & set "CRF=18" & set "PRORES_PROFILE=2")

:: Encoder options
if "%ENCODER%"=="libx264" set "ENC_OPTS=-preset fast -crf %CRF%"
if "%ENCODER%"=="h264_nvenc" set "ENC_OPTS=-preset p4 -cq %CRF%"
if "%ENCODER%"=="h264_amf" set "ENC_OPTS=-quality balanced -qp_i %CRF% -qp_p %CRF%"
if "%ENCODER%"=="h264_qsv" set "ENC_OPTS=-preset medium -global_quality %CRF%"
if "%ENCODER%"=="prores_ks" (set "ENC_OPTS=-profile:v %PRORES_PROFILE% -vendor apl0" & set "SCALE=scale=-2:720")

if "%OUTPUT_DIR%"=="" set "OUTPUT_DIR=proxies"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

set "EXT=mp4"
if "%ENCODER%"=="prores_ks" set "EXT=mov"

echo Encoder: %ENCODER% ^| Quality: %QUALITY%
echo.

:: Check if input is directory or file
if exist "%INPUT%\*" (
    for %%f in ("%INPUT%\*.mp4" "%INPUT%\*.mov" "%INPUT%\*.avi" "%INPUT%\*.mkv" "%INPUT%\*.mxf" "%INPUT%\*.webm") do (
        call :encode_file "%%f"
    )
) else (
    call :encode_file "%INPUT%"
)

echo.
echo Done! Files saved to %OUTPUT_DIR%
goto :eof

:encode_file
set "FILE=%~1"
set "NAME=%~n1"
set "OUT=%OUTPUT_DIR%\%NAME%%SUFFIX%.%EXT%"
echo Processing: %~nx1
if "%ENCODER%"=="prores_ks" (
    ffmpeg -i "%FILE%" -vf "%SCALE%" -c:v %ENCODER% %ENC_OPTS% -c:a pcm_s16le -y "%OUT%" -loglevel error -stats
) else (
    ffmpeg -i "%FILE%" -vf "%SCALE%" -c:v %ENCODER% %ENC_OPTS% -c:a aac -b:a 128k -y "%OUT%" -loglevel error -stats
)
goto :eof

:detect_gpu
ffmpeg -f lavfi -i nullsrc=s=256x256:d=1 -c:v h264_nvenc -f null - 2>nul && (set "ENCODER=h264_nvenc" & goto :eof)
ffmpeg -f lavfi -i nullsrc=s=256x256:d=1 -c:v h264_amf -f null - 2>nul && (set "ENCODER=h264_amf" & goto :eof)
ffmpeg -f lavfi -i nullsrc=s=256x256:d=1 -c:v h264_qsv -f null - 2>nul && (set "ENCODER=h264_qsv" & goto :eof)
set "ENCODER=libx264"
goto :eof

:show_info
for /f "tokens=*" %%a in ('ffprobe -v error -select_streams v:0 -show_entries stream^=codec_name^,width^,height^,r_frame_rate^,pix_fmt^,profile -of default^=noprint_wrappers^=1 "%INPUT%" 2^>nul') do (
    echo %%a
)
for /f "tokens=*" %%a in ('ffprobe -v error -show_entries format^=duration^,size^,bit_rate -of default^=noprint_wrappers^=1 "%INPUT%" 2^>nul') do (
    echo %%a
)
echo.
echo Compatibility:
echo   DaVinci Resolve - Yes
echo   Premiere Pro    - Yes
echo   Final Cut Pro   - Yes
echo   After Effects   - Yes
goto :eof

:usage
echo Usage: prx [options] ^<file or folder^>
echo.
echo Options:
echo   -o    Output directory (default: proxies)
echo   -q    Quality: low ^| medium ^| high (default: medium)
echo   -s    Suffix (default: _Proxy)
echo   -c    Codec: auto ^| cpu ^| nvenc ^| amf ^| qsv ^| prores
echo   -i    Show video info
echo.
echo Examples:
echo   prx video.mp4
echo   prx -q low -c nvenc .\footage
echo   prx -i video_Proxy.mp4
goto :eof
