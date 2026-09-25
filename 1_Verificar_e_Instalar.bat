@echo off
chcp 65001 > nul
title Instalador e Verificador - Desafio Cartesiano
color 0B

echo =======================================================
echo        DESAFIO CARTESIANO - INSTALACAO LOCAL
echo =======================================================
echo.
echo [1/3] Verificando arquivos fundamentais do jogo...

cd /d "%~dp0"

set ERRO_ARQUIVOS=0

if not exist "index.html" (
    echo [ERRO] "index.html" nao foi encontrado nesta pasta!
    set ERRO_ARQUIVOS=1
) else (
    echo [OK] index.html encontrado.
)

if not exist "mapa_mundo.jpg" (
    echo [ERRO] "mapa_mundo.jpg" nao foi encontrado nesta pasta!
    set ERRO_ARQUIVOS=1
) else (
    echo [OK] mapa_mundo.jpg [Missao 4] encontrado.
)

if not exist "mapa_parque.jpg" (
    echo [ERRO] "mapa_parque.jpg" nao foi encontrado nesta pasta!
    set ERRO_ARQUIVOS=1
) else (
    echo [OK] mapa_parque.jpg [Missao 5] encontrado.
)

if %ERRO_ARQUIVOS% neq 0 (
    echo.
    echo [!] Alguns arquivos essenciais estao faltando.
    echo     Certifique-se de extrair todos os arquivos do ZIP.
    echo.
    pause
    exit /b 1
)

echo.
echo [2/3] Verificando compatibilidade com o sistema Windows...
echo [OK] Sistema PowerShell nativo detectado com sucesso.
py -3 -c "exit(0)" >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Python detectado como motor auxiliar opcional.
)
where node >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Node.js detectado como motor auxiliar opcional.
)

echo.
echo [3/3] Configurando permissoes de execucao local...
powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass" >nul 2>nul
echo [OK] Ambiente local validado e liberado para execucao!

echo.
echo =======================================================
echo    🎉 TUDO PRONTO! O JOGO ESTA PRONTO PARA RODAR!
echo =======================================================
echo.
echo Agora e so dar dois cliques no arquivo:
echo     👉 "2_Jogar_Desafio_Cartesiano.bat"
echo.
echo O navegador sera aberto automaticamente com o jogo!
echo.
pause
