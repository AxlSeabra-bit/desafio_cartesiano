// Armazenamento em memória com suporte a múltiplas salas e Ranking Global (RANK)
let cacheRanking = [];

export default function handler(req, res) {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");

    if (req.method === "OPTIONS") {
        res.status(200).end();
        return;
    }

    // Parâmetro de sala na URL (?sala=9A, ?sala=AXL, ?sala=RANK)
    let salaFiltro = "";
    if (req.query && req.query.sala) {
        salaFiltro = String(req.query.sala).toUpperCase().trim();
    } else if (req.url && req.url.includes("?")) {
        try {
            const urlObj = new URL(req.url, "http://localhost");
            salaFiltro = String(urlObj.searchParams.get("sala") || "").toUpperCase().trim();
        } catch {}
    }

    if (req.method === "GET") {
        let lista = cacheRanking;

        // Se a sala for específica (diferente de RANK ou vazio), filtra apenas os dados daquela sala
        if (salaFiltro && salaFiltro !== "RANK" && salaFiltro !== "GLOBAL" && salaFiltro !== "TODOS") {
            lista = cacheRanking.filter(r => (r.sala || "9A").toUpperCase() === salaFiltro);
        }

        const sorted = lista.slice().sort((a, b) => {
            if ((b.pontuacao || 0) !== (a.pontuacao || 0)) {
                return (b.pontuacao || 0) - (a.pontuacao || 0);
            }
            if ((a.tempo || 99999) !== (b.tempo || 99999)) {
                return (a.tempo || 99999) - (b.tempo || 99999);
            }
            return (a.erros || 0) - (b.erros || 0);
        });

        res.status(200).json(sorted);
        return;
    }

    if (req.method === "POST") {
        const dados = req.body || {};

        // Rota para zerar placar (exige senha 'apagar 123' e apaga apenas a sala indicada, ou todas se RANK)
        if ((req.url && req.url.includes("/limpar")) || dados.action === "limpar" || dados.limpar) {
            const senha = String(dados.senha || "").trim().toLowerCase();
            if (senha !== "apagar 123") {
                res.status(403).json({ error: "Senha incorreta. Não autorizado a zerar o placar." });
                return;
            }

            const salaParaLimpar = String(dados.sala || salaFiltro || "").toUpperCase().trim();
            if (!salaParaLimpar || salaParaLimpar === "RANK" || salaParaLimpar === "GLOBAL") {
                cacheRanking = [];
            } else {
                cacheRanking = cacheRanking.filter(r => (r.sala || "9A").toUpperCase() !== salaParaLimpar);
            }

            res.status(200).json({ status: "cleared", sala: salaParaLimpar || "RANK" });
            return;
        }

        const salaRegistro = String(dados.sala || salaFiltro || "9A").toUpperCase().trim() || "9A";

        const novoRegistro = {
            grupo: String(dados.grupo || "Equipe Anônima").trim() || "Equipe Anônima",
            pontuacao: Number(dados.pontuacao || 0),
            tempo: Number(dados.tempo || 0),
            erros: Number(dados.erros || 0),
            dicas: Number(dados.dicas || 0),
            sala: salaRegistro,
            hora: new Date().toLocaleTimeString("pt-BR").slice(0, 5)
        };

        // Remove registro anterior da mesma equipe na mesma sala para manter o melhor
        cacheRanking = cacheRanking.filter(r => !(
            (r.sala || "9A").toUpperCase() === salaRegistro &&
            (r.grupo || "").trim().toLowerCase() === novoRegistro.grupo.toLowerCase()
        ));

        cacheRanking.push(novoRegistro);

        // Calcula a colocação dentro da sala
        const rankingDaSala = cacheRanking
            .filter(r => (r.sala || "9A").toUpperCase() === salaRegistro)
            .sort((a, b) => {
                if (b.pontuacao !== a.pontuacao) return b.pontuacao - a.pontuacao;
                if (a.tempo !== b.tempo) return a.tempo - b.tempo;
                return a.erros - b.erros;
            });

        const posicao = rankingDaSala.findIndex(r => r.grupo.toLowerCase() === novoRegistro.grupo.toLowerCase()) + 1;
        res.status(200).json({ status: "ok", posicao, total: rankingDaSala.length, sala: salaRegistro });
        return;
    }

    res.status(405).json({ error: "Método não permitido" });
}
