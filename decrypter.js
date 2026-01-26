const http = require('http');
const sodium = require('libsodium-wrappers');
const fs = require('fs');
const path = require('path');

const FORWARD_DEST = process.env.FORWARD_DEST || 'http://host.docker.internal:8080';
const LISTEN_PORT = process.env.DECRYPTER_PORT || 8081;
const PRIV_KEY_PATH = '/registration/priv.key';
const PUB_KEY_PATH = '/registration/pub.key';

const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

function log(level, message) {
    if (LOG_LEVEL === 'silent') return;
    if (level === 'debug' && LOG_LEVEL !== 'debug') return;
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`);
}

async function decrypt(sealedBoxBase64) {
    await sodium.ready;
    try {
        if (!fs.existsSync(PRIV_KEY_PATH) || !fs.existsSync(PUB_KEY_PATH)) {
            throw new Error('Keys not found in /registration/');
        }

        const pubKeyBase64 = fs.readFileSync(PUB_KEY_PATH, 'utf8').trim();
        const publicKey = Buffer.from(pubKeyBase64, 'base64');

        // Extract raw X25519 private key from OpenSSL PEM
        const pemContent = fs.readFileSync(PRIV_KEY_PATH, 'utf8');
        const base64Part = pemContent.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
        const der = Buffer.from(base64Part, 'base64');
        const privateKey = der.slice(-32);

        const sealedBox = sodium.from_base64(sealedBoxBase64);
        const decrypted = sodium.crypto_box_seal_open(sealedBox, publicKey, privateKey);
        
        return JSON.parse(sodium.to_string(decrypted));
    } catch (e) {
        console.error('[Decrypter] Decryption failed:', e.message);
        return null;
    }
}

const server = http.createServer(async (req, res) => {
    if (req.method !== 'POST') {
        res.statusCode = 405;
        return res.end('Method Not Allowed');
    }

    let chunks = [];
    let size = 0;
    const MAX_SIZE = 1 * 1024 * 1024; // 1MB Limit

    req.on('data', chunk => { 
        size += chunk.length;
        if (size > MAX_SIZE) {
            log('error', 'Payload too large, dropping connection');
            res.statusCode = 413;
            res.end('Payload Too Large');
            req.destroy();
            return;
        }
        chunks.push(chunk); 
    });

    req.on('end', async () => {
        if (res.writableEnded) return;

        try {
            const body = Buffer.concat(chunks).toString();
            const json = JSON.parse(body);
            if (!json.payload) {
                console.warn('[Decrypter] No payload field found. Skipping decryption.');
                return forward(body, req.headers, res);
            }

            const decrypted = await decrypt(json.payload);
            if (!decrypted) {
                res.statusCode = 400;
                return res.end('Decryption Failed');
            }

            // Forward only the 'data' part of the decrypted envelope
            const payloadToForward = typeof decrypted.data === 'string' 
                ? decrypted.data 
                : JSON.stringify(decrypted.data);
            
            log('debug', `Forwarding payload to ${FORWARD_DEST}`);
            
            forward(payloadToForward, {
                ...req.headers,
                'content-type': typeof decrypted.data === 'object' ? 'application/json' : 'text/plain',
                'content-length': Buffer.byteLength(payloadToForward),
                'x-decrypted': 'true'
            }, res);

        } catch (e) {
            log('error', `Internal Error: ${e.message}`);
            res.statusCode = 500;
            res.end('Internal Decrypter Error');
        }
    });
});

function forward(data, headers, clientRes) {
    const url = new URL(FORWARD_DEST);
    const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname + url.search,
        method: 'POST',
        headers: headers
    };

    const proxyReq = http.request(options, (proxyRes) => {
        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(clientRes);
    });

    proxyReq.on('error', (err) => {
        log('error', `Forwarding failed: ${err.message}`);
        clientRes.statusCode = 502;
        clientRes.end('Bad Gateway');
    });

    proxyReq.write(data);
    proxyReq.end();
}

server.listen(LISTEN_PORT, '0.0.0.0', () => {
    log('info', `Decrypter listening on port ${LISTEN_PORT}`);
});
