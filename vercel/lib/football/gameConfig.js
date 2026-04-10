import { readFile } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const configPath = path.join(__dirname, '..', '..', '..', 'football-cards', 'backend', 'game-config.json');

export async function getFootballGameConfig() {
  if (global._footballGameConfig) {
    return global._footballGameConfig;
  }

  const raw = await readFile(configPath, 'utf8');
  const config = JSON.parse(raw);
  global._footballGameConfig = config;
  return config;
}