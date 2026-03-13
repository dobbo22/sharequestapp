// Check users table schema
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: "postgresql://neondb_owner:npg_hnOjK9g3VJLI@ep-round-mountain-abas00um-pooler.eu-west-2.aws.neon.tech/neondb?sslmode=require",
  ssl: { rejectUnauthorized: false }
});

async function main() {
  try {
    const result = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users' 
      ORDER BY ordinal_position
    `);
    console.log('Users table columns:');
    console.log(JSON.stringify(result.rows, null, 2));
    
    // Also check for a sample user
    const users = await pool.query('SELECT id, username, email FROM users LIMIT 3');
    console.log('\nSample users:');
    console.log(JSON.stringify(users.rows, null, 2));
  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    await pool.end();
  }
}

main();
