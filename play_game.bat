@echo off
title Minh Han - Le Hoi Trai Tim
echo ========================================================
echo   MINH HAN - LE HOI TRAI TIM
echo ========================================================

cd /d "%~dp0"

where godot >nul 2>nul
if %errorlevel% equ 0 (
    godot %*
) else (
    if exist "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" (
        "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" %*
    ) else (
        echo [LOI] Khong tim thay Godot trong PATH hoac WinGet!
        echo Hay cai dat Godot 4 hoac them godot vao bien moi truong PATH.
        pause
    )
)
