'use strict';
const db = require('../models/db');
const bcrypt = require('bcryptjs');
const util = require('util');
const query = util.promisify(db.query).bind(db);

// GET /api/users - admin only
exports.getAllUsers = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
    const users = await query('SELECT id, name, email, role, created_at FROM users ORDER BY created_at DESC');
    res.json(users);
  } catch (err) {
    console.error('getAllUsers error:', err.message);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
};

// POST /api/users - admin only
exports.addUser = async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
  const { name, email, password, role } = req.body;
  if (!name || !email || !password)
    return res.status(400).json({ error: 'name, email and password are required' });

  try {
    const existing = await query('SELECT id FROM users WHERE email = ?', [email]);
    if (existing.length) return res.status(409).json({ error: 'Email already exists' });

    const hash = await bcrypt.hash(password, 12);
    const allowedRoles = ['admin', 'editor', 'viewer'];
    const assignedRole = allowedRoles.includes(role) ? role : 'viewer';
    const result = await query(
      'INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)',
      [name.trim(), email.toLowerCase().trim(), hash, assignedRole]
    );
    res.status(201).json({ message: 'User created', id: result.insertId });
  } catch (err) {
    console.error('addUser error:', err.message);
    res.status(500).json({ error: 'Failed to create user' });
  }
};

// PUT /api/users/:id - admin only
exports.updateUser = async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
  const { id } = req.params;
  const { name, email, password, role } = req.body;

  try {
    const existing = await query('SELECT id FROM users WHERE id = ?', [id]);
    if (!existing.length) return res.status(404).json({ error: 'User not found' });

    let updateQuery = 'UPDATE users SET name = ?, email = ?, role = ?';
    const params = [name, email, role];
    if (password) {
      const hash = await bcrypt.hash(password, 12);
      updateQuery += ', password = ?';
      params.push(hash);
    }
    updateQuery += ' WHERE id = ?';
    params.push(id);
    await query(updateQuery, params);
    res.json({ message: 'User updated successfully' });
  } catch (err) {
    console.error('updateUser error:', err.message);
    res.status(500).json({ error: 'Failed to update user' });
  }
};

// DELETE /api/users/:id - admin only
exports.deleteUser = async (req, res) => {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
  const { id } = req.params;
  if (parseInt(id) === req.user.id) return res.status(400).json({ error: 'Cannot delete yourself' });

  try {
    const result = await query('DELETE FROM users WHERE id = ?', [id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ message: 'User deleted' });
  } catch (err) {
    console.error('deleteUser error:', err.message);
    res.status(500).json({ error: 'Failed to delete user' });
  }
};
