#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import { argv } from 'process';

async function main(){
  const userId = argv[2];
  if (!userId) {
    console.error('Usage: node print-tokens.mjs <USER_ID>');
    process.exit(1);
  }
  const pool = getPool();
  const client = await pool.connect();
  try{
    const r = await client.query('SELECT id, value, hash_algo, user_id, expires_at, created_at FROM sq.api_tokens WHERE user_id = $1', [userId]);
    console.log(JSON.stringify(r.rows, null, 2));
  }catch(err){
    console.error('Error', err);
    process.exit(1);
  }finally{ client.release(); process.exit(0); }
}

main();
