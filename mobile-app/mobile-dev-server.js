// Mobile Development Server with Built-in API Proxy
// This eliminates CORS issues by serving both the mobile app AND API from the same origin

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = 8085; // New unified port
const API_TARGET = 'http://localhost:3000';

console.log('🚀 Starting Mobile Development Server with API Proxy...');

// Enable CORS for development
app.use(cors({
  origin: true,
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-user-id', 'X-Requested-With', 'Accept', 'Origin']
}));

// Parse JSON and text bodies
app.use(express.json());
app.use(express.text());

// API Proxy - Forward all /api requests to the main app
const apiProxy = createProxyMiddleware({
  target: API_TARGET,
  changeOrigin: true,
  logLevel: 'info',
  onProxyReq: (proxyReq, req, res) => {
    const timestamp = new Date().toLocaleTimeString();
    console.log(`🔄 [${timestamp}] API Proxy: ${req.method} ${req.path} -> ${API_TARGET}${req.path}`);
  },
  onProxyRes: (proxyRes, req, res) => {
    console.log(`✅ API Response: ${proxyRes.statusCode} for ${req.method} ${req.path}`);
  },
  onError: (err, req, res) => {
    console.error(`❌ API Proxy Error for ${req.method} ${req.path}:`, err.message);
    res.status(500).json({
      success: false,
      error: 'API proxy error: ' + err.message,
      target: API_TARGET
    });
  }
});

// Mount the API proxy
app.use('/api', apiProxy);

// Serve static files (for built mobile app)
const staticPath = path.join(__dirname, 'web-build');
app.use(express.static(staticPath));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Mobile Development Server with API Proxy',
    apiTarget: API_TARGET,
    staticPath: staticPath,
    timestamp: new Date().toISOString()
  });
});

// Serve mobile app for all other routes (SPA support)
app.get('/', (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  res.sendFile(indexPath, (err) => {
    if (err) {
      console.error('Error serving index.html:', err);
      res.status(404).send('Mobile app not built. Run: npx expo export --platform web');
    }
  });
});

// Handle specific mobile app routes
app.get(['/dashboard', '/portfolio', '/stocks', '/leaderboards', '/community', '/profile'], (req, res) => {
  const indexPath = path.join(staticPath, 'index.html');
  res.sendFile(indexPath);
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Mobile Development Server running on http://localhost:${PORT}`);
  console.log(`📱 Mobile App: http://localhost:${PORT}`);
  console.log(`🔌 API Proxy: http://localhost:${PORT}/api -> ${API_TARGET}/api`);
  console.log(`🏥 Health Check: http://localhost:${PORT}/health`);
  console.log('');
  console.log('📋 Instructions:');
  console.log('  1. Build mobile app: npm run build:web');
  console.log('  2. Open browser: http://localhost:8085');
  console.log('  3. No more CORS issues! 🎉');
  console.log('');
  console.log('🧪 Test API:');
  console.log(`  curl http://localhost:${PORT}/api/test`);
  console.log(`  curl http://localhost:${PORT}/health`);
});