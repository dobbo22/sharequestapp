an#!/usr/bin/env node
import { getPool } from '../api/_db.js';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    const trigSql = `SELECT t.tgname, pg_get_triggerdef(t.oid) AS def
      FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid WHERE c.relname = 'users' AND NOT t.tgisinternal;`;
    const r1 = await client.query(trigSql);
    console.log('triggers:', r1.rows);

    const ruleSql = `SELECT * FROM pg_rules WHERE schemaname = 'public' AND tablename = 'users';`;
    const r2 = await client.query(ruleSql);
    console.log('rules:', r2.rows);

    const policySql = `SELECT polname, polcmd, polpermissive, polroles FROM pg_policies WHERE tablename = 'users';`;
    const r3 = await client.query(policySql);
    console.log('policies:', r3.rows);

    const constraintsSql = `SELECT conname, pg_get_constraintdef(oid) as def FROM pg_constraint WHERE conrelid = 'users'::regclass;`;
    const r4 = await client.query(constraintsSql);
    console.log('constraints:', r4.rows);
  }catch(err){
    console.error('error', err);
  }finally{ client.release(); }
}
main();
