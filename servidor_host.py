import os
import sys
import json
import socket
import datetime
import webbrowser
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

# Garante suporte a UTF-8 no console do Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

PORT = 8080
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RANKING_FILE = os.path.join(BASE_DIR, "ranking_sala.json")

def detectar_ip_local():
    """Detecta automaticamente o IP local da máquina na rede Wi-Fi / LAN."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Conecta a um IP de teste sem enviar pacotes reais
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        try:
            ip = socket.gethostbyname(socket.gethostname())
        except Exception:
            ip = '127.0.0.1'
    finally:
        s.close()
    return ip

class HostCompeticaoHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=BASE_DIR, **kwargs)

    def end_headers(self):
        # Desabilita cache para garantir tempo real no ranking
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        path = self.path.split("?")[0]

        # Rota para informações de rede do Host
        if path == "/api/info":
            ip = detectar_ip_local()
            data = {
                "host_ip": ip,
                "port": PORT,
                "game_url": f"http://{ip}:{PORT}/index.html",
                "host_url": f"http://{ip}:{PORT}/host.html"
            }
            self.enviar_json(data)
            return

        # Rota para buscar o ranking ao vivo
        if path == "/api/ranking":
            ranking = self.carregar_ranking()
            self.enviar_json(ranking)
            return

        # Redireciona a raiz para o Painel do Host se acessado pelo localhost
        if path == "/" or path == "":
            self.path = "/host.html"

        return super().do_GET()

    def do_POST(self):
        path = self.path.split("?")[0]

        # Rota para receber nova pontuação de aluno/equipe
        if path == "/api/ranking":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            try:
                dados = json.loads(body.decode("utf-8"))
            except Exception as e:
                self.send_error(400, f"JSON invalido: {e}")
                return

            ranking = self.carregar_ranking()

            novo_registro = {
                "grupo": str(dados.get("grupo", "Equipe Anônima")).strip() or "Equipe Anônima",
                "pontuacao": int(dados.get("pontuacao", 0)),
                "tempo": int(dados.get("tempo", 0)),
                "erros": int(dados.get("erros", 0)),
                "dicas": int(dados.get("dicas", 0)),
                "hora": datetime.datetime.now().strftime("%H:%M:%S")
            }

            ranking.append(novo_registro)
            self.salvar_ranking(ranking)

            # Ordena: Maior pontuação, Menor tempo, Menor erro
            ranking_ordenado = sorted(
                ranking,
                key=lambda x: (-x.get("pontuacao", 0), x.get("tempo", 999999), x.get("erros", 999999))
            )
            posicao = ranking_ordenado.index(novo_registro) + 1

            print(f"⚡ [NOVO RESULTADO] {novo_registro['grupo']} terminou em {novo_registro['tempo']}s ({novo_registro['pontuacao']} pts) -> #{posicao} lugar!")

            self.enviar_json({"status": "ok", "posicao": posicao, "total": len(ranking)})
            return

        # Rota para limpar ranking (nova rodada)
        if path == "/api/ranking/limpar":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length) if content_length > 0 else b"{}"
            try:
                dados = json.loads(body.decode("utf-8")) if body else {}
            except Exception:
                dados = {}

            senha = str(dados.get("senha", "")).strip().lower()
            if senha != "apagar 123":
                self.send_error(403, "Senha incorreta. Apenas o professor pode zerar o placar.")
                return

            self.salvar_ranking([])
            print("🔒 [HOST] O placar foi zerado com sucesso apos autenticacao com senha do professor.")
            self.enviar_json({"status": "cleared"})
            return

        self.send_error(404, "Rota nao encontrada")

    def carregar_ranking(self):
        if not os.path.exists(RANKING_FILE):
            return []
        try:
            with open(RANKING_FILE, "r", encoding="utf-8") as f:
                dados = json.load(f)
                return sorted(
                    dados,
                    key=lambda x: (-x.get("pontuacao", 0), x.get("tempo", 999999), x.get("erros", 999999))
                )
        except Exception:
            return []

    def salvar_ranking(self, dados):
        try:
            with open(RANKING_FILE, "w", encoding="utf-8") as f:
                json.dump(dados, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Erro ao salvar ranking: {e}")

    def enviar_json(self, obj):
        payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

def iniciar_servidor():
    ip = detectar_ip_local()
    global PORT

    server = None
    for tentativa in range(5):
        try:
            server = ThreadingHTTPServer(("0.0.0.0", PORT), HostCompeticaoHandler)
            break
        except OSError:
            PORT += 1

    if not server:
        print("Erro: Nao foi possivel abrir uma porta para o servidor.")
        sys.exit(1)

    url_host = f"http://localhost:{PORT}/host.html"
    url_jogo = f"http://{ip}:{PORT}/index.html"

    print("=" * 65)
    print("      [HOST] DESAFIO CARTESIANO - SERVIDOR DA SALA ATIVO      ")
    print("=" * 65)
    print(f" * Painel do Host (Projetor/Tela): {url_host}")
    print(f" * Link para Celulares dos Alunos (Mesmo Wi-Fi): {url_jogo}")
    print(f" * IP da Maquina na Rede Local: {ip}")
    print("-" * 65)
    print(" Abrindo o Painel do Host com o QR Code no navegador...")
    print(" Para encerrar a competicao, feche esta janela.")
    print("=" * 65)

    webbrowser.open(url_host)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor encerrado.")
        server.server_close()

if __name__ == "__main__":
    iniciar_servidor()
