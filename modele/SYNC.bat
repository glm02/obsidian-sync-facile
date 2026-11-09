@echo off
rem Double-clic : synchronise le coffre Obsidian avec GitHub.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-obsidian.ps1"
