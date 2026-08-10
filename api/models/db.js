'use strict';
require('dotenv').config();
const mysql = require('mysql2');

const pool = mysql.createPool({
  host:     process.env.DB_HOST     || 'localhost',
  user:     process.env.DB_USER     || 'appuser',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME     || 'crud_app',
  port:     parseInt(process.env.DB_PORT || '3306', 10),
  waitForConnections: true,
  connectionLimit:    10,
  queueLimit:         0,
  enableKeepAlive:    true,
  keepAliveInitialDelay: 0,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : undefined,
});

// Test connectivity on startup
pool.getConnection((err, conn) => {
  if (err) {
    console.error('❌ Database connection failed:', err.message);
    process.exit(1);
  }
  console.log('✅ MySQL connected successfully');
  conn.release();
});

module.exports = pool;
