#!/usr/bin/env node
import { Pool } from 'pg';

const conn = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
(async () => {
  if (!conn) {
    console.error('No API_DATABASE_URL or DATABASE_URL set');
    process.exit(1);
  }
  const pool = new Pool({ connectionString: conn, ssl: { rejectUnauthorized: false } });
  try {
    console.log('Connected. Checking schemas...');
    const schemas = await pool.query("select schema_name from information_schema.schemata order by schema_name");
    console.log('Schemas:', schemas.rows.map(r=>r.schema_name).join(', '));
    const tables = await pool.query("select table_schema, table_name from information_schema.tables where table_schema in ('sq','public') order by table_schema, table_name");
    console.log('Tables in sq/public:', tables.rows);
  } catch (e) {
    console.error('DB error', e);
    process.exit(1);
  } finally {
    await pool.end();
  }
})();
