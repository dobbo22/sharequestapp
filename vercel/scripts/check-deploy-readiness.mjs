#!/usr/bin/env node
/*
  Deployment readiness checker
  - Verifies required environment variables are set for production
  - Ensures critical URL env vars do not point to localhost/127.0.0.1
  - Exit code: 0 = ready, 1 = issues found
*/

import fs from 'fs';
import path from 'path';

const checks = [
  { name: 'API_DATABASE_URL', required: true, desc: 'Primary DB connection string (Neon/Postgres) for API' },
  { name: 'DATABASE_URL', required: false, desc: 'Fallback DB connection string (optional if API_DATABASE_URL set)' },
  { name: 'EXPO_PUBLIC_API_URL', required: true, desc: 'Mobile app API base URL (must be public, include /api)' },
  { name: 'MAIN_APP_URL', required: false, desc: 'Used by mobile-api-server if deployed as standalone (should be public if used)' },
  { name: 'JWT_SECRET', required: true, desc: 'JWT signing secret for mobile auth' },
  { name: 'TOKEN_HMAC_SECRET', required: false, desc: 'HMAC secret used by API token tooling (optional)' },
  { name: 'REDIS_URL', required: false, desc: 'Optional Redis URL for rate limiting' },
  { name: 'SERVICE_API_TOKEN', required: false, desc: 'Optional service token for backend-to-backend calls' },
];

function isLocalHostish(value) {
  if (!value) return false;
  const v = String(value).toLowerCase();
  return v.includes('localhost') || v.includes('127.0.0.1') || v.includes('[::1]') || v.includes('::1');
}

function short(v) {
  if (!v) return '';
  const s = String(v);
  if (s.length <= 32) return s;
  return s.slice(0, 10) + '…' + s.slice(-10);
}

console.log('\n=== ShareQuest deployment readiness check ===\n');

const errors = [];
const warnings = [];
const infos = [];

for (const c of checks) {
  const val = process.env[c.name];
  if (val === undefined || val === null || String(val) === '') {
    if (c.required) {
      errors.push(`${c.name}: MISSING (required) — ${c.desc}`);
    } else {
      warnings.push(`${c.name}: not set — ${c.desc}`);
    }
  } else {
    // Present
    if (isLocalHostish(val)) {
      errors.push(`${c.name}: set but points to localhost/loopback (${short(val)}) — update to a remote host for production`);
    } else {
      infos.push(`${c.name}: set (${short(val)})`);
    }
  }
}

// Special logic: if API_DATABASE_URL not set but DATABASE_URL is set, treat as OK but warn
if (!process.env.API_DATABASE_URL && process.env.DATABASE_URL) {
  warnings.push('API_DATABASE_URL not set but DATABASE_URL is present — consider setting API_DATABASE_URL to a limited-role connection for serverless functions.');
}

// If mobile-api-server.js exists in repo, recommend MAIN_APP_URL
try {
  const repoMobileApiServer = path.join(process.cwd(), 'mobile-app', 'mobile-api-server.js');
  if (fs.existsSync(repoMobileApiServer)) {
    if (!process.env.MAIN_APP_URL) {
      warnings.push('mobile-api-server detected in repository but MAIN_APP_URL is not set — mobile-api-server in production requires MAIN_APP_URL to point to your remote API (include /api suffix)');
    } else if (isLocalHostish(process.env.MAIN_APP_URL)) {
      errors.push('MAIN_APP_URL is configured but points to localhost/127.0.0.1 — mobile-api-server will refuse to start in production with this value');
    }
  }
} catch (e) {
  // ignore
}

// Print summary
if (infos.length) {
  console.log('Info:');
  for (const i of infos) console.log('  ✔', i);
  console.log('');
}

if (warnings.length) {
  console.log('Warnings:');
  for (const w of warnings) console.log('  ⚠', w);
  console.log('');
}

if (errors.length) {
  console.log('Errors:');
  for (const e of errors) console.log('  ✖', e);
  console.log('');
}

if (errors.length === 0) {
  console.log('✅ Deployment readiness: OK — No blocking issues detected.');
  if (warnings.length) console.log('⚠ Resolve warnings before promoting to production for best practice.');
  console.log('\n');
  process.exit(0);
} else {
  console.log('❌ Deployment readiness: FAILED — Fix the errors above before deploying to production.');
  console.log('\n');
  process.exit(1);
}
