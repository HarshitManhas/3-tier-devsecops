import React, { useState, useContext } from 'react';
import axios from '../axios';
import { useNavigate, Link } from 'react-router-dom';

function Register() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: '', email: '', password: '', role: 'viewer' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = e => setForm({ ...form, [e.target.name]: e.target.value });

  const handleSubmit = async e => {
    e.preventDefault();
    setError('');
    if (form.password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }
    setLoading(true);
    try {
      await axios.post('/api/auth/register', form);
      navigate('/login');
    } catch (err) {
      setError(err.response?.data?.error || 'Registration failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-header">
          <div className="auth-logo">⚙️</div>
          <h2>Create Account</h2>
          <p>Join DevOps Project</p>
        </div>
        {error && <div className="alert alert-error" role="alert">{error}</div>}
        <form onSubmit={handleSubmit} id="register-form">
          <div className="form-group">
            <label htmlFor="reg-name">Full Name</label>
            <input id="reg-name" type="text" name="name" placeholder="John Doe" value={form.name} onChange={handleChange} required className="form-input" />
          </div>
          <div className="form-group">
            <label htmlFor="reg-email">Email Address</label>
            <input id="reg-email" type="email" name="email" placeholder="you@example.com" value={form.email} onChange={handleChange} required className="form-input" />
          </div>
          <div className="form-group">
            <label htmlFor="reg-password">Password (min 8 chars)</label>
            <input id="reg-password" type="password" name="password" placeholder="••••••••" value={form.password} onChange={handleChange} required className="form-input" />
          </div>
          <div className="form-group">
            <label htmlFor="reg-role">Role</label>
            <select id="reg-role" name="role" value={form.role} onChange={handleChange} className="form-input">
              <option value="viewer">Viewer</option>
              <option value="editor">Editor</option>
            </select>
          </div>
          <button type="submit" className="btn-primary btn-full" id="btn-register" disabled={loading}>
            {loading ? 'Creating...' : 'Create Account'}
          </button>
        </form>
        <p className="auth-footer">Already have an account? <Link to="/login">Sign in</Link></p>
      </div>
    </div>
  );
}

export default Register;
