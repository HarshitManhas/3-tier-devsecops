'use strict';
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const userRoutes = require('./routes/userRoutes');
const authRoutes = require('./routes/authRoutes');
const db = require('./models/db');

const app = express();
const PORT = process.env.PORT || 5000;

// ── Security Middlewares ──────────────────────────────────────
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:3000').split(',');
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error('CORS policy violation'));
  },
  credentials: true,
}));

app.use(bodyParser.json({ limit: '10kb' })); // Limit body size
app.disable('x-powered-by');                 // Hide Express fingerprint

// ── Health Check ──────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/ready', (req, res) => {
  db.query('SELECT 1', (err) => {
    if (err) return res.status(503).json({ status: 'not ready', error: err.message });
    res.status(200).json({ status: 'ready' });
  });
});

// ── Routes ────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);

// ── 404 Handler ───────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ error: 'Not Found' }));

// ── Global Error Handler ──────────────────────────────────────
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err.message);
  res.status(500).json({ error: 'Internal Server Error' });
});

// ── Start ─────────────────────────────────────────────────────
if (require.main === module) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ API server running on port ${PORT}`);
    initAdminUser();
  });
}

async function initAdminUser() {
  const bcrypt = require('bcryptjs');
  const adminEmail = process.env.ADMIN_EMAIL || 'admin@example.com';
  const adminPassword = process.env.ADMIN_PASSWORD;

  if (!adminPassword) {
    console.warn('⚠️  ADMIN_PASSWORD not set - skipping admin user creation');
    return;
  }

  db.query('SELECT id FROM users WHERE email = ?', [adminEmail], async (err, results) => {
    if (err) { console.error('❌ DB error checking admin:', err.message); return; }
    if (results.length > 0) { console.log('ℹ️  Admin user already exists'); return; }
    const hash = await bcrypt.hash(adminPassword, 12);
    db.query(
      'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
      ['Admin User', adminEmail, hash, 'admin'],
      (e) => {
        if (e) console.error('❌ Failed to create admin:', e.message);
        else console.log('✅ Admin user created');
      }
    );
  });
}

module.exports = app;
