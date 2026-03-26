import React from 'react';
import { Outlet, NavLink } from 'react-router-dom';

const navItems = [
  { to: '/dashboard', label: 'Today', icon: '📅' },
  { to: '/todos', label: 'To-Do', icon: '✅' },
  { to: '/accounts', label: 'Accounts', icon: '👤' },
  { to: '/history', label: 'Notes', icon: '📝' },
  { to: '/settings', label: 'Settings', icon: '⚙️' },
];

export default function Layout() {
  return (
    <div style={styles.container}>
      {/* macOS traffic lights live in the top-left; add padding */}
      <div style={styles.titleBar} />
      <div style={styles.body}>
        <nav style={styles.sidebar}>
          <div style={styles.appName}>📆 CalTask</div>
          {navItems.map(item => (
            <NavLink
              key={item.to}
              to={item.to}
              style={({ isActive }) => ({
                ...styles.navItem,
                ...(isActive ? styles.navItemActive : {}),
              })}
            >
              <span style={styles.navIcon}>{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <main style={styles.main}>
          <Outlet />
        </main>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex',
    flexDirection: 'column',
    height: '100vh',
    background: '#1e1e2e',
    color: '#cdd6f4',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    fontSize: 14,
    userSelect: 'none',
  },
  titleBar: {
    height: 28,
    WebkitAppRegion: 'drag',
    background: '#1e1e2e',
    flexShrink: 0,
  },
  body: {
    display: 'flex',
    flex: 1,
    overflow: 'hidden',
  },
  sidebar: {
    width: 180,
    background: '#181825',
    display: 'flex',
    flexDirection: 'column',
    padding: '12px 0',
    borderRight: '1px solid #313244',
    flexShrink: 0,
  },
  appName: {
    padding: '8px 16px 16px',
    fontWeight: 700,
    fontSize: 15,
    color: '#cba6f7',
    letterSpacing: 0.5,
  },
  navItem: {
    display: 'flex',
    alignItems: 'center',
    gap: 10,
    padding: '9px 16px',
    color: '#a6adc8',
    textDecoration: 'none',
    borderRadius: 6,
    margin: '1px 8px',
    transition: 'background 0.1s',
  },
  navItemActive: {
    background: '#313244',
    color: '#cdd6f4',
  },
  navIcon: {
    fontSize: 16,
  },
  main: {
    flex: 1,
    overflow: 'auto',
    padding: 24,
  },
};
