import type { Request } from 'express';

export function jsonOk(data: unknown) {
  return {
    success: true,
    data,
  };
}

export function jsonError(message: string) {
  return {
    message,
  };
}

export function parseCallbackParams(req: Request) {
  const payloadSource = req.method === 'GET' ? req.query : req.body;
  const params: Record<string, string> = {};

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
