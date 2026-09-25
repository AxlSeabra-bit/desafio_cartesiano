@echo off
chcp 65001 > nul
title Central da Competicao - Host Desafio Cartesiano
color 0B

cd /d "%~dp0"

echo =======================================================
echo     🏆 DESAFIO CARTESIANO - CENTRAL DA COMPETICAO
echo =======================================================
echo.
echo [1/2] Verificando arquivos do servidor e QR Code...

if not exist "host.html" (
    echo [ERRO] "host.html" nao encontrado!
    pause
    exit /b 1
)

if not exist "qrcode.min.js" (
    echo [ERRO] "qrcode.min.js" nao encontrado!
    pause
    exit /b 1
)

echo [OK] Painel da competicao pronto!
echo.
echo [2/2] Iniciando Servidor Host na Rede Local...
echo.
echo =======================================================
echo  * O navegador abrira com o QR CODE para a turma!
echo  * Projete esta tela ou mostre aos alunos.
echo  * Conecte todos os celulares no mesmo Wi-Fi.
echo  * Para encerrar a competicao, feche esta janela.
echo =======================================================
echo.

echo [OK] Executando servidor nativo do Windows (sem precisar instalar nada)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor_host.ps1"

pause
