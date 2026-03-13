// Mobile API Server - Provides database connectivity for mobile app
// This server runs alongside the mobile app and makes server-side requests to main app
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const { Pool, types } = require('pg');

// Configure PostgreSQL type parsers to return numbers instead of strings
types.setTypeParser(1700, function(val) {
  return parseFloat(val);
});

// Optional: Handle other numeric types that might be returned as strings
types.setTypeParser(types.builtins.INT8, function(val) {
  return parseInt(val, 10);
});

types.setTypeParser(types.builtins.FLOAT8, function(val) {
  return parseFloat(val);
});

types.setTypeParser(types.builtins.NUMERIC, function(val) {
  return parseFloat(val);
});

console.log('✅ PostgreSQL type parsers configured for numeric types');

// Initialize connection pool with environment variables or fallback values
// Tip: You can set DEFAULT_MOBILE_USER_ID to override the fallback user header for dev
// process.env.DEFAULT_MOBILE_USER_ID = 'Bina';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || process.env.POSTGRES_URL,
  ssl: process.env.NODE_ENV === 'production' 
    ? { rejectUnauthorized: false } 
    : false
});

// Generic query function
async function query(text, params) {
  const client = await pool.connect();
  try {
    return await client.query(text, params);
  } finally {
    client.release();
  }
}

const app = express();
const PORT = parseInt(process.env.PORT || '8082', 10); // Mobile API server port - matching mobile app's expected port
const MAIN_APP_URL = process.env.MAIN_APP_URL || 'http://localhost:3000/api'; // Updated to include /api prefix
const MAX_RETRIES = 5;
const RETRY_DELAY = 2000; // 2 seconds

// Add comprehensive error handling
process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught Exception:', err);
  // Keep the process running
});

process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled Promise Rejection:', err);
  // Keep the process running
});

// Handle process signals
process.on('SIGTERM', () => {
  console.log('📥 Received SIGTERM. Performing graceful shutdown...');
  server?.close(() => {
    console.log('Server closed gracefully');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('📥 Received SIGINT. Performing graceful shutdown...');
  server?.close(() => {
    console.log('Server closed gracefully');
    process.exit(0);
  });
});

// Middleware should be added first
app.use(express.json());
app.use(cors({
  origin: '*',
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id']
}));

// Log all incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Set proxy-only mode by default since we're using the main app's API
const dbConnected = false;
console.log('ℹ️ Mobile API Server running in proxy-only mode - all requests will be forwarded to main app');

console.log('🚀 Starting Mobile API Server for database connectivity...');

// Enable CORS for mobile app and development
const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = [
      'http://localhost:8081',
      'http://localhost:8082',
      'http://localhost:3000',
      'http://localhost:3001',
      'exp://localhost:8081',
      undefined // Allow requests with no origin (like mobile apps, curl)
    ];
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, true); // Allow all origins in development
    }
  },
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id'],
  optionsSuccessStatus: 200 // Some legacy browsers choke on 204
};

app.use(cors(corsOptions));

app.use(express.json());

// Debug middleware to log all requests
app.use((req, res, next) => {
  console.log(`📝 Request: ${req.method} ${req.path}`);
  console.log('Headers:', req.headers);
  console.log('Query:', req.query);
  next();
});

// Stocks endpoints - register these first (COMMENTED OUT - using proxy endpoints instead)
/* app.get(['/api/mobile/stocks/ftse100', '/api/stocks/ftse100'], async (req, res) => {
  console.log('📊 Mobile API: FTSE 100 stocks request');
  
  try {
    const { limit = 100 } = req.query;
    
    const result = await query(`
      SELECT
        symbol,
        companyname,
        sector,
        sector_disp,
        last_price,
        day_change,
        day_change_percent,
        volume,
        updated_at,
        is_active
      FROM stocks
      WHERE security_type = 'FTSE100'
      AND is_active = true
      ORDER BY market_cap DESC NULLS LAST
      LIMIT $1
    `, [limit]);
    
    res.status(200)
       .set('Cache-Control', 'private, max-age=60') // Cache for 1 minute
       .json({
         success: true,
         stocks: result.rows.map(stock => ({
           symbol: stock.symbol,
           companyName: stock.companyname,
           sector: stock.sector_disp || stock.sector || 'Unknown',
           lastPrice: stock.last_price,
           changeAmount: stock.day_change,
           changePercent: stock.day_change_percent,
           volume: stock.volume || 0,
           lastUpdated: stock.updated_at
         })),
         totalCount: result.rowCount
       });
  } catch (error) {
    console.error('FTSE 100 fetch error:', error);
    
    res.status(500)
       .json({
         success: false,
         error: 'FTSE 100 stocks fetch failed: ' + error.message,
         code: 'DB_ERROR'
       });
  }
});

app.get(['/api/mobile/stocks/ftse250', '/api/stocks/ftse250'], async (req, res) => {
  console.log('📊 Mobile API: FTSE 250 stocks request');
  
  try {
    const { limit = 250 } = req.query;
    
    const result = await query(`
      SELECT
        symbol,
        companyname,
        sector,
        sector_disp,
        last_price,
        day_change,
        day_change_percent,
        volume,
        updated_at,
        is_active
      FROM stocks
      WHERE security_type = 'FTSE250'
      AND is_active = true
      ORDER BY market_cap DESC NULLS LAST
      LIMIT $1
    `, [limit]);
    
    res.status(200)
       .set('Cache-Control', 'private, max-age=60') // Cache for 1 minute
       .json({
         success: true,
         stocks: result.rows.map(stock => ({
           symbol: stock.symbol,
           companyName: stock.companyname,
           sector: stock.sector_disp || stock.sector || 'Unknown',
           lastPrice: stock.last_price,
           changeAmount: stock.day_change,
           changePercent: stock.day_change_percent,
           volume: stock.volume || 0,
           lastUpdated: stock.updated_at
         })),
         totalCount: result.rowCount
       });
  } catch (error) {
    console.error('FTSE 250 fetch error:', error);
    
    res.status(500)
       .json({
         success: false,
         error: 'FTSE 250 stocks fetch failed: ' + error.message,
         code: 'DB_ERROR'
       });
  }
}); */

// Helper function to make requests to main app
async function proxyToMainApp(endpoint, options = {}, retryCount = 0) {
  try {
    // Remove any leading /api from the endpoint to prevent duplication
    const cleanEndpoint = endpoint.replace(/^\/api/, '');
    const url = `${MAIN_APP_URL}${cleanEndpoint}`;
    console.log(`🔄 [Attempt ${retryCount + 1}/${MAX_RETRIES}] Proxying to main app: ${options.method || 'GET'} ${url}`);
  
    // Create AbortController for timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 30000); // 30 second timeout
    
    // Add retry mechanism
    let retries = 3;
    let lastError;
    
    // Build request headers with sensible defaults and fallbacks
    const requestHeaders = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...(options.headers || {})
    };

    // Ensure x-user-id is present for mobile API compatibility (fallback to Bina in dev)
    if (!requestHeaders['x-user-id'] && !requestHeaders['X-User-Id']) {
      requestHeaders['x-user-id'] = process.env.DEFAULT_MOBILE_USER_ID || 'Bina';
    }

    // Log the outgoing request headers (without sensitive data)
    const debugHeaders = { ...requestHeaders };
    if (debugHeaders.Authorization) debugHeaders.Authorization = '[redacted]';
    console.log('➡️  Proxy request headers:', debugHeaders);

    const response = await fetch(url, {
      method: options.method || 'GET',
      headers: requestHeaders,
      body: options.body ? JSON.stringify(options.body) : undefined,
      signal: controller.signal,
      keepalive: true,
      cache: 'no-cache'
    });
    
    if (!response) {
      throw lastError || new Error('Failed to fetch after all retries');
    }
    
    // Clear timeout since request completed
    clearTimeout(timeoutId);
    
    let data;
    try {
      data = await response.text();
      console.log(`✅ Main app response: ${response.status}`);
      console.log('Response data (first 1000 chars):', data.substring(0, 1000));
      console.log('Content-Type:', response.headers.get('content-type'));
      
      // Check if the response is empty
      if (!data.trim()) {
        throw new Error('Empty response received');
      }
    } catch (error) {
      console.error('Error reading response:', error);
      throw new Error(`Failed to read response: ${error.message}`);
    }
    
    if (!response.ok) {
      console.error('Response not OK:', response.status, data);
      if (data.trim().startsWith('{') || data.trim().startsWith('[')) {
        try {
          const errorData = JSON.parse(data);
          const errorMessage = errorData.error || `HTTP error! status: ${response.status}`;
          
          // Check if this is a subscription error - don't retry these
          if (response.status === 403 && 
              (errorMessage.includes('subscription required') || 
               errorMessage.includes('subscription') || 
               errorData.subscriptionRequired)) {
            console.log('📊 Subscription error detected - not retrying');
            const subscriptionError = new Error(errorMessage);
            subscriptionError.isSubscriptionError = true;
            throw subscriptionError;
          }
          
          throw new Error(errorMessage);
        } catch (e) {
          console.error('Error parsing error response:', e);
          throw new Error(`HTTP error! status: ${response.status}`);
        }
      }
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    // Try to handle both JSON and non-JSON responses gracefully
    let parsedData;
    try {
      // Clean the data string - remove any control characters and BOM
      const cleanData = data.replace(/[\u0000-\u001F\u007F-\u009F\uFEFF]/g, '');
      
      // Log the cleaned data for debugging
      console.log('Cleaned data:', cleanData);
      
      // First try to parse as JSON regardless of content type
      if (cleanData.trim().startsWith('{') || cleanData.trim().startsWith('[')) {
        try {
          parsedData = JSON.parse(cleanData);
        } catch (jsonError) {
          console.error('JSON Parse Error. Attempting to fix malformed JSON...');
          // Try to fix common JSON issues
          const fixedData = cleanData
            .replace(/\n/g, ' ')          // Remove newlines
            .replace(/\r/g, '')           // Remove carriage returns
            .replace(/\t/g, ' ')          // Replace tabs with spaces
            .replace(/\\'/g, "'")         // Fix escaped single quotes
            .replace(/\\/g, '\\\\')       // Escape backslashes
            .replace(/"/g, '\\"')         // Escape quotes
            .replace(/(['"])?([a-zA-Z0-9_]+)(['"])?:/g, '"$2":'); // Ensure property names are quoted
          
          console.log('Fixed data:', fixedData);
          parsedData = JSON.parse(fixedData);
        }
      } else {
        // If it doesn't look like JSON, check content type
        if (response.headers.get('content-type')?.includes('application/json')) {
          // It claims to be JSON but doesn't look like it - return error
          console.error('Invalid JSON response:', cleanData);
          parsedData = {
            success: false,
            error: 'Invalid JSON response received',
            raw: cleanData
          };
        } else {
          // Not JSON and doesn't claim to be - return as text
          parsedData = {
            success: true,
            data: cleanData
          };
        }
      }
    } catch (e) {
      console.error('JSON Parse Error:', e);
      console.error('Raw data:', data);
      parsedData = {
        success: false,
        error: `Failed to parse response: ${e.message}`,
        raw: data
      };
    }
    
    return {
      status: response.status,
      data: parsedData,
      headers: Object.fromEntries(response.headers.entries())
    };
  } catch (error) {
    console.error(`❌ Error proxying to main app (attempt ${retryCount + 1}):`, error);
    
    // If it's a subscription error, don't retry
    if (error.isSubscriptionError) {
      console.log('📊 Subscription error - not retrying');
      throw error;
    }
    
    // If we haven't exceeded max retries, try again after delay
    if (retryCount < MAX_RETRIES - 1) {
      console.log(`⏳ Retrying in ${RETRY_DELAY/1000} seconds...`);
      await new Promise(resolve => setTimeout(resolve, RETRY_DELAY));
      return proxyToMainApp(endpoint, options, retryCount + 1);
    }
    
    if (error.name === 'AbortError') {
      throw new Error('Request timed out after 30 seconds');
    }
    throw error;
  }
}

// Authentication endpoints
app.post('/api/auth/login', async (req, res) => {
  console.log('🔐 Mobile API: Login request received');
  console.log('Request body:', req.body);
  console.log('Headers:', req.headers);
  
  try {
    const result = await proxyToMainApp('/mobile/auth/login', {
      method: 'POST',
      body: req.body
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Authentication failed: ' + error.message
    });
  }
});

// Add mobile-specific auth endpoint that the mobile app expects
app.post('/api/mobile/auth/login', async (req, res) => {
  console.log('🔐 Mobile API: Mobile auth login request received');
  
  try {
    const result = await proxyToMainApp('/mobile/auth/login', {
      method: 'POST',
      body: req.body
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Authentication failed: ' + error.message
    });
  }
});

app.post('/api/auth/logout', async (req, res) => {
  console.log('🚪 Mobile API: Logout request received');
  res.json({ success: true, message: 'Logged out successfully' });
});

// Portfolio endpoints
app.get('/api/portfolio/:portfolioType', async (req, res) => {
  console.log(`💼 Mobile API: Portfolio request for ${req.params.portfolioType}`);
  
  try {
    // First try to get portfolio with extra error handling
    let result;
    try {
    result = await proxyToMainApp(`/mobile/portfolio/${req.params.portfolioType}`, {
        method: 'GET',
        headers: {
      'Authorization': req.headers.authorization,
      'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
        }
      });
      
      console.log('Initial portfolio result:', result);
    } catch (fetchError) {
      console.error('Initial portfolio fetch failed:', fetchError);
      result = { status: 404, data: { success: false } };
    }
    
    // Check if we need to initialize the portfolio
    const needsInit = !result.data?.success || !result.data?.portfolio || result.status >= 400;
    
    if (needsInit) {
      console.log('Portfolio needs initialization...');
      
      try {
        // Try to initialize portfolio with default balance
        const initResult = await proxyToMainApp(`/mobile/portfolio/${req.params.portfolioType}/initialise`, {
          method: 'POST',
          headers: {
            'Authorization': req.headers.authorization,
            'x-user-id': req.headers['x-user-id'],
            'Content-Type': 'application/json'
          },
          body: { initialBalance: 10000000 } // £100,000 in pence
        });
        
        console.log('Portfolio initialization result:', initResult);
        
        if (initResult.data?.success) {
          // After initialization, try to fetch portfolio again with error handling
          try {
      result = await proxyToMainApp(`/mobile/portfolio/${req.params.portfolioType}`, {
              method: 'GET',
              headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
              }
            });
            
            console.log('Portfolio fetch after init:', result);
          } catch (refetchError) {
            console.error('Portfolio refetch failed:', refetchError);
            // Provide fallback data if refetch fails
            result = {
              status: 200,
              data: {
                success: true,
                portfolio: {
                  totalValue: 10000000,
                  cashBalance: 10000000,
                  holdingsValue: 0,
                  holdings: []
                }
              }
            };
          }
        }
      } catch (initError) {
        console.error('Portfolio initialization failed:', initError);
      }
    }
    
    // Ensure we have a valid response even if everything fails
    const responseData = {
      success: result.data?.success || false,
      portfolio: result.data?.portfolio || {
        totalValue: 10000000, // £100,000 in pence
        cashBalance: 10000000,
        holdingsValue: 0,
        holdings: []
      },
      holdings: result.data?.holdings || []
    };
    
    res.status(200).json(responseData);
  } catch (error) {
    console.error('Portfolio request error:', error);
    
    // Always return a valid JSON response
    res.status(200).json({
      success: false,
      error: 'Portfolio fetch failed: ' + error.message,
      portfolio: {
        totalValue: 10000000, // £100,000 in pence
        cashBalance: 10000000,
        holdingsValue: 0,
        holdings: []
      },
      holdings: []
    });
  }
});

// Trades endpoints
app.get(['/api/trades/recent', '/api/mobile/trades/recent'], async (req, res) => {
  console.log('📈 Mobile API: Recent trades request');
  
  try {
  const result = await proxyToMainApp('/mobile/trades/recent', {
      method: 'GET',
      headers: {
    'Authorization': req.headers.authorization,
    'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Recent trades fetch failed: ' + error.message
    });
  }
});

app.get('/api/trades/:portfolioType', async (req, res) => {
  console.log(`📈 Mobile API: Trades request for ${req.params.portfolioType}`);
  
  try {
    const result = await proxyToMainApp(`/api/trades/${req.params.portfolioType}`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Trades fetch failed: ' + error.message
    });
  }
});

// Mobile portfolio endpoints
app.get('/api/mobile/portfolio/:portfolioType', async (req, res) => {
  console.log(`💼 Mobile API: Portfolio request for ${req.params.portfolioType}`);
  
  try {
    const result = await proxyToMainApp(`/mobile/portfolio/${req.params.portfolioType}`, {
      method: 'GET',
      headers: {
  'Authorization': req.headers.authorization,
  'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Portfolio fetch failed: ' + error.message
    });
  }
});

app.post('/api/trades/:portfolioType', async (req, res) => {
  console.log(`💰 Mobile API: Trade execution for ${req.params.portfolioType}`);
  
  try {
    const result = await proxyToMainApp(`/mobile/trades/${req.params.portfolioType}`, {
      method: 'POST',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      },
      body: req.body
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Trade execution failed: ' + error.message
    });
  }
});

// Gamification endpoints - proxy to main app
app.post('/api/mobile/gamification/login', async (req, res) => {
  console.log('🎮 Mobile API: Gamification login');
  try {
    const result = await proxyToMainApp('/mobile/gamification/login', {
      method: 'POST',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({ success: false, error: 'Gamification login failed: ' + error.message });
  }
});

app.get('/api/mobile/gamification/profile', async (req, res) => {
  console.log('🎮 Mobile API: Gamification profile');
  try {
    const result = await proxyToMainApp('/mobile/gamification/profile', {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({ success: false, error: 'Gamification profile failed: ' + error.message });
  }
});

app.get('/api/mobile/gamification/challenges', async (req, res) => {
  console.log('🎮 Mobile API: Gamification challenges');
  try {
    const result = await proxyToMainApp('/mobile/gamification/challenges', {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({ success: false, error: 'Gamification challenges failed: ' + error.message });
  }
});

app.get('/api/mobile/gamification/achievements', async (req, res) => {
  console.log('🎮 Mobile API: Gamification achievements');
  try {
    const result = await proxyToMainApp('/mobile/gamification/achievements', {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({ success: false, error: 'Gamification achievements failed: ' + error.message });
  }
});

app.post('/api/mobile/gamification/check', async (req, res) => {
  console.log('🎮 Mobile API: Gamification check');
  try {
    const result = await proxyToMainApp('/mobile/gamification/check', {
      method: 'POST',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({ success: false, error: 'Gamification check failed: ' + error.message });
  }
});

// Unified dashboard endpoint - proxy to main app
app.get('/api/mobile/dashboard/unified', async (req, res) => {
  console.log('📊 Mobile API: Unified dashboard request');
  try {
    const qs = req.url.includes('?') ? req.url.split('?')[1] : '';
    const result = await proxyToMainApp(`/mobile/dashboard/unified${qs ? '?' + qs : ''}`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Unified dashboard fetch failed: ' + error.message
    });
  }
});

// Subscriptions endpoints
app.get('/api/subscriptions', async (req, res) => {
  console.log('📋 Mobile API: Subscriptions request received');
  
  try {
  const result = await proxyToMainApp('/mobile/subscriptions', {
      method: 'GET',
      headers: {
    'Authorization': req.headers.authorization,
    'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Subscriptions fetch failed: ' + error.message
    });
  }
});

// Mobile subscriptions endpoint (alternative path)
app.get('/api/mobile/subscriptions', async (req, res) => {
  console.log('📋 Mobile API: Mobile subscriptions request received');
  
  try {
  const result = await proxyToMainApp('/mobile/subscriptions', {
      method: 'GET',
      headers: {
    'Authorization': req.headers.authorization,
    'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Mobile subscriptions fetch failed: ' + error.message
    });
  }
});

// Mobile auth/me endpoint
app.get('/api/mobile/auth/me', async (req, res) => {
  console.log('👤 Mobile API: Auth/me request received');
  
  try {
    const result = await proxyToMainApp('/api/mobile/auth/me', {
      method: 'GET',
      headers: {
  'Authorization': req.headers.authorization,
  'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    console.error('❌ Mobile auth/me error:', error.message);
    res.status(401).json({
      success: false,
      error: 'Authentication failed: ' + error.message
    });
  }
});

// Sectors endpoint - proxy to main app (MUST be before :symbol route)
app.get('/api/stocks/sectors', async (req, res) => {
  console.log('📊 Mobile API: Sectors proxy request', req.query);

  try {
    const { sector } = req.query;
    const endpoint = sector
      ? `/api/stocks/sectors?sector=${encodeURIComponent(sector)}`
      : '/api/stocks/sectors';

    const result = await proxyToMainApp(endpoint, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });

    res.status(result.status).json(result.data);
  } catch (error) {
    console.error('❌ Sectors proxy error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Sectors proxy failed: ' + error.message
    });
  }
});

// Stock detail endpoint with full details
app.get('/api/stocks/:symbol', async (req, res) => {
  console.log(`📊 Mobile API: Stock detail request for ${req.params.symbol}`);
  
  try {
    const result = await proxyToMainApp(`/api/stocks/${req.params.symbol}`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    console.error(`❌ Stock detail error for ${req.params.symbol}:`, error.message);
    res.status(500).json({
      success: false,
      error: 'Stock data fetch failed: ' + error.message
    });
  }
});

// TODO: Subscription history endpoint - implement with main app payment system
// app.get('/api/subscriptions/history', async (req, res) => {
//   console.log('📋 Mobile API: Subscription history request received');
//   
//   // Return empty history for now - will be implemented with payment system
//   res.status(200).json({
//     success: true,
//     data: {
//       payments: []
//     }
//   });
// });

// Log all incoming requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Stocks endpoints (COMMENTED OUT - using proxy endpoints instead)
/* app.get('/api/mobile/stocks/ftse100', async (req, res) => {
  console.log('📊 Mobile API: FTSE 100 stocks request');
  
  try {
    const { limit = 100 } = req.query;
    
    const result = await query(`
      SELECT
        symbol,
        companyname,
        sector,
        sector_disp,
        last_price,
        day_change,
        day_change_percent,
        volume,
        updated_at,
        is_active
      FROM stocks
      WHERE security_type = 'FTSE100'
      AND is_active = true
      ORDER BY market_cap DESC NULLS LAST
      LIMIT $1
    `, [limit]);
    
    res.status(200)
       .set('Cache-Control', 'private, max-age=60') // Cache for 1 minute
       .json({
         success: true,
         stocks: result.rows.map(stock => ({
           symbol: stock.symbol,
           companyName: stock.companyname,
           sector: stock.sector_disp || stock.sector || 'Unknown',
           lastPrice: stock.last_price,
           changeAmount: stock.day_change,
           changePercent: stock.day_change_percent,
           volume: stock.volume || 0,
           lastUpdated: stock.updated_at
         })),
         totalCount: result.rowCount
       });
  } catch (error) {
    console.error('FTSE 100 fetch error:', error);
    
    res.status(500)
       .json({
         success: false,
         error: 'FTSE 100 stocks fetch failed: ' + error.message,
         code: 'DB_ERROR'
       });
  }
});

app.get('/api/mobile/stocks/ftse250', async (req, res) => {
  console.log('📊 Mobile API: FTSE 250 stocks request');
  
  try {
    const { limit = 250 } = req.query;
    
    const result = await query(`
      SELECT
        symbol,
        companyname,
        sector,
        sector_disp,
        last_price,
        day_change,
        day_change_percent,
        volume,
        updated_at,
        is_active
      FROM stocks
      WHERE security_type = 'FTSE250'
      AND is_active = true
      ORDER BY market_cap DESC NULLS LAST
      LIMIT $1
    `, [limit]);
    
    res.status(200)
       .set('Cache-Control', 'private, max-age=60') // Cache for 1 minute
       .json({
         success: true,
         stocks: result.rows.map(stock => ({
           symbol: stock.symbol,
           companyName: stock.companyname,
           sector: stock.sector_disp || stock.sector || 'Unknown',
           lastPrice: stock.last_price,
           changeAmount: stock.day_change,
           changePercent: stock.day_change_percent,
           volume: stock.volume || 0,
           lastUpdated: stock.updated_at
         })),
         totalCount: result.rowCount
       });
  } catch (error) {
    console.error('FTSE 250 fetch error:', error);
    
    res.status(500)
       .json({
         success: false,
         error: 'FTSE 250 stocks fetch failed: ' + error.message,
         code: 'DB_ERROR'
       });
  }
}); */

app.get('/api/stocks/search', async (req, res) => {
  console.log('🔍 Mobile API: Stock search request received');
  
  try {
    const result = await proxyToMainApp(`/mobile/stocks/search?${new URLSearchParams(req.query)}`, {
      method: 'GET'
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Stock search failed: ' + error.message
    });
  }
});

// Batch prices endpoint for mobile app
app.post('/api/stocks/batch-prices', async (req, res) => {
  console.log('📊 Mobile API: Batch prices request received');
  
  try {
    const result = await proxyToMainApp('/mobile/stocks/batch-prices', {
      method: 'POST',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      },
      body: req.body
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Batch prices failed: ' + error.message
    });
  }
});

// Additional stock endpoints that proxy to main app (moved before :symbol to avoid conflict)
app.get(['/api/stocks/ftse100', '/api/mobile/stocks/ftse100'], async (req, res) => {
  console.log('📊 Mobile API: FTSE 100 proxy request');
  
  try {
    const { limit } = req.query;
    console.log('🔄 Proxying FTSE 100 request to main app...');
    
    // Use the mobile-specific endpoint
    const result = await proxyToMainApp('/mobile/stocks/ftse100', {
      method: 'GET',
      headers: {
        ...req.headers,
        'accept': 'application/json',
        'content-type': 'application/json'
      }
    });
    
    console.log('✅ FTSE 100 response received:', result.status);
    res.status(result.status).json(result.data);
  } catch (error) {
    console.error('❌ FTSE 100 proxy error:', error);
    res.status(500).json({
      success: false,
      error: 'FTSE 100 proxy failed: ' + error.message,
      details: error.stack
    });
  }
});

app.get('/api/stocks/ftse250', async (req, res) => {
  console.log('📊 Mobile API: FTSE 250 proxy request');
  
  try {
    const { limit } = req.query;
    const result = await proxyToMainApp(`/mobile/stocks/ftse250${limit ? `?limit=${limit}` : ''}`, {
      method: 'GET'
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'FTSE 250 proxy failed: ' + error.message
    });
  }
});

app.get('/api/stocks/top100', async (req, res) => {
  console.log('📊 Mobile API: Top 100 stocks proxy request');
  
  try {
    const { limit } = req.query;
    const result = await proxyToMainApp(`/api/stocks/top100${limit ? `?limit=${limit}` : ''}`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Top 100 stocks proxy failed: ' + error.message
    });
  }
});


// Transactions endpoint
app.get('/api/transactions/recent', async (req, res) => {
  console.log('📈 Mobile API: Recent transactions request');
  
  try {
    const result = await proxyToMainApp('/api/transactions/recent', {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Transactions fetch failed: ' + error.message
    });
  }
});

// Portfolio holdings endpoints
// Get portfolio balance endpoint
app.get('/api/portfolio/:type/balance', async (req, res) => {
  console.log(`💰 Mobile API: Portfolio balance request for ${req.params.type}`);
  
  try {
    const result = await proxyToMainApp(`/api/portfolio/${req.params.type}/balance${req.query.userId ? `?userId=${req.query.userId}` : ''}`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Portfolio balance fetch failed: ' + error.message
    });
  }
});

app.post('/api/portfolio/:type/initialise', async (req, res) => {
  console.log(`🆕 Mobile API: Portfolio initialization request for ${req.params.type}`);
  
  try {
    const result = await proxyToMainApp(`/api/portfolio/${req.params.type}/initialise`, {
      method: 'POST',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id'],
        'Content-Type': 'application/json'
      },
      body: req.body
    });
    
    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Portfolio initialization failed: ' + error.message
    });
  }
});

app.get('/api/portfolio/:type/holdings', async (req, res) => {
  console.log(`💼 Mobile API: Portfolio holdings request for ${req.params.type}`);
  
  try {
    // Use mobile endpoint that includes holdings in response
  const result = await proxyToMainApp(`/mobile/portfolio/${req.params.type}`, {
      method: 'GET',
      headers: {
    'Authorization': req.headers.authorization,
    'x-user-id': req.headers['x-user-id'] || process.env.DEFAULT_MOBILE_USER_ID || 'Bina'
      }
    });
    
    // Normalize response to ensure it contains holdings array
    const holdings = result.data?.holdings || result.data?.data?.holdings || [];
    res.status(200).json({ success: true, holdings });
  } catch (error) {
    // Handle 403 (subscription required) errors gracefully
    if (error.message.includes('HTTP error! status: 403') || error.message.includes('HTTP error! status: 401')) {
      const pType = req.params.type;
      console.log(`📋 Portfolio ${pType} access restricted (subscription/auth)`);
      return res.status(200).json({
        success: true,
        requiresSubscription: error.message.includes('403') || undefined,
        requiresAuth: error.message.includes('401') || undefined,
        portfolioType: pType,
        message: `${pType.charAt(0).toUpperCase() + pType.slice(1)} portfolio ${error.message.includes('401') ? 'requires authentication' : 'may require a subscription'}`,
        portfolio: null,
        holdings: []
      });
    }
    
    res.status(500).json({
      success: false,
      error: 'Portfolio holdings fetch failed: ' + error.message
    });
  }
});

// Portfolio transactions endpoint (proxy to main app portfolio-specific transactions)
app.get('/api/portfolio/:type/transactions', async (req, res) => {
  console.log(`📄 Mobile API: Portfolio transactions request for ${req.params.type}`);
  try {
    const result = await proxyToMainApp(`/api/portfolio/${req.params.type}/transactions`, {
      method: 'GET',
      headers: {
        'Authorization': req.headers.authorization,
        'x-user-id': req.headers['x-user-id']
      }
    });

    res.status(result.status).json(result.data);
  } catch (error) {
    res.status(500).json({
      success: false,
      error: 'Portfolio transactions fetch failed: ' + error.message
    });
  }
});

// Leaderboard endpoints
app.get('/api/leaderboard/:type', async (req, res) => {
  console.log(`🏆 Mobile API: Leaderboard request for ${req.params.type}`);
  
  try {
    // Forward to main app subscription-filtered endpoint: /api/leaderboards/:type
    const result = await proxyToMainApp(`/api/leaderboards/${req.params.type}`, {
      method: 'GET'
    });
    console.log('➡️  Forwarded to /api/leaderboards, status:', result.status);
    res.status(result.status).json(result.data);
  } catch (error) {
    console.error('❌ Leaderboard proxy error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Leaderboard fetch failed: ' + error.message
    });
  }
});

// Leaderboard user portfolio endpoint
app.get('/api/leaderboard/:type/user/:userId', async (req, res) => {
  console.log(`👤 Mobile API: Leaderboard user portfolio request type=${req.params.type} user=${req.params.userId}`);
  try {
    const result = await proxyToMainApp(`/api/leaderboards/${req.params.type}/user/${req.params.userId}`, {
      method: 'GET'
    });
    console.log('➡️  Forwarded to /api/leaderboards/:type/user, status:', result.status);
    res.status(result.status).json(result.data);
  } catch (error) {
    console.error('❌ Leaderboard user proxy error:', error.message);
    res.status(500).json({
      success: false,
      error: 'User portfolio fetch failed: ' + error.message
    });
  }
});

// Health check
app.get('/api/health', async (req, res) => {
  console.log('🏥 Mobile API: Health check');
  
  try {
    // Test connection to main app using a real endpoint
    const result = await proxyToMainApp('/api/mobile/stocks/ftse100');
    
    res.json({
      success: true,
      message: 'Mobile API Server is healthy',
      mainAppConnection: result.status === 200,
      mainAppUrl: MAIN_APP_URL,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Mobile API Server is unhealthy',
      mainAppConnection: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Test endpoint
app.get('/api/test', (req, res) => {
  res.json({
    success: true,
    message: 'Mobile API Server is working',
    timestamp: new Date().toISOString()
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Server Error:', err);
  res.status(500).json({
    success: false,
    error: err.message || 'Internal server error'
  });
});

// Global error handlers for uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught Exception:', err);
  // Don't exit the process
});

process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled Promise Rejection:', err);
  // Don't exit the process
});

// Start server
console.log('🚀 Starting Mobile API Server...');

// Server error handling
function handleServerError(err) {
  console.error('❌ Server Error:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`⚠️ Port ${PORT} is already in use. Please close the other program using this port or choose a different port.`);
    process.exit(1);
  } else if (err.code === 'EACCES') {
    console.error(`⚠️ Permission denied to bind to port ${PORT}. Try using a port number above 1024 or run with sudo.`);
    process.exit(1);
  } else {
    console.error('Server error details:', err.stack);
  }
}

// Connection handling
function handleConnection(socket) {
  console.log('🔌 New client connected');
  
  socket.on('error', (err) => {
    console.error('Socket error:', err);
  });
  
  socket.on('close', () => {
    console.log('Client connection closed');
  });
}

// Create HTTP server with timeout handling
const server = app.listen(PORT, () => {
  // Set keep-alive timeout to 65 seconds for all server connections
  server.keepAliveTimeout = 65000;
  // Set headers timeout higher than keep-alive timeout
  server.headersTimeout = 66000;
  console.log(`🚀 Mobile API Server running on http://localhost:${PORT}`);
  console.log(`📡 Proxying requests to ${MAIN_APP_URL}`);
  console.log(`🔗 Mobile app should use: http://localhost:${PORT}/api as base URL`);
  console.log('');
  console.log('📋 Available endpoints:');
  console.log(`  Health: http://localhost:${PORT}/api/health`);
  console.log(`  Test: http://localhost:${PORT}/api/test`);
  console.log(`  Login: http://localhost:${PORT}/api/auth/login`);
  console.log(`  Portfolio: http://localhost:${PORT}/api/portfolio/default`);
  console.log(`  Trades: http://localhost:${PORT}/api/trades/default`);
  console.log('');
  console.log('✨ Server is ready to handle requests!');
}).on('error', handleServerError);