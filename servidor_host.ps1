# Servidor Host da Competicao em PowerShell Nativo (TcpListener - Sem necessidade de Admin)
param(
    [int]$Port = 8080
)

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = Get-Location }
$rankingFile = Join-Path $baseDir "ranking_sala.json"

function Get-LocalIP {
    try {
        $udp = New-Object System.Net.Sockets.UdpClient
        $udp.Connect("10.255.255.255", 1)
        $ip = $udp.Client.LocalEndPoint.Address.ToString()
        $udp.Close()
        return $ip
    } catch {
        $ipObj = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
            $_.InterfaceAlias -notlike "*Loopback*" -and 
            $_.InterfaceAlias -notlike "*VPN*" -and 
            $_.InterfaceAlias -notlike "*Virtual*" -and 
            $_.IPAddress -notlike "169.254*" 
        } | Select-Object -First 1
        if ($ipObj) { return $ipObj.IPAddress }
        return "127.0.0.1"
    }
}

$localIP = Get-LocalIP

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

$tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
try {
    $tcpListener.Start()
} catch {
    $Port = 8081
    $tcpListener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
    $tcpListener.Start()
}

$urlHost = "http://localhost:$Port/host.html"
$urlJogo = "http://$($localIP):$Port/index.html"

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   [HOST] DESAFIO CARTESIANO - SERVIDOR DA SALA (POWERSHELL)    " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " * Painel do Host (Projetor/Tela): $urlHost" -ForegroundColor Yellow
Write-Host " * Link para os Alunos (Mesmo Wi-Fi): $urlJogo" -ForegroundColor Yellow
Write-Host " * IP Local Detectado: $localIP" -ForegroundColor White
Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Abrindo o Painel do Host com o QR Code automaticamente..." -ForegroundColor Gray
Write-Host " Para encerrar a competicao, feche esta janela." -ForegroundColor Gray
Write-Host "=================================================================" -ForegroundColor Cyan

Start-Process $urlHost

try {
    while ($true) {
        $client = $tcpListener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $writer = New-Object System.IO.StreamWriter($stream)

        $requestLine = $reader.ReadLine()
        if (-not $requestLine) {
            $client.Close()
            continue
        }

        $parts = $requestLine.Split(" ")
        $method = $parts[0]
        $fullUrl = $parts[1]
        $rawUrl = $fullUrl.Split("?")[0]
        $querySala = ""
        if ($fullUrl -match "[\?&]sala=([^&]+)") {
            $querySala = [System.Uri]::UnescapeDataString($matches[1]).ToUpper().Trim()
        }

        $contentLength = 0
        while (($headerLine = $reader.ReadLine()) -and $headerLine.Trim().Length -gt 0) {
            if ($headerLine -match "Content-Length:\s*(\d+)") {
                $contentLength = [int]$matches[1]
            }
        }

        $body = ""
        if ($contentLength -gt 0) {
            $buffer = New-Object char[] $contentLength
            $readBytes = 0
            while ($readBytes -lt $contentLength) {
                $read = $reader.Read($buffer, $readBytes, $contentLength - $readBytes)
                if ($read -le 0) { break }
                $readBytes += $read
            }
            $body = -join $buffer
        }

        if ($method -eq "GET" -and $rawUrl -eq "/api/info") {
            $infoObj = @{
                host_ip = $localIP
                port = $Port
                game_url = $urlJogo
                host_url = $urlHost
            }
            $json = ConvertTo-Json $infoObj
            $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            $writer.WriteLine("HTTP/1.1 200 OK")
            $writer.WriteLine("Content-Type: application/json; charset=utf-8")
            $writer.WriteLine("Access-Control-Allow-Origin: *")
            $writer.WriteLine("Cache-Control: no-cache")
            $writer.WriteLine("Content-Length: $($jsonBytes.Length)")
            $writer.WriteLine("")
            $writer.Flush()
            $stream.Write($jsonBytes, 0, $jsonBytes.Length)
        }
        elseif ($method -eq "GET" -and $rawUrl -eq "/api/ranking") {
            $ranking = @()
            if (Test-Path $rankingFile) {
                try {
                    $jsonRaw = [System.IO.File]::ReadAllText($rankingFile, [System.Text.Encoding]::UTF8)
                    $parsed = ConvertFrom-Json $jsonRaw
                    if ($parsed -is [array]) { $ranking = $parsed }
                    elseif ($parsed) { $ranking = @($parsed) }
                } catch {}
            }
            if ($querySala -and $querySala -ne "RANK" -and $querySala -ne "GLOBAL" -and $querySala -ne "TODOS") {
                $ranking = @($ranking | Where-Object { ($_.sala -as [string]).ToUpper() -eq $querySala })
            }
            $sorted = $ranking | Sort-Object -Property @{Expression="pontuacao"; Descending=$true}, @{Expression="tempo"; Descending=$false}, @{Expression="erros"; Descending=$false}
            $json = ConvertTo-Json -InputObject @($sorted) -Compress
            if (-not $json) { $json = "[]" }
            $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            $writer.WriteLine("HTTP/1.1 200 OK")
            $writer.WriteLine("Content-Type: application/json; charset=utf-8")
            $writer.WriteLine("Access-Control-Allow-Origin: *")
            $writer.WriteLine("Cache-Control: no-cache")
            $writer.WriteLine("Content-Length: $($jsonBytes.Length)")
            $writer.WriteLine("")
            $writer.Flush()
            $stream.Write($jsonBytes, 0, $jsonBytes.Length)
        }
        elseif ($method -eq "POST" -and $rawUrl -eq "/api/ranking") {
            $ranking = @()
            if (Test-Path $rankingFile) {
                try {
                    $jsonRaw = [System.IO.File]::ReadAllText($rankingFile, [System.Text.Encoding]::UTF8)
                    $parsed = ConvertFrom-Json $jsonRaw
                    if ($parsed -is [array]) { $ranking = $parsed }
                    elseif ($parsed) { $ranking = @($parsed) }
                } catch {}
            }
            try {
                $novoDado = ConvertFrom-Json $body
                $nomeGrupo = "Equipe Anonima"
                if ($novoDado.grupo) { $nomeGrupo = [string]$novoDado.grupo }
                $salaReg = "9A"
                if ($novoDado.sala) { $salaReg = [string]$novoDado.sala.ToString().ToUpper().Trim() }
                elseif ($querySala) { $salaReg = $querySala }
                
                $reg = @{
                    grupo = $nomeGrupo
                    pontuacao = [int]($novoDado.pontuacao)
                    tempo = [int]($novoDado.tempo)
                    erros = [int]($novoDado.erros)
                    dicas = [int]($novoDado.dicas)
                    sala = $salaReg
                    hora = (Get-Date).ToString("HH:mm:ss")
                }
                $filtrados = @($ranking | Where-Object { -not (($_.sala -as [string]).ToUpper() -eq $salaReg -and ($_.grupo -as [string]).ToLower() -eq $reg.grupo.ToLower()) })
                $rankingList = [System.Collections.ArrayList]@($filtrados)
                $rankingList.Add($reg) | Out-Null
                $saveJson = ConvertTo-Json -InputObject @($rankingList) -Depth 4
                [System.IO.File]::WriteAllText($rankingFile, $saveJson, [System.Text.Encoding]::UTF8)

                $rankingSala = @($rankingList | Where-Object { ($_.sala -as [string]).ToUpper() -eq $salaReg })
                $sorted = $rankingSala | Sort-Object -Property @{Expression="pontuacao"; Descending=$true}, @{Expression="tempo"; Descending=$false}, @{Expression="erros"; Descending=$false}
                $pos = 1
                for ($i = 0; $i -lt $sorted.Count; $i++) {
                    if ($sorted[$i].grupo -eq $reg.grupo) {
                        $pos = $i + 1
                        break
                    }
                }
                Write-Host "[NOVO RESULTADO - SALA $salaReg] $($reg.grupo) terminou em $($reg.tempo)s -> #$pos lugar!" -ForegroundColor Green

                $respObj = @{ status = "ok"; posicao = $pos; total = $sorted.Count; sala = $salaReg }
                $respJson = ConvertTo-Json $respObj
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)

                $writer.WriteLine("HTTP/1.1 200 OK")
                $writer.WriteLine("Content-Type: application/json; charset=utf-8")
                $writer.WriteLine("Access-Control-Allow-Origin: *")
                $writer.WriteLine("Content-Length: $($respBytes.Length)")
                $writer.WriteLine("")
                $writer.Flush()
                $stream.Write($respBytes, 0, $respBytes.Length)
            } catch {
                $writer.WriteLine("HTTP/1.1 400 Bad Request")
                $writer.WriteLine("Content-Length: 0")
                $writer.WriteLine("")
                $writer.Flush()
            }
        }
        elseif ($method -eq "POST" -and $rawUrl -eq "/api/ranking/limpar") {
            $senhaValida = $false
            $jsonBody = $null
            if ($body) {
                try {
                    $jsonBody = ConvertFrom-Json $body
                    if ($jsonBody.senha -and $jsonBody.senha.ToString().Trim().ToLower() -eq "apagar 123") {
                        $senhaValida = $true
                    }
                } catch {}
            }
            if (-not $senhaValida) {
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Senha incorreta. Apenas o professor pode zerar o placar."}')
                $writer.WriteLine("HTTP/1.1 403 Forbidden")
                $writer.WriteLine("Content-Type: application/json; charset=utf-8")
                $writer.WriteLine("Access-Control-Allow-Origin: *")
                $writer.WriteLine("Content-Length: $($errBytes.Length)")
                $writer.WriteLine("")
                $writer.Flush()
                $stream.Write($errBytes, 0, $errBytes.Length)
            } else {
                $salaLimpar = ""
                if ($jsonBody.sala) { $salaLimpar = [string]$jsonBody.sala.ToString().ToUpper().Trim() }
                elseif ($querySala) { $salaLimpar = $querySala }

                if (-not $salaLimpar -or $salaLimpar -eq "RANK" -or $salaLimpar -eq "GLOBAL") {
                    [System.IO.File]::WriteAllText($rankingFile, "[]", [System.Text.Encoding]::UTF8)
                    Write-Host "[HOST] Todas as salas foram zeradas." -ForegroundColor Green
                } else {
                    $restantes = @()
                    if (Test-Path $rankingFile) {
                        try {
                            $jsonRaw = [System.IO.File]::ReadAllText($rankingFile, [System.Text.Encoding]::UTF8)
                            $parsed = ConvertFrom-Json $jsonRaw
                            if ($parsed -is [array]) {
                                $restantes = @($parsed | Where-Object { ($_.sala -as [string]).ToUpper() -ne $salaLimpar })
                            }
                        } catch {}
                    }
                    $saveJson = ConvertTo-Json -InputObject @($restantes) -Depth 4
                    [System.IO.File]::WriteAllText($rankingFile, $saveJson, [System.Text.Encoding]::UTF8)
                    Write-Host "[HOST] Placar da sala $salaLimpar foi zerado com sucesso." -ForegroundColor Green
                }

                $retSala = if ($salaLimpar) { $salaLimpar } else { "RANK" }
                $respJson = '{"status":"cleared","sala":"' + $retSala + '"}'
                $respBytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)
                $writer.WriteLine("HTTP/1.1 200 OK")
                $writer.WriteLine("Content-Type: application/json; charset=utf-8")
                $writer.WriteLine("Access-Control-Allow-Origin: *")
                $writer.WriteLine("Content-Length: $($respBytes.Length)")
                $writer.WriteLine("")
                $writer.Flush()
                $stream.Write($respBytes, 0, $respBytes.Length)
            }
        }
        else {
            $relPath = $rawUrl.TrimStart('/')
            if (-not $relPath -or $relPath -eq "") { $relPath = "host.html" }
            $decodedPath = [System.Uri]::UnescapeDataString($relPath)
            $filePath = Join-Path $baseDir $decodedPath

            if (Test-Path $filePath -PathType Leaf) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $mime = "application/octet-stream"
                if ($mimeTypes.ContainsKey($ext)) { $mime = $mimeTypes[$ext] }

                $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
                $writer.WriteLine("HTTP/1.1 200 OK")
                $writer.WriteLine("Content-Type: $mime")
                $writer.WriteLine("Access-Control-Allow-Origin: *")
                $writer.WriteLine("Cache-Control: no-cache")
                $writer.WriteLine("Content-Length: $($fileBytes.Length)")
                $writer.WriteLine("")
                $writer.Flush()
                $stream.Write($fileBytes, 0, $fileBytes.Length)
            } else {
                $writer.WriteLine("HTTP/1.1 404 Not Found")
                $writer.WriteLine("Content-Length: 0")
                $writer.WriteLine("")
                $writer.Flush()
            }
        }

        $client.Close()
    }
} finally {
    $tcpListener.Stop()
}
