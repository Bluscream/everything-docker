@echo off
setlocal enabledelayedexpansion

docker-compose down

rmdir /s /q cache
rmdir /s /q config

docker-compose build --no-cache
if %errorlevel% neq 0 exit /b %errorlevel%

docker-compose up 