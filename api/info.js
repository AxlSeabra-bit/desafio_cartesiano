export default function handler(req, res) {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");

    if (req.method === "OPTIONS") {
        res.status(200).end();
        return;
    }

    const host = req.headers["x-forwarded-host"] || req.headers.host || "desafio-cartesiano.vercel.app";
    const proto = req.headers["x-forwarded-proto"] || "https";

    res.status(200).json({
        online: true,
        platform: "vercel",
        host_ip: host,
        game_url: `${proto}://${host}/index.html`,
        host_url: `${proto}://${host}/host.html`
    });
}
