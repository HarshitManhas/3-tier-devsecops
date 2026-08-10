'use strict';
process.env.JWT_SECRET = 'test-secret-key-at-least-32-chars-long';
process.env.DB_HOST = 'localhost';
process.env.DB_USER = 'test';
process.env.DB_PASSWORD = 'test';
process.env.DB_NAME = 'test';

const request = require('supertest');
const app = require('../app');

describe('Health Endpoints', () => {
  it('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
  });

  it('GET /unknown returns 404', async () => {
    const res = await request(app).get('/unknown-route');
    expect(res.statusCode).toBe(404);
  });
});

describe('Auth - Input Validation', () => {
  it('POST /api/auth/register rejects missing fields', async () => {
    const res = await request(app).post('/api/auth/register').send({ email: 'a@b.com' });
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/auth/register rejects short password', async () => {
    const res = await request(app).post('/api/auth/register').send({ name: 'Test', email: 'a@b.com', password: '123' });
    expect(res.statusCode).toBe(400);
  });

  it('POST /api/auth/login rejects missing fields', async () => {
    const res = await request(app).post('/api/auth/login').send({});
    expect(res.statusCode).toBe(400);
  });
});
