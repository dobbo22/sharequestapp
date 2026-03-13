// Simple proxy server to forward API requests from mobile app to main app
// This avoids CORS issues by running on the same origin as the mobile app

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 8082; // Different port to avoid conflicts

// Enable CORS for all requests
app.use(cors({
  origin: ['http://localhost:8081', 'http://localhost:8082'],
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'X-Requested-With']
}));

// Proxy configuration
const proxyOptions = {
  target: 'http://localhost:3000', // Main app server
  changeOrigin: true,
  pathRewrite: {
    '^/api': '/api', // Keep the /api path
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`🔄 Proxying: ${req.method} ${req.url} -> http://localhost:3000${req.url}`);
    console.log(`   Headers:`, req.headers);
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`✅ Response: ${proxyRes.statusCode} for ${req.method} ${req.url}`);
    console.log(`   Response Headers:`, proxyRes.headers);
    console.log(`   Content-Type: ${proxyRes.headers['content-type']}`);
  },
  onError: (err, req, res) => {
    console.error(`❌ Proxy error for ${req.method} ${req.url}:`, err.message);
    res.status(500).json({
      success: false,
      error: 'Proxy server error: ' + err.message
    });
  }
};

// Create proxy middleware
const apiProxy = createProxyMiddleware(proxyOptions);

// Add logging middleware to see what requests are coming in
app.use('/api', (req, res, next) => {
  console.log(`📥 Received API request: ${req.method} ${req.path}`);
  next();
});

// Use the proxy middleware
app.use('/api', apiProxy);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Mobile app proxy server is running',
    target: 'http://localhost:3000',
    timestamp: new Date().toISOString()
  });
});

// Start the proxy server
app.listen(PORT, () => {
  console.log(`🚀 Mobile App Proxy Server running on http://localhost:${PORT}`);
  console.log(`📡 Forwarding requests to http://localhost:3000`);
  console.log(`🔗 Mobile app should use http://localhost:${PORT}/api as base URL`);
  console.log('');
  console.log('Test endpoints:');
  console.log(`  Health: http://localhost:${PORT}/health`);
  console.log(`  API Test: http://localhost:${PORT}/api/test`);
  console.log(`  Login: http://localhost:${PORT}/api/mobile/auth/login`);
});