#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import crypto from 'crypto';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    // check if role exists
    const q1 = "SELECT 1 FROM pg_roles WHERE rolname = 'sharequest_api'";
    console.log('DEBUG: running', q1);
    const r = await client.query(q1);
    if (r.rowCount > 0) {
      console.log('Role sharequest_api already exists.');
      process.exit(0);
    } else {
      // generate strong password
      const pwd = crypto.randomBytes(24).toString('base64');
      // escape single quotes
      const pwdEsc = pwd.replace(/'/g, "''");
      const q2 = `CREATE ROLE sharequest_api WITH LOGIN PASSWORD '${pwdEsc}'`;
      console.log('DEBUG: running', q2.replace(/\n/g,' '));
      await client.query(q2);
      console.log('Created role sharequest_api');
      const q3 = 'GRANT USAGE ON SCHEMA sq TO sharequest_api';
      console.log('DEBUG: running', q3);
      await client.query(q3);
      const q4 = 'GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sq TO sharequest_api';
      console.log('DEBUG: running', q4);
      await client.query(q4);
      const q5 = "ALTER DEFAULT PRIVILEGES IN SCHEMA sq GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sharequest_api";
      console.log('DEBUG: running', q5);
      await client.query(q5);
      console.log('Granted privileges on schema sq to sharequest_api');

      // compute a connection string from DATABASE_URL but with new user and password
      const orig = process.env.DATABASE_URL;
      if (orig) {
        try{
          const u = new URL(orig);
          // set new user/pass
          u.username = 'sharequest_api';
          u.password = pwd;
          const newConn = u.toString();
          console.log('Connection string for sharequest_api (store this in Vercel env):');
          console.log(newConn);
        }catch(e){
          console.log('Could not compute sanitized connection string; provide new credentials to Vercel manually.');
          console.log('Password (base64):', pwd);
        }
      } else {
        console.log('DATABASE_URL not set; here is the password for sharequest_api:');
        console.log(pwd);
      }
    }
  }catch(err){
    console.error('Error creating role', err);
    process.exit(1);
  }finally{ client.release(); process.exit(0); }
}

main();
