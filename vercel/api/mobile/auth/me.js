// /api/mobile/auth/me.js
// Get current user profile endpoint

import { Pool } from 'pg';
import jwt from 'jsonwebtoken';

const connectionString = process.env.API_DATABASE_URL || process.env.DATABASE_URL;
const pool = new Pool({
  connectionString,
  ssl: connectionString ? { rejectUnauthorized: false } : undefined
});

// Verify JWT token and extract user info
function verifyToken(authHeader) {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  
  const token = authHeader.substring(7);
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'sharequest-mobile-secret');
    return decoded;
  } catch (error) {
    return null;
  }
}

export default async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  try {
    // Verify authorization
    const tokenData = verifyToken(req.headers.authorization);
    
    if (!tokenData) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized'
      });
    }
    
    // Get user from database - handle both id and user_id column names
    const userResult = await pool.query(
      `SELECT 
         COALESCE(user_id::text, id::text) as id, 
         username, 
         email, 
         COALESCE(first_name, '') as first_name, 
         COALESCE(last_name, '') as last_name, 
         COALESCE(is_admin, false) as is_admin, 
         created_at
       FROM public.users 
       WHERE user_id::text = $1 OR id::text = $1`,
      [tokenData.userId]
    );
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }
    
    const user = userResult.rows[0];
    
    return res.status(200).json({
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      isAdmin: user.is_admin || false,
      created_at: user.created_at
    });
    
  } catch (error) {
    console.error('Profile error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
}
