// Armazenamento em memória para requisições no mesmo container serverless
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

    if (req.method === "GET") {
        const sorted = cacheRanking.sort((a, b) => {
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
        if (req.url && req.url.includes("/limpar")) {
            cacheRanking = [];
            res.status(200).json({ status: "cleared" });
            return;
        }

        const novoRegistro = {
            grupo: String(dados.grupo || "Equipe Anônima").trim() || "Equipe Anônima",
            pontuacao: Number(dados.pontuacao || 0),
            tempo: Number(dados.tempo || 0),
            erros: Number(dados.erros || 0),
            dicas: Number(dados.dicas || 0),
            hora: new Date().toLocaleTimeString("pt-BR").slice(0, 5)
        };

        cacheRanking.push(novoRegistro);
        const sorted = cacheRanking.sort((a, b) => {
            if (b.pontuacao !== a.pontuacao) return b.pontuacao - a.pontuacao;
            if (a.tempo !== b.tempo) return a.tempo - b.tempo;
            return a.erros - b.erros;
        });

        const posicao = sorted.indexOf(novoRegistro) + 1;
        res.status(200).json({ status: "ok", posicao, total: cacheRanking.length });
        return;
    }

    res.status(405).json({ error: "Método não permitido" });
}
