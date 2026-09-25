@echo off
chcp 65001 > nul
title Desafio Cartesiano - Executando Localmente
color 0A

cd /d "%~dp0"

echo =======================================================
echo             INICIANDO O DESAFIO CARTESIANO
echo =======================================================
echo.

if not exist "index.html" (
    echo [AVISO] Os arquivos do jogo nao foram encontrados nesta pasta!
    echo.
    echo Por favor, execute primeiro o arquivo:
    echo     👉 "1_Verificar_e_Instalar.bat"
    echo.
    pause
    exit /b 1
)

echo [OK] Arquivos verificados com sucesso!
echo [OK] Iniciando servidor web local...
echo.
echo O navegador sera aberto automaticamente com o jogo pronto!
echo.
echo -------------------------------------------------------
echo  * DICA: Deixe esta janela aberta enquanto estiver jogando.
echo  * Para encerrar o jogo, basta fechar esta janela.
echo -------------------------------------------------------
echo.

if exist "servidor_local.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor_local.ps1"
) else (
    start "" "%~dp0index.html"
)

pause
