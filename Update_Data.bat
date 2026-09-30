@echo off
REM Konversi ulang Excel -> folder data\ (terenkripsi dengan PIN). Jalankan setiap kali Excel diperbarui.
REM PIN disimpan di ..\PIN_Dashboard.txt (di luar folder Dashboard, JANGAN ikut di-upload).
REM Untuk ganti PIN: hapus file ..\PIN_Dashboard.txt lalu jalankan file ini lagi.
cd /d "%~dp0"
python --version >nul 2>&1 || (echo Python belum terpasang. Install dari https://www.python.org/downloads/ lalu centang "Add Python to PATH". & pause & exit /b 1)
python -c "import pandas, openpyxl, cryptography" >nul 2>&1 || python -m pip install pandas openpyxl python-calamine cryptography
python tools\convert_data.py %1
echo.
echo Selesai. Buka login.html (atau refresh browser lalu masukkan PIN).
pause
