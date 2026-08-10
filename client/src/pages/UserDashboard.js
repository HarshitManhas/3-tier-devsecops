import React, { useEffect, useState, useContext } from 'react';
import axios from '../axios';
import { AuthContext } from '../context/AuthContext';

function UserDashboard() {
  const [users, setUsers] = useState([]);
  const [editingUser, setEditingUser] = useState(null);
  const [form, setForm] = useState({ name: '', email: '', password: '', role: 'viewer' });
  const [showForm, setShowForm] = useState(false);
  const [message, setMessage] = useState({ text: '', type: '' });
  const [loading, setLoading] = useState(false);
  const { user } = useContext(AuthContext);

  useEffect(() => { fetchUsers(); }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const res = await axios.get('/api/users');
      setUsers(res.data);
    } catch (err) {
      showMessage('Failed to fetch users', 'error');
    } finally {
      setLoading(false);
    }
  };

  const showMessage = (text, type = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage({ text: '', type: '' }), 3000);
  };

  const handleSubmit = async e => {
    e.preventDefault();
    try {
      if (editingUser) {
        await axios.put(`/api/users/${editingUser.id}`, form);
        showMessage('User updated successfully');
      } else {
        await axios.post('/api/users', form);
        showMessage('User created successfully');
      }
      resetForm();
      fetchUsers();
    } catch (err) {
      showMessage(err.response?.data?.error || 'Operation failed', 'error');
    }
  };

  const handleEdit = u => {
    setEditingUser(u);
    setForm({ name: u.name, email: u.email, password: '', role: u.role });
    setShowForm(true);
  };

  const handleDelete = async id => {
    if (!window.confirm('Delete this user?')) return;
    try {
      await axios.delete(`/api/users/${id}`);
      showMessage('User deleted');
      fetchUsers();
    } catch (err) {
      showMessage(err.response?.data?.error || 'Delete failed', 'error');
    }
  };

  const resetForm = () => {
    setEditingUser(null);
    setForm({ name: '', email: '', password: '', role: 'viewer' });
    setShowForm(false);
  };

  const isAdmin = user?.role === 'admin';

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h2>User Management</h2>
          <p className="dashboard-subtitle">{users.length} registered user{users.length !== 1 ? 's' : ''}</p>
        </div>
        {isAdmin && (
          <button className="btn-primary" onClick={() => { resetForm(); setShowForm(true); }} id="btn-add-user">
            + Add User
          </button>
        )}
      </div>

      {message.text && (
        <div className={`alert alert-${message.type}`} role="alert">{message.text}</div>
      )}

      {showForm && isAdmin && (
        <div className="form-card">
          <h3>{editingUser ? 'Edit User' : 'Create New User'}</h3>
          <form onSubmit={handleSubmit} id="user-form">
            <div className="form-row">
              <div className="form-group">
                <label>Full Name</label>
                <input type="text" name="name" value={form.name} onChange={e => setForm({...form, name: e.target.value})} required className="form-input" id="user-name" />
              </div>
              <div className="form-group">
                <label>Email</label>
                <input type="email" name="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} required className="form-input" id="user-email" />
              </div>
            </div>
            <div className="form-row">
              <div className="form-group">
                <label>{editingUser ? 'New Password (leave blank to keep)' : 'Password'}</label>
                <input type="password" name="password" value={form.password} onChange={e => setForm({...form, password: e.target.value})} required={!editingUser} className="form-input" id="user-password" />
              </div>
              <div className="form-group">
                <label>Role</label>
                <select name="role" value={form.role} onChange={e => setForm({...form, role: e.target.value})} className="form-input" id="user-role">
                  <option value="viewer">Viewer</option>
                  <option value="editor">Editor</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
            </div>
            <div className="btn-group">
              <button type="submit" className="btn-primary" id="btn-save-user">{editingUser ? 'Update' : 'Create'}</button>
              <button type="button" className="btn-secondary" onClick={resetForm}>Cancel</button>
            </div>
          </form>
        </div>
      )}

      {loading ? (
        <div className="loading-state">⏳ Loading users...</div>
      ) : (
        <div className="table-wrapper">
          <table className="data-table" id="users-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Created</th>
                {isAdmin && <th>Actions</th>}
              </tr>
            </thead>
            <tbody>
              {users.length === 0 ? (
                <tr><td colSpan={isAdmin ? 6 : 5} className="empty-state">No users found</td></tr>
              ) : (
                users.map((u, idx) => (
                  <tr key={u.id}>
                    <td>{idx + 1}</td>
                    <td>{u.name}</td>
                    <td>{u.email}</td>
                    <td><span className="role-badge" data-role={u.role}>{u.role}</span></td>
                    <td>{new Date(u.created_at).toLocaleDateString()}</td>
                    {isAdmin && (
                      <td>
                        <button className="btn-sm btn-edit" onClick={() => handleEdit(u)} id={`btn-edit-${u.id}`}>Edit</button>
                        <button className="btn-sm btn-danger" onClick={() => handleDelete(u.id)} id={`btn-delete-${u.id}`} disabled={u.id === user.id}>Delete</button>
                      </td>
                    )}
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

export default UserDashboard;
