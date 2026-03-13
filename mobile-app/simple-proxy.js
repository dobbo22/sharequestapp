// Simple manual proxy server to forward API requests from mobile app to main app
const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = 8082;
const TARGET = 'http://localhost:3000';

// Enable CORS and JSON parsing - be very permissive for development
app.use(cors({
  origin: true, // Allow all origins
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'X-Requested-With', 'Accept', 'Origin'],
  optionsSuccessStatus: 200 // Some legacy browsers choke on 204
}));

app.use(express.json());
app.use(express.text());

// Manual proxy for API requests
app.use('/api', async (req, res) => {
  // req.path when mounted on /api will be the remaining path after /api
  // e.g., /api/test -> req.path = '/test'
  const targetUrl = `${TARGET}/api${req.path}`;
  console.log(`🔄 Proxying: ${req.method} ${req.originalUrl} -> ${targetUrl}`);
  console.log(`   Original URL: ${req.originalUrl}, Path: ${req.path}`);
  
  try {
    // Prepare headers
    const headers = {
      'Content-Type': req.headers['content-type'] || 'application/json',
      'User-Agent': 'Mobile-App-Proxy/1.0',
    };
    
    // Copy relevant headers
    if (req.headers.authorization) {
      headers.Authorization = req.headers.authorization;
    }
    if (req.headers['x-user-id']) {
      headers['x-user-id'] = req.headers['x-user-id'];
    }
    
    console.log(`   Headers:`, headers);
    
    // Prepare fetch options
    const fetchOptions = {
      method: req.method,
      headers: headers,
    };
    
    // Add body for POST/PUT requests
    if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
      if (typeof req.body === 'string') {
        fetchOptions.body = req.body;
      } else {
        fetchOptions.body = JSON.stringify(req.body);
      }
      console.log(`   Body:`, fetchOptions.body);
    }
    
    // Make request to target
    const response = await fetch(targetUrl, fetchOptions);
    const responseText = await response.text();
    
    console.log(`✅ Response: ${response.status} ${response.statusText}`);
    console.log(`   Content-Type: ${response.headers.get('content-type')}`);
    console.log(`   Body preview: ${responseText.substring(0, 200)}...`);
    
    // Copy response headers
    const responseHeaders = {};
    for (const [key, value] of response.headers) {
      responseHeaders[key] = value;
    }
    
    // Set status and headers
    res.status(response.status);
    Object.keys(responseHeaders).forEach(key => {
      res.setHeader(key, responseHeaders[key]);
    });
    
    // Send response
    if (response.headers.get('content-type')?.includes('application/json')) {
      try {
        const jsonData = JSON.parse(responseText);
        res.json(jsonData);
      } catch (parseError) {
        console.log(`   JSON parse error, sending as text`);
        res.send(responseText);
      }
    } else {
      res.send(responseText);
    }
    
  } catch (error) {
    console.error(`❌ Proxy error:`, error.message);
    res.status(500).json({
      success: false,
      error: 'Proxy server error: ' + error.message
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Simple proxy server is running',
    target: TARGET,
    timestamp: new Date().toISOString()
  });
});

// Start the proxy server
app.listen(PORT, () => {
  console.log(`🚀 Simple Proxy Server running on http://localhost:${PORT}`);
  console.log(`📡 Forwarding requests to ${TARGET}`);
  console.log(`🔗 Mobile app should use http://localhost:${PORT}/api as base URL`);
  console.log('');
  console.log('Test endpoints:');
  console.log(`  Health: http://localhost:${PORT}/health`);
  console.log(`  API Test: http://localhost:${PORT}/api/test`);
  console.log(`  Login: http://localhost:${PORT}/api/mobile/auth/login`);
});