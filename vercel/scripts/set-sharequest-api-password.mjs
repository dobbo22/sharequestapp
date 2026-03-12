#!/usr/bin/env node
import { getPool } from '../api/_db.js';
import crypto from 'crypto';

async function main(){
  const pool = getPool();
  const client = await pool.connect();
  try{
    const pwd = crypto.randomBytes(24).toString('base64');
    const pwdEsc = pwd.replace(/'/g, "''");
    // ALTER ROLE
    await client.query(`ALTER ROLE sharequest_api WITH LOGIN PASSWORD '${pwdEsc}'`);
    // compute connection string from process.env.DATABASE_URL
    const orig = process.env.DATABASE_URL;
    if (!orig) {
      console.error('DATABASE_URL not set in environment');
      process.exit(1);
    }
    const u = new URL(orig);
    u.username = 'sharequest_api';
    u.password = pwd;
    console.log(u.toString());
    // print password to stdout too (user asked to see secrets)
    console.log('---PASSWORD-START---');
    console.log(pwd);
    console.log('---PASSWORD-END---');
  }catch(err){
    console.error('error setting password', err);
    process.exit(1);
  }finally{ client.release(); }
}

main();
