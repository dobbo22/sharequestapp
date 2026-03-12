curl -i "https://aiert.vercel.app/api/items"#!/usr/bin/env node
import { getPool } from '../api/_db.js';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    const tables = await client.query("SELECT table_name FROM information_schema.tables WHERE table_schema='sq' ORDER BY table_name");
    console.log('tables in schema sq:', tables.rows);
    const cols = await client.query("SELECT table_name, column_name, data_type FROM information_schema.columns WHERE table_schema='sq' ORDER BY table_name, ordinal_position");
    console.log('columns:');
    for (const r of cols.rows) console.log(r);
  }catch(err){
    console.error('error', err);
  }finally{ client.release(); }
}
main();
