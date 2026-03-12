#!/usr/bin/env node
import { getPool } from '../api/_db.js';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    const r = await client.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position");
    console.log('users columns:', r.rows);
  }catch(err){
    console.error('error', err);
  }finally{ client.release(); }
}
main();
