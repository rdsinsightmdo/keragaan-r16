@echo off
setlocal
REM =====================================================================
REM  Upload dashboard ke GitHub Pages (sekali klik)
REM  - Klik pertama: otomatis menghubungkan folder ini ke repository GitHub
REM  - (opsional) konversi ulang data dari Excel
REM  - cek keamanan PIN (tolak jika masih PIN sementara)
REM  - commit + push ke GitHub
REM =====================================================================
cd /d "%~dp0"
set "DEFAULT_REPO=https://github.com/rdsinsightmdo/keragaan-r16.git"

REM --- cari git: dari PATH (Git for Windows) atau bawaan GitHub Desktop ---
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
python --version >nul 2>&1 || (echo [GAGAL] Python belum terpasang. & pause & exit /b 1)

REM --- klik pertama: hubungkan folder Dashboard ke repository GitHub ---
if exist ".git" goto repo_ok
echo Folder ini belum terhubung ke GitHub. Menghubungkan sekarang...
echo Repository tujuan (Enter = %DEFAULT_REPO%)
set "REPO="
set /p "REPO=Alamat repository: "
if not defined REPO set "REPO=%DEFAULT_REPO%"
"%GIT%" init -q -b main || (echo [GAGAL] git init gagal. & pause & exit /b 1)
"%GIT%" remote add origin "%REPO%"
echo Mengambil isi repository dari GitHub ...
"%GIT%" fetch -q origin
if errorlevel 1 (
  echo [GAGAL] Tidak bisa mengakses %REPO%
  echo         Cek koneksi internet / alamat repository / login GitHub.
  rmdir /s /q .git
  pause & exit /b 1
)
"%GIT%" rev-parse -q --verify origin/main >nul 2>&1 && "%GIT%" reset -q --soft origin/main
echo [OK] Folder Dashboard terhubung ke %REPO%
:repo_ok

REM --- identitas commit (pakai akun GitHub Desktop jika sudah diatur) ---
"%GIT%" config user.email >nul 2>&1 || "%GIT%" config user.email "rdsinsightmdo@gmail.com"
"%GIT%" config user.name  >nul 2>&1 || "%GIT%" config user.name  "rdsinsightmdo"

REM --- ambil dulu perubahan terbaru dari tim di GitHub ---
echo.
echo Mengambil perubahan terbaru dari tim di GitHub ...
"%GIT%" pull -q --rebase --autostash origin main
if errorlevel 1 (
  "%GIT%" rebase --abort >nul 2>&1
  echo.
  echo [PERHATIAN] Perubahan tim tidak bisa digabung otomatis ^(bentrok di file yang sama^).
  echo             Tidak ada yang diubah. Buka GitHub Desktop untuk menyelesaikannya,
  echo             atau hubungi rekan tim yang terakhir mengubah file tersebut.
  pause & exit /b 1
)
echo [OK] Folder Dashboard sudah sama dengan versi terbaru tim.

echo.
choice /c YT /n /m "Konversi ulang data dari Excel terbaru dulu? [Y=Ya / T=Tidak] "
if errorlevel 2 goto skipconv
python tools\convert_data.py || (echo [GAGAL] Konversi data gagal. Coba jalankan Update_Data.bat. & pause & exit /b 1)
:skipconv

echo.
echo Memeriksa keamanan PIN ...
python tools\cek_pin.py || (echo. & echo Upload DIBATALKAN demi keamanan data. & pause & exit /b 1)

echo.
for /f "delims=" %%t in ('python -c "import datetime;print(datetime.datetime.now().strftime('%%Y-%%m-%%d %%H.%%M'))"') do set "TS=%%t"
"%GIT%" add -A
"%GIT%" diff --cached --quiet
if errorlevel 1 goto do_commit
echo Tidak ada perubahan file baru.
goto do_push
:do_commit
"%GIT%" commit -q -m "Update data %TS%" || (echo [GAGAL] Commit gagal. & pause & exit /b 1)
echo [OK] Perubahan disimpan (commit "Update data %TS%").

:do_push
REM --- cek apakah GitHub berisi perubahan yang TIDAK berasal dari komputer ini ---
"%GIT%" fetch -q origin >nul 2>&1
set "BEHIND=0"
"%GIT%" rev-list --count HEAD..origin/main > "%TEMP%\kr_behind.txt" 2>nul && set /p BEHIND=<"%TEMP%\kr_behind.txt"
del "%TEMP%\kr_behind.txt" >nul 2>&1
if "%BEHIND%"=="0" goto count_ahead
echo.
echo ====================================================================
echo  PERINGATAN: di GitHub ada %BEHIND% perubahan yang TIDAK dibuat dari komputer ini:
echo ====================================================================
"%GIT%" --no-pager log --format="  - %%an (%%ae)  %%ad  : %%s" --date=format:"%%Y-%%m-%%d %%H:%%M" HEAD..origin/main
echo  File yang diubah/ditambah di GitHub:
"%GIT%" --no-pager diff --stat HEAD...origin/main
echo.
echo  G = gabungkan dengan perubahan tim (disarankan untuk kerja tim)
echo  T = TIMPA: perubahan di atas akan DIHAPUS dari GitHub (pakai hanya jika perubahan itu tidak dikenal)
echo.
choice /c GTB /n /m "[G]abungkan / [T]impa / [B]atal : "
if errorlevel 3 (echo Dibatalkan. & pause & exit /b 1)
if errorlevel 2 goto overwrite_remote
goto merge_remote
:overwrite_remote
echo Menimpa GitHub dengan isi folder Dashboard di komputer ini ...
"%GIT%" push --force-with-lease origin main
if errorlevel 1 goto push_fail
goto push_ok
:merge_remote
"%GIT%" pull -q --rebase --autostash origin main
if errorlevel 1 (
  "%GIT%" rebase --abort >nul 2>&1
  echo [GAGAL] Tidak bisa digabung otomatis. Jalankan lagi dan pilih T.
  pause & exit /b 1
)

:count_ahead
set "AHEAD=1"
"%GIT%" rev-list --count origin/main..HEAD > "%TEMP%\kr_ahead.txt" 2>nul && set /p AHEAD=<"%TEMP%\kr_ahead.txt"
del "%TEMP%\kr_ahead.txt" >nul 2>&1
if "%AHEAD%"=="0" (
  echo.
  echo [OK] GitHub sudah berisi versi terbaru. Tidak ada yang perlu dikirim.
  pause & exit /b 0
)
echo Mengirim %AHEAD% commit ke GitHub (jika diminta login, login dengan akun GitHub Anda) ...
"%GIT%" push -u origin main
if errorlevel 1 goto push_fail
:push_ok
echo.
echo [SELESAI] Data terkirim ke GitHub. Website diperbarui dalam 1-2 menit
echo           ^(tekan Ctrl+F5 di browser jika tampilan belum berubah^).
pause
exit /b 0
:push_fail
echo.
echo [GAGAL] Push ke GitHub gagal. Pesan error ada di atas.
echo         Commit sudah tersimpan dan akan dikirim otomatis saat file ini dijalankan lagi.
pause
exit /b 1
