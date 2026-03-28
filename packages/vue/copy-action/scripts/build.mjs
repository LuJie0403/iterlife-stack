import { cpSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const currentDir = dirname(fileURLToPath(import.meta.url));
const packageDir = resolve(currentDir, '..');
const distDir = resolve(packageDir, 'dist');
const srcStyleFile = resolve(packageDir, 'src', 'style.css');
const distStyleFile = resolve(distDir, 'style.css');

rmSync(distDir, { force: true, recursive: true });

const tscCommand = process.platform === 'win32' ? 'pnpm.cmd' : 'pnpm';
const tscResult = spawnSync(tscCommand, ['exec', 'tsc', '-p', 'tsconfig.json'], {
  cwd: packageDir,
  stdio: 'inherit',
});

if (tscResult.status !== 0) {
  process.exit(tscResult.status ?? 1);
}

mkdirSync(distDir, { recursive: true });
cpSync(srcStyleFile, distStyleFile);
