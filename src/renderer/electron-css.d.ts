// Extend React's CSSProperties with Electron-specific drag region property
import 'react';

declare module 'react' {
  interface CSSProperties {
    WebkitAppRegion?: 'drag' | 'no-drag';
  }
}
