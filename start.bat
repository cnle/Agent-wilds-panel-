@echo off
chcp 65001 >nul
cd /d "%~dp0"
python aw_panel.py
pause
