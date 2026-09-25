@echo off
chcp 65001 > nul
title Liberar Portas 8080 e 8081
color 0C

echo =======================================================
echo          LIBERAR PORTAS 8080 E 8081 NO WINDOWS
echo =======================================================
echo.
echo Verificando e encerrando processos nessas portas...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$conns = Get-NetTCPConnection -LocalPort 8080, 8081 -State Listen -ErrorAction SilentlyContinue; " ^
    "if (-not $conns) { $conns = Get-NetTCPConnection -LocalPort 8080, 8081 -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -gt 4 }; } " ^
    "if ($conns) { " ^
    "    $conns | Where-Object { $_.OwningProcess -gt 4 } | ForEach-Object { " ^
    "        $p = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue; " ^
    "        if ($p) { " ^
    "            Write-Host ('[ENCERRANDO] Porta ' + $_.LocalPort + ' usada por ' + $p.ProcessName + ' (PID: ' + $_.OwningProcess + ')') -ForegroundColor Yellow; " ^
    "            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue; " ^
    "        } " ^
    "    }; " ^
    "    Write-Host 'Portas 8080 e 8081 liberadas com sucesso!' -ForegroundColor Green; " ^
    "} else { " ^
    "    Write-Host 'Nenhum processo estava usando as portas 8080 e 8081. Elas ja estao livres!' -ForegroundColor Green; " ^
    "}"

echo.
echo =======================================================
echo Concluido!
echo =======================================================
pause
