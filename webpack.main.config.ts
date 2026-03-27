import type { Configuration } from 'webpack';
import webpack from 'webpack';

import { rules } from './webpack.rules';
import { plugins } from './webpack.plugins';

export const mainConfig: Configuration = {
  /**
   * This is the main entry point for your application, it's the first file
   * that runs in the main process.
   */
  entry: './src/index.ts',
  // Put your normal webpack config below here
  module: {
    rules,
  },
  plugins: [
    ...plugins,
    // Make __APP_ROOT__ available at runtime so externals can be resolved
    // from the correct path inside a packaged asar.
    new webpack.DefinePlugin({
      __APP_ROOT__: 'require("path").resolve(require("electron").app.isPackaged ? require("electron").app.getAppPath() : __dirname, "..")',
    }),
  ],
  resolve: {
    extensions: ['.js', '.ts', '.jsx', '.tsx', '.css', '.json'],
  },
  externals: {
    // keytar has native .node binaries — must stay external and be unpacked from asar
    'keytar': 'commonjs keytar',
    // node-ical depends on temporal-polyfill which uses BigInt extensively;
    // webpack + terser break the global BigInt reference when bundling it.
    // Keep it external and load via require-from-root helper.
    'node-ical': 'commonjs node-ical',
  },
};
