@echo off
setlocal
REM =====================================================================
REM  Ambil versi terbaru dari GitHub (hasil kerja tim) ke folder Dashboard ini.
REM  Jalankan SEBELUM mulai mengubah file atau update data.
REM  Perubahan Anda yang belum di-upload tetap aman (disimpan sementara lalu dipasang lagi).
REM =====================================================================
cd /d "%~dp0"
set "GIT="
where git >nul 2>&1 && set "GIT=git"
if not defined GIT (
  for /d %%D in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do (
    if exist "%%D\resources\app\git\cmd\git.exe" set "GIT=%%D\resources\app\git\cmd\git.exe"
  )
)
if not defined GIT (
  echo [GAGAL] Git tidak ditemukan. Install Git for Windows: https://git-scm.com/download/win
  pause & exit /b 1
)
if not exist ".git" (
  echo [GAGAL] Folder ini belum terhubung ke GitHub. Jalankan Upload_GitHub.bat sekali dulu.
  pause & exit /b 1
)
"%GIT%" config user.email >nul 2>&1 || "%GIT%" config user.email "rdsinsightmdo@gmail.com"
"%GIT%" config user.name  >nul 2>&1 || "%GIT%" config user.name  "rdsinsightmdo"

echo Mengecek GitHub ...
"%GIT%" fetch -q origin
if errorlevel 1 (
  echo [GAGAL] Tidak bisa terhubung ke GitHub. Cek koneksi internet / login GitHub.
  pause & exit /b 1
)
set "BEHIND=0"
"%GIT%" rev-list --count HEAD..origin/main > "%TEMP%\kr_behind.txt" 2>nul && set /p BEHIND=<"%TEMP%\kr_behind.txt"
del "%TEMP%\kr_behind.txt" >nul 2>&1
if "%BEHIND%"=="0" (
  echo.
  echo [OK] Folder Dashboard sudah versi terbaru. Tidak ada perubahan baru dari tim.
  pause & exit /b 0
)
echo.
echo Ada %BEHIND% perubahan baru dari tim:
"%GIT%" --no-pager log --format="  - %%an  %%ad  : %%s" --date=format:"%%Y-%%m-%%d %%H:%%M" HEAD..origin/main
echo File yang berubah:
"%GIT%" --no-pager diff --stat HEAD...origin/main
echo.
echo Menggabungkan ke folder Dashboard ...
"%GIT%" pull -q --rebase --autostash origin main
if errorlevel 1 (
  "%GIT%" rebase --abort >nul 2>&1
  echo.
  echo [PERHATIAN] Tidak bisa digabung otomatis ^(Anda dan tim mengubah bagian yang sama^).
  echo             Folder Anda TIDAK diubah. Selesaikan lewat GitHub Desktop,
  echo             atau koordinasikan dengan rekan tim yang terakhir mengubah file tersebut.
  pause & exit /b 1
)
echo.
echo [SELESAI] Folder Dashboard sudah sama dengan versi terbaru tim.
echo           Silakan mulai bekerja / update data, lalu kirim dengan Upload_GitHub.bat.
pause
