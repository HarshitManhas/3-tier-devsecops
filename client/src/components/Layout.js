import React, { useContext, useState } from 'react';
import { AuthContext } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

function Layout({ children }) {
  const { user, logout } = useContext(AuthContext);
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  return (
    <div className="app-layout">
      <header className="app-header">
        <div className="brand">
          <div className="brand-icon">⚙️</div>
          <div>
            <h1 className="brand-title">DevOps Project</h1>
            <p className="nav-subtitle">User Management Platform</p>
          </div>
        </div>
        <div className="header-right">
          <span className="user-badge">
            <span className="user-role-chip" data-role={user?.role}>{user?.role?.toUpperCase()}</span>
            {user?.name}
          </span>
          <button className="btn-logout" onClick={handleLogout} id="btn-logout">Logout</button>
        </div>
      </header>

      <div className="marquee-banner">
        <span>🚀 Welcome to DevOps Project &nbsp;&nbsp;|&nbsp;&nbsp; Powered by AWS EKS &nbsp;&nbsp;|&nbsp;&nbsp; Secured with DevSecOps &nbsp;&nbsp;|&nbsp;&nbsp; CI/CD with Jenkins + Argo CD &nbsp;&nbsp;|&nbsp;&nbsp; 🔐 Zero Trust Security</span>
      </div>

      <main className="app-body">
        <aside className="sidebar">
          <div className="sidebar-section">
            <h3>Navigation</h3>
            <nav>
              <a href="/dashboard" className="sidebar-link active">📊 Dashboard</a>
            </nav>
          </div>
          <div className="sidebar-section">
            <h3>Stack</h3>
            <ul className="tech-list">
              <li>⚛️ React 19</li>
              <li>🟢 Node.js 20</li>
              <li>🐬 MySQL 8.0</li>
              <li>☸️ Kubernetes</li>
              <li>🐳 Docker</li>
              <li>🔧 Jenkins CI</li>
              <li>🔄 Argo CD</li>
              <li>☁️ AWS EKS</li>
            </ul>
          </div>
          <div className="sidebar-section">
            <h3>Security</h3>
            <ul className="tech-list">
              <li>🔍 SonarQube</li>
              <li>🛡️ Trivy</li>
              <li>🔑 Gitleaks</li>
              <li>🔒 AWS Secrets</li>
            </ul>
          </div>
        </aside>
        <div className="main-content">
          {children}
        </div>
      </main>
    </div>
  );
}

export default Layout;
