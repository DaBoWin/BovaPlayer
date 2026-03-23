export function jsonOk(data) {
    return {
        success: true,
        data,
    };
}
export function jsonError(message) {
    return {
        message,
    };
}
export function parseCallbackParams(req) {
    const payloadSource = req.method === 'GET' ? req.query : req.body;
    const params = {};
    if (!payloadSource || typeof payloadSource !== 'object') {
        return params;
    }
    for (const [key, value] of Object.entries(payloadSource)) {
        if (Array.isArray(value)) {
            params[key] = String(value[0] ?? '');
            continue;
        }
        params[key] = String(value ?? '');
    }
    return params;
}
