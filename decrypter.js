const http = require('http');
const sodium = require('libsodium-wrappers');
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const FORWARD_DEST = process.env.FORWARD_DEST || 'http://host.docker.internal:8080';
const SERVICES_MAP = process.env.SERVICES_MAP || ""; 
const LISTEN_PORT = process.env.DECRYPTER_PORT || 8081;
const TUNNEL_ID = process.env.TUNNEL_ID || ""; 

const routes = SERVICES_MAP.split(',').filter(x => x.includes('=')).map(r => {
    const [path, ...targetParts] = r.split('=');
    return { path: path.trim(), target: targetParts.join('=').trim() };
}).sort((a, b) => b.path.length - a.path.length);

function getTarget(requestPath) {
    const match = routes.find(r => requestPath.startsWith(r.path));
    return match ? match.target : FORWARD_DEST;
}

const PRIV_KEY_PATH = '/registration/priv.key';
const PUB_KEY_PATH = '/registration/pub.key';
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

function log(level, message) {
    if (LOG_LEVEL === 'silent') return;
    if (level === 'debug' && LOG_LEVEL !== 'debug') return;
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [LOOHIVE] [${level.toUpperCase()}] ${message}`);
}

async function decrypt(sealedBoxBase64) {
    await sodium.ready;
    try {
        if (!fs.existsSync(PRIV_KEY_PATH) || !fs.existsSync(PUB_KEY_PATH)) return null;
        const publicKey = Buffer.from(fs.readFileSync(PUB_KEY_PATH, 'utf8').trim(), 'base64');
        const pemContent = fs.readFileSync(PRIV_KEY_PATH, 'utf8');
        const der = Buffer.from(pemContent.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, ''), 'base64');
        const privateKey = der.slice(-32);
        const sealedBox = sodium.from_base64(sealedBoxBase64);
        const decrypted = sodium.crypto_box_seal_open(sealedBox, publicKey, privateKey);
        return JSON.parse(sodium.to_string(decrypted));
    } catch (e) { return null; }
}

const server = http.createServer(async (req, res) => {
    // Transparent Proxy for Non-Relay Traffic (GET, Direct Browser Access, etc.)
    if (req.method !== 'POST' || req.url !== '/') {
        log('debug', `Direct access: [${req.method}] ${req.url}`);
        return forwardFull({ method: req.method, path: req.url, headers: req.headers, stream: req }, res);
    }

    let chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', async () => {
        try {
            const body = Buffer.concat(chunks).toString();
            let json;
            try { json = JSON.parse(body); } catch (e) { 
                return forwardFull({ method: req.method, path: req.url, headers: req.headers, body: body }, res); 
            }

            if (!json || !json.payload) {
                return forwardFull({ method: req.method, path: req.url, headers: req.headers, body: body }, res);
            }

            const ctx = await decrypt(json.payload);
            if (!ctx) { res.statusCode = 400; return res.end('Decryption Failed'); }

            if (ctx.method && ctx.requestId) {
                log('info', `Relay: [${ctx.method}] ${ctx.path} (${ctx.requestId})`);
                return forwardFull({ ...ctx, isTunnel: true }, res);
            }
            forwardLegacy(JSON.stringify(ctx.data), { ...req.headers, 'x-decrypted': 'true' }, res);
        } catch (e) { res.statusCode = 500; res.end('Internal Error'); }
    });
});

async function forwardFull(ctx, clientRes) {
    const target = getTarget(ctx.path || '/');
    const targetUrl = new URL(ctx.path || '', target);
    const options = {
        hostname: targetUrl.hostname,
        port: targetUrl.port || (targetUrl.protocol === 'https:' ? 443 : 80),
        path: targetUrl.pathname + targetUrl.search,
        method: ctx.method || 'GET',
        headers: { 
            ...ctx.headers, 
            'host': targetUrl.host, 
            'accept-encoding': 'identity',
            'x-forwarded-host': ctx.headers['host'] || 'onion-pipe.loohive.com',
            'x-forwarded-proto': 'https',
            'x-forwarded-for': ctx.headers['x-forwarded-for'] || '127.0.0.1'
        }
    };
    if (TUNNEL_ID) {
        options.headers['x-forwarded-prefix'] = `/h/${TUNNEL_ID}`;
    }
    ['content-length', 'connection'].forEach(h => delete options.headers[h]);

    const proxyReq = http.request(options, (proxyRes) => {
        // Handle Gzipped content in the decrypter efficiently
        const isHtml = (proxyRes.headers['content-type'] || '').includes('text/html');
        const isGzipped = (proxyRes.headers['content-encoding'] || '').includes('gzip');
        
        // --- SECURITY & PATH REWRITING ---
        if (ctx.isTunnel && TUNNEL_ID) {
            // 1. Rewrite Redirects for Relay Subpath
            // Handles both relative (/path) and absolute (http://host/path) redirects
            if (proxyRes.headers.location) {
                const loc = proxyRes.headers.location;
                if (loc.startsWith('/')) {
                    // Root-relative
                    if (!loc.startsWith(`/h/${TUNNEL_ID}`)) {
                        proxyRes.headers.location = `/h/${TUNNEL_ID}${loc}`;
                    }
                } else if (loc.includes(targetUrl.host)) {
                    // Absolute redirect to the same host
                    try {
                        const locUrl = new URL(loc);
                        proxyRes.headers.location = `/h/${TUNNEL_ID}${locUrl.pathname}${locUrl.search}${locUrl.hash}`;
                    } catch (e) {}
                }
            }

            // 2. Rewrite Cookie Paths (Critical for Auth & Sessions)
            // Enhanced to handle any Path attribute and prefix it, strip Domain, and fix SameSite
            if (proxyRes.headers['set-cookie']) {
                const cookies = proxyRes.headers['set-cookie'];
                proxyRes.headers['set-cookie'] = cookies.map(cookie => {
                    let c = cookie;
                    c = c.replace(/Path\s*=\s*([^;]+)/gi, (match, pathAttr) => {
                        const p = pathAttr.trim();
                        if (p.startsWith(`/h/${TUNNEL_ID}`)) return match;
                        const newPath = `/h/${TUNNEL_ID}${p.startsWith('/') ? '' : '/'}${p}`;
                        return `Path=${newPath}`;
                    });
                    c = c.replace(/Domain\s*=\s*[^;]+;?/gi, '');
                    if (c.toLowerCase().includes('samesite=none') && !c.toLowerCase().includes('secure')) {
                        c += '; Secure';
                    }
                    return c.trim().replace(/;$/, '');
                });
            }
        }

        if (ctx.isTunnel && isHtml && TUNNEL_ID) {
            let body = [];
            proxyRes.on('data', chunk => body.push(chunk));
            proxyRes.on('end', () => {
                let buffer = Buffer.concat(body);
                
                // If the HTML is gzipped, we MUST decompress it to rewrite paths
                if (isGzipped) {
                    try {
                        buffer = zlib.gunzipSync(buffer);
                        delete proxyRes.headers['content-encoding']; // Header is no longer valid for decompressed body
                    } catch (e) {
                        log('error', 'Failed to decompress HTML for rewriting');
                    }
                }

                let html = buffer.toString();
                
                // Remove any existing <base> tags and prefix injections
                html = html.replace(/<base[^>]*>/gi, '');

                const baseTag = `<base href="/h/${TUNNEL_ID}/">`;
                const prefix = `/h/${TUNNEL_ID}`;
                
                // Aggressive Path Rewriting for Subpath support
                const attrs = ['href', 'src', 'action', 'data-href', 'data-src', 'srcset'];
                attrs.forEach(attr => {
                    const regex = new RegExp(`(${attr})\\s*=\\s*(["'])\\/([^\\/][^"'>]*)\\2`, 'g');
                    html = html.replace(regex, (match, a, quote, path) => {
                        if (path.startsWith(`h/${TUNNEL_ID}`)) return match;
                        return `${a}=${quote}${prefix}/${path}${quote}`;
                    });
                });
                
                // Handle the single / case (home link)
                html = html.replace(/(href|src|action)\s*=\s*(["'])\/\2/g, `$1=$2${prefix}/$2`);

                html = html.includes('<head>') ? html.replace('<head>', `<head>${baseTag}`) : baseTag + html;
                delete proxyRes.headers['content-length'];
                clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
                clientRes.end(html);
            });
        } else {
            clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
            proxyRes.pipe(clientRes);
        }
    });

    proxyReq.on('error', (err) => { 
        log('error', `Forwarding failed: ${err.message}`);
        clientRes.statusCode = 502; 
        clientRes.end('Service Unreachable'); 
    });
    
    if (ctx.stream) ctx.stream.pipe(proxyReq);
    else { 
        if (ctx.body) {
            const bodyData = ctx.isBase64 ? Buffer.from(ctx.body, 'base64') : ctx.body;
            if (Buffer.isBuffer(bodyData) || typeof bodyData === 'string') {
                proxyReq.write(bodyData);
            } else {
                proxyReq.write(JSON.stringify(bodyData));
            }
        }
        proxyReq.end(); 
    }
}

function forwardLegacy(data, headers, clientRes) {
    const url = new URL(getTarget('/'));
    const options = { hostname: url.hostname, port: url.port || 80, path: url.pathname, method: 'POST', headers };
    const proxyReq = http.request(options, (proxyRes) => { 
        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers); 
        proxyRes.pipe(clientRes); 
    });
    proxyReq.write(data); proxyReq.end();
}

server.listen(LISTEN_PORT, '0.0.0.0', () => { 
    log('info', `Service active on port ${LISTEN_PORT}`); 
});
