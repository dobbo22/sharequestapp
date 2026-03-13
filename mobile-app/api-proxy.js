// API Proxy Server for Mobile App - runs on same port as mobile app
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const path = require('path');

const app = express();
const PORT = 8084; // Different port from mobile app
const TARGET = 'http://localhost:3000';

// Enable CORS for same-origin requests
app.use(cors({
  origin: ['http://localhost:8081', 'http://localhost:8084'],
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'X-Requested-With']
}));

app.use(express.json());
app.use(express.text());
app.use(express.urlencoded({ extended: true }));

// Serve static files from mobile app (if needed)
app.use(express.static(path.join(__dirname, 'web-build')));

// API forwarding middleware
app.use('/api', async (req, res) => {
  const apiPath = req.path; // This will be /test, /mobile/auth/login, etc. (after /api)
  const targetUrl = `${TARGET}/api${apiPath}`;
  
  console.log(`🔄 [${new Date().toLocaleTimeString()}] ${req.method} ${req.originalUrl} -> ${targetUrl}`);
  
  try {
    const headers = {
      'Content-Type': req.headers['content-type'] || 'application/json',
      'User-Agent': 'Mobile-App-Server/1.0'
    };
    
    // Copy relevant headers from original request
    if (req.headers.authorization) {
      headers.Authorization = req.headers.authorization;
    }
    if (req.headers['x-user-id']) {
      headers['x-user-id'] = req.headers['x-user-id'];
    }
    
    const options = {
      method: req.method,
      headers: headers
    };
    
    // Add body for POST/PUT requests
    if (['POST', 'PUT', 'PATCH'].includes(req.method) && req.body) {
      if (typeof req.body === 'string') {
        options.body = req.body;
      } else {
        options.body = JSON.stringify(req.body);
      }
    }
    
    console.log(`   📤 Request body: ${options.body || 'None'}`);
    
    // Make the request to the main app
    const response = await fetch(targetUrl, options);
    const responseText = await response.text();
    
    console.log(`   📥 Response: ${response.status} ${response.statusText}`);
    console.log(`   📄 Response body: ${responseText.substring(0, 200)}${responseText.length > 200 ? '...' : ''}`);
    
    // Set response status and headers
    res.status(response.status);
    
    // Copy important headers
    if (response.headers.get('content-type')) {
      res.setHeader('content-type', response.headers.get('content-type'));
    }
    
    // Send the response
    if (response.headers.get('content-type')?.includes('application/json')) {
      try {
        const jsonData = JSON.parse(responseText);
        res.json(jsonData);
      } catch (parseError) {
        res.send(responseText);
      }
    } else {
      res.send(responseText);
    }
    
  } catch (error) {
    console.error(`❌ Proxy error:`, error.message);
    res.status(500).json({
      success: false,
      error: 'API proxy error: ' + error.message,
      target: targetUrl
    });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Mobile API proxy is running',
    target: TARGET,
    timestamp: new Date().toISOString()
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Mobile API Proxy running on http://localhost:${PORT}`);
  console.log(`📡 Forwarding /api/* requests to ${TARGET}`);
  console.log(`🔗 Mobile app should use: http://localhost:${PORT}/api`);
  console.log('');
  console.log('Test endpoints:');
  console.log(`  Health: http://localhost:${PORT}/health`);
  console.log(`  API Test: http://localhost:${PORT}/api/test`);
  console.log(`  Login: http://localhost:${PORT}/api/mobile/auth/login`);
});