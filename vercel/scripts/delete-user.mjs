#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import { argv } from 'process';

async function main(){
  const userId = argv[2];
  if (!userId) {
    console.error('Usage: node delete-user.mjs <USER_ID>');
    process.exit(1);
  }
  const pool = getPool();
  const client = await pool.connect();
  try{
    console.log('Deleting tokens for user', userId);
    await client.query('DELETE FROM sq.api_tokens WHERE user_id = $1', [userId]);
    console.log('Deleting user row', userId);
    await client.query('DELETE FROM users WHERE user_id = $1', [userId]);
    console.log('Done');
  }catch(err){
    console.error('Error deleting user', err);
    process.exit(1);
  }finally{ client.release(); process.exit(0); }
}

main();
