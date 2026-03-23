import express from 'express';
import cors from 'cors';

import { config } from './lib/config.js';
import { createPaymentOrder } from './routes/createPaymentOrder.js';
import { getPaymentStatus } from './routes/getPaymentStatus.js';
import { handleYipayNotify } from './routes/handleYipayNotify.js';
import { handleYipayReturn } from './routes/handleYipayReturn.js';

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/health', (_req, res) => {
  res.json({ success: true });
});

app.options('/api/payment/create', (_req, res) => res.sendStatus(204));
app.options('/api/payment/status/:orderId', (_req, res) => res.sendStatus(204));
app.options('/api/payment/notify/yipay', (_req, res) => res.sendStatus(204));
app.options('/api/payment/return/yipay', (_req, res) => res.sendStatus(204));

app.post('/api/payment/create', createPaymentOrder);
app.get('/api/payment/status/:orderId', getPaymentStatus);
app.get('/api/payment/notify/yipay', handleYipayNotify);
app.post('/api/payment/notify/yipay', handleYipayNotify);
app.get('/api/payment/return/yipay', handleYipayReturn);
app.post('/api/payment/return/yipay', handleYipayReturn);

app.listen(config.port, () => {
  console.log(`[payment-api] listening on :${config.port}`);
});
