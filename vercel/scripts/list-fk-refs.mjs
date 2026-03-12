#!/usr/bin/env node
import { getPool } from '../api/_db.js';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    const sql = `
      SELECT
        con.conname AS constraint_name,
        conrel.relname AS table_name,
        a_att.attname AS column_name,
        confrel.relname AS referenced_table,
        af_att.attname AS referenced_column
      FROM pg_constraint con
      JOIN pg_class conrel ON con.conrelid = conrel.oid
      JOIN pg_class confrel ON con.confrelid = confrel.oid
      JOIN unnest(con.conkey) WITH ORDINALITY AS cols(attnum, ord) ON true
      JOIN pg_attribute a_att ON a_att.attnum = cols.attnum AND a_att.attrelid = conrel.oid
      JOIN unnest(con.confkey) WITH ORDINALITY AS refcols(attnum, ord) ON refcols.ord = cols.ord
      JOIN pg_attribute af_att ON af_att.attnum = refcols.attnum AND af_att.attrelid = confrel.oid
      WHERE con.contype = 'f'
      ORDER BY con.conname;
    `;
    const r = await client.query(sql);
    console.log('foreign keys:');
    for (const row of r.rows) {
      console.log(row);
    }
  }catch(err){
    console.error('error', err);
  }finally{ client.release(); }
}
main();
