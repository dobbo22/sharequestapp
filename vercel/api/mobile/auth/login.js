// /api/mobile/auth/login.js
// Login endpoint for mobile app - authenticates against Neon PostgreSQL

import { Pool } from 'pg';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';

// Use the configured connection string (API_DATABASE_URL preferred) and enable SSL for Neon
const connectionString = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
if (!connectionString) {
  // No DB configured — throw a clear error
  throw new Error('No database connection string configured. Set API_DATABASE_URL or DATABASE_URL in your environment.');
}

// Create or reuse a global pool to avoid exhausting connections in serverless
function getPool() {
  if (global.__pgPool) return global.__pgPool;
  const pool = new Pool({
    connectionString,
    max: parseInt(process.env.PG_MAX_CLIENTS || '3', 10),
    ssl: {
      rejectUnauthorized: false,
    },
  });
  // ensure sq schema resolves first if present
  pool.on('connect', (client) => {
    client.query("SET search_path TO sq, public").catch(() => {});
  });
  global.__pgPool = pool;
  return pool;
}

// Hash password with SHA256 (matching the web app's method)
function hashPassword(password, salt = '') {
  return crypto.createHash('sha256').update(password + salt).digest('hex');
}

// Verify password against stored hash
async function verifyPassword(password, storedHash, salt = '') {
  const hash = hashPassword(password, salt);
  return hash === storedHash;
}

export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  try {
    const pool = getPool();
    const client = await pool.connect();
    try {
      const { email, password } = req.body;
      
      if (!email || !password) {
        return res.status(400).json({
          success: false,
          error: 'Email and password are required'
        });
      }
      
      // Find user by email or username - assume primary key column is user_id
      const userResult = await client.query(
        `SELECT 
           user_id::text as id,
           username,
           email,
           password_hash,
           COALESCE(first_name, '') as first_name,
           COALESCE(last_name, '') as last_name,
           COALESCE(is_admin, false) as is_admin,
           COALESCE(salt, '') as salt
         FROM users
         WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1)
         LIMIT 1`,
        [email]
      );
      
      if (userResult.rows.length === 0) {
        return res.status(401).json({
          success: false,
          error: 'Invalid email or password'
        });
      }
      
      const user = userResult.rows[0];
      
      // Verify password
      const isValid = await verifyPassword(password, user.password_hash, user.salt || '');
      
      if (!isValid) {
        return res.status(401).json({
          success: false,
          error: 'Invalid email or password'
        });
      }
      
      // Generate JWT token
      const token = jwt.sign(
        {
          userId: user.id,
          username: user.username,
          email: user.email,
          isAdmin: user.is_admin || false
        },
        process.env.JWT_SECRET || 'sharequest-mobile-secret',
        { expiresIn: '30d' }
      );
      
      // Return success response
      return res.status(200).json({
        success: true,
        token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          isAdmin: user.is_admin || false
        }
      });
      
    } finally {
      client.release();
    }
  } catch (error) {
    // If the runtime raised a JSON parse error (statusCode 400), return Bad Request
    if (error && error.statusCode === 400) {
      console.error('Login invalid JSON:', error.message || error);
      return res.status(400).json({ success: false, error: 'Invalid JSON' });
    }
    console.error('Login error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
}
