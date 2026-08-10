import React from 'react';
import { Link } from 'react-router-dom';

function NotFound() {
  return (
    <div className="auth-page">
      <div className="auth-card" style={{textAlign: 'center'}}>
        <div style={{fontSize: '4rem', marginBottom: '1rem'}}>404</div>
        <h2>Page Not Found</h2>
        <p>The page you are looking for doesn't exist.</p>
        <Link to="/dashboard"><button className="btn-primary" style={{marginTop: '1rem'}}>Go to Dashboard</button></Link>
      </div>
    </div>
  );
}

export default NotFound;
