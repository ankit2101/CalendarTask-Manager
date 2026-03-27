import React, { useEffect } from 'react';
import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import Dashboard from './pages/Dashboard';
import Todos from './pages/Todos';
import Accounts from './pages/Accounts';
import History from './pages/History';
import Settings from './pages/Settings';
import QuickNote from './pages/QuickNote';
import Layout from './components/Layout';
import { NormalizedEvent } from '../shared/types/calendar';

declare global {
  interface Window {
    api: import('../preload').ElectronAPI;
  }
}

export default function App() {
  // Listen for meeting-ended events to navigate to quick-note route
  useEffect(() => {
    const unsubscribe = window.api?.onMeetingEnded?.((event: NormalizedEvent) => {
      // If we're in the main window, show a notification banner
      console.log('Meeting ended:', event.title);
    });
    return () => unsubscribe?.();
  }, []);

  return (
    <HashRouter>
      <Routes>
        {/* Quick note is a standalone page (rendered in its own window) */}
        <Route path="/quick-note" element={<QuickNote />} />

        {/* Main app with sidebar layout */}
        <Route element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/todos" element={<Todos />} />
          <Route path="/accounts" element={<Accounts />} />
          <Route path="/history" element={<History />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Routes>
    </HashRouter>
  );
}
