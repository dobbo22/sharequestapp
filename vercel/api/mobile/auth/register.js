// /api/mobile/auth/register.js
// Registration endpoint for mobile app - creates user in Neon PostgreSQL

import { Pool } from 'pg';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';

const connectionString = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
const pool = new Pool({
  connectionString,
  ssl: connectionString ? { rejectUnauthorized: false } : undefined
});

// Generate a random salt
function generateSalt() {
  return crypto.randomBytes(16).toString('hex');
}

// Hash password with SHA256 and salt
function hashPassword(password, salt) {
  return crypto.createHash('sha256').update(password + salt).digest('hex');
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
    const { email, username, password, first_name, last_name, date_of_birth } = req.body;
    
    // Validation
    if (!email || !username || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email, username, and password are required'
      });
    }
    
    if (password.length < 8) {
      return res.status(400).json({
        success: false,
        error: 'Password must be at least 8 characters'
      });
    }
    
    // Check if email already exists
    const emailCheck = await pool.query(
      'SELECT user_id FROM users WHERE LOWER(email) = LOWER($1)',
      [email]
    );
    
    if (emailCheck.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Email already registered'
      });
    }
    
    // Check if username already exists
    const usernameCheck = await pool.query(
      'SELECT user_id FROM users WHERE LOWER(username) = LOWER($1)',
      [username]
    );
    
    if (usernameCheck.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Username already taken'
      });
    }
    
    // Hash password
    const salt = generateSalt();
    const passwordHash = hashPassword(password, salt);
    
    // Insert new user - use user_id as the column name
    const insertResult = await pool.query(
      `INSERT INTO users (username, email, password_hash, salt, first_name, last_name, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())
       RETURNING user_id::text as id, username, email, first_name, last_name`,
      [
        username.toLowerCase(),
        email.toLowerCase(),
        passwordHash,
        salt,
        first_name || null,
        last_name || null
      ]
    );
    
    const user = insertResult.rows[0];
    
    // Generate JWT token
    const token = jwt.sign(
      {
        userId: user.id,
        username: user.username,
        email: user.email,
        isAdmin: false
      },
      process.env.JWT_SECRET || 'sharequest-mobile-secret',
      { expiresIn: '30d' }
    );
    
    // Return success response
    return res.status(201).json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        first_name: user.first_name,
        last_name: user.last_name,
        isAdmin: false
      }
    });
    
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
}
