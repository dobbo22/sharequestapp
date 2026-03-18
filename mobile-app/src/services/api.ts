// API service for mobile app - connects to mobile API server
import { ApiResponse } from '../types';
import { localBackend } from './local-backend';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

// Declare React Native's __DEV__ global for TypeScript in non-RN tooling
declare const __DEV__: boolean;

class ApiService {
  private baseUrl: string;
  private token: string | null = null;
  private localMode: boolean;
  private static LOCAL_MODE_KEY = 'local_mode_enabled';

  constructor() {
    // Log environment variable for debugging
    console.log('🔍 EXPO_PUBLIC_API_URL at runtime:', process.env.EXPO_PUBLIC_API_URL);
    this.baseUrl = this.getApiUrl();
    this.localMode = (process.env.EXPO_PUBLIC_LOCAL_MODE === '1'); // initial default
    console.log('📱 API Service initialized with baseUrl:', this.baseUrl);
    if (this.localMode) {
      console.log('🛠  Local mode ENABLED – mobile app running independent backend');
    }
    // Load token asynchronously - don't await in constructor
    this.loadToken().then(() => {
      // Auto-clear old offline tokens to force real API usage
      if (this.token && this.token.startsWith('dev-token-bina')) {
        console.log('🧹 Clearing old offline token to force real API usage...');
        this.clearToken();
      }
    }).catch(error => console.error('Failed to load token:', error));

    // Load persisted local mode preference
    this.loadLocalModePreference().catch(err => console.warn('Local mode preference load failed:', err));
  }

  private async loadLocalModePreference() {
    try {
      const stored = await AsyncStorage.getItem(ApiService.LOCAL_MODE_KEY);
      if (stored === '1' || stored === '0') {
        const desired = stored === '1';
        if (desired !== this.localMode) {
          console.log('🔁 Applying persisted local mode preference:', desired);
          this.localMode = desired;
        }
      }
    } catch (e) {
      // Non-fatal
    }
  }

  async setLocalMode(enabled: boolean) {
    if (enabled === this.localMode) return;
    console.log('🔄 Switching local mode ->', enabled);
    this.localMode = enabled;
    try { await AsyncStorage.setItem(ApiService.LOCAL_MODE_KEY, enabled ? '1' : '0'); } catch {}
    // Clear token to avoid mixing remote & local auth contexts
    await this.clearToken();
  }

  isLocalMode() { return this.localMode; }

  private getApiUrl(): string {
    // 1. In production (non-dev), use EXPO_PUBLIC_API_URL directly
    if (!__DEV__ && process.env.EXPO_PUBLIC_API_URL) {
      const normalized = this.normalizeBaseUrl(process.env.EXPO_PUBLIC_API_URL);
      // Safety: prevent accidental production config that points to localhost
      if (normalized.includes('localhost') || normalized.includes('127.0.0.1')) {
        console.error(`ERROR: EXPO_PUBLIC_API_URL is configured as ${process.env.EXPO_PUBLIC_API_URL} which points to localhost. In production this must point to the remote API URL (e.g. https://sharequest.example.com/api).`);
        throw new Error('Invalid EXPO_PUBLIC_API_URL in production - points to localhost');
      }
      console.log('🌐 Using production API URL:', normalized);
      return normalized;
    }

    // 2. In dev mode, allow simulator/device URL switching
    let rawEnv = process.env.EXPO_PUBLIC_API_URL || process.env.API_BASE_URL;

    if (Platform.OS === 'ios') {
      if (!Platform.isPad && !Platform.isTVOS && typeof navigator !== 'undefined' && navigator.product === 'ReactNative') {
        rawEnv = process.env.EXPO_PUBLIC_API_URL_SIM || rawEnv;
      } else {
        rawEnv = process.env.EXPO_PUBLIC_API_URL_DEVICE || rawEnv;
      }
    } else if (Platform.OS === 'android') {
      if (typeof navigator !== 'undefined' && navigator.product === 'ReactNative') {
        rawEnv = process.env.EXPO_PUBLIC_API_URL_SIM || 'http://10.0.2.2:3000/api';
      } else {
        rawEnv = process.env.EXPO_PUBLIC_API_URL_DEVICE || rawEnv;
      }
    }

    if (rawEnv) {
      const normalized = this.normalizeBaseUrl(rawEnv);
      console.log('🌐 Using environment API URL:', normalized);
      return normalized;
    }

    // 3. Development heuristics (prefer mobile proxy if running)
    if (__DEV__) {
      const devProxy = 'http://localhost:8082/api';
      console.log('🛠  Dev mode defaulting to proxy URL:', devProxy);
      return devProxy;
    }

    // 4. Fallback to production
    const fallback = 'https://www.sharequest.co.uk/api';
    console.log('🌐 Using fallback URL:', fallback);
    return fallback;
  }

  private normalizeBaseUrl(url: string): string {
    let u = url.trim();
    // Remove trailing slash
    if (u.endsWith('/')) u = u.slice(0, -1);
    // Ensure it ends with /api or /api/vX pattern; if not and doesn't have /api already, append /api
    if (!/\/api(\/|$)/.test(u)) {
      u = u + '/api';
    }
    return u;
  }

  // Allow runtime override (e.g., switch to test API from settings screen)
  setBaseUrl(url: string) {
    const old = this.baseUrl;
    this.baseUrl = this.normalizeBaseUrl(url);
    console.log('🔄 Base URL overridden:', { from: old, to: this.baseUrl });
  }

  private async loadToken() {
    try {
      const token = await AsyncStorage.getItem('auth_token');
      this.token = token;
      console.log('🔑 Token loaded:', this.token ? 'Present' : 'Not found');
    } catch (error) {
      console.error('Error loading token:', error);
    }
  }

  private async ensureTokenLoaded() {
    if (this.token === null) {
      await this.loadToken();
    }
  }

  private async saveToken(token: string) {
    try {
      await AsyncStorage.setItem('auth_token', token);
      this.token = token;
    } catch (error) {
      console.error('Error saving token:', error);
    }
  }

  private async clearToken() {
    try {
      await AsyncStorage.removeItem('auth_token');
      this.token = null;
    } catch (error) {
      console.error('Error clearing token:', error);
    }
  }

  // Public request method for direct API calls
  async request<T = any>(
    endpoint: string,
  options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    // Always use real API requests through mobile API server or direct connection
    return this.privateRequest<T>(endpoint, options);
  }

  // Check if we're in offline development mode
  isOfflineMode(): boolean {
    return __DEV__ && this.token !== null && this.token.startsWith('dev-token-');
  }

  // Handle requests in offline development mode
  private async handleOfflineModeRequest<T = any>(endpoint: string, options: RequestInit): Promise<ApiResponse<T>> {
    console.log('🔌 Offline mode request:', endpoint);
    
    // Add small delay to simulate network request
    await new Promise(resolve => setTimeout(resolve, 100 + Math.random() * 200));
    
    // Mock responses for common endpoints
    if (endpoint === '/subscriptions' || endpoint === '/mobile/subscriptions') {
      return {
        success: true,
        data: {
          subscriptions: {
            weekly: false,
            monthly: false,
            annual: false,
            default: true
          }
        } as T
      } as ApiResponse<T>;
    }
    
    if (endpoint.startsWith('/stocks/ftse100')) {
      return {
        success: true,
        data: {
          stocks: [
            {
              symbol: "AZN.L",
              company_name: "AstraZeneca PLC",
              companyname: "AstraZeneca PLC",
              sector: "Pharmaceuticals",
              current_price: 11942,
              price: 11942,
              change_amount: 160,
              change: 160,
              change_percent: 1.36,
              changePercent: 1.36,
              market_cap: 171615879168,
              marketCap: 171615879168,
              volume: 13561,
              currency: "GBX"
            },
            {
              symbol: "HSBA.L",
              company_name: "HSBC Holdings plc",
              companyname: "HSBC Holdings plc",
              sector: "Banks",
              current_price: 948,
              price: 948,
              change_amount: 9,
              change: 9,
              change_percent: 0.96,
              changePercent: 0.96,
              market_cap: 164854988800,
              marketCap: 164854988800,
              volume: 139780,
              currency: "GBX"
            }
          ]
        } as T
      } as ApiResponse<T>;
    }
    
    if (endpoint.startsWith('/stocks/top100') || endpoint.startsWith('/stocks/ftse250') || endpoint.startsWith('/stocks/top250')) {
      return {
        success: true,
        data: {
          stocks: [
            {
              symbol: "VOD.L",
              company_name: "Vodafone Group Plc",
              companyname: "Vodafone Group Plc",
              sector: "Telecommunications",
              current_price: 75,
              price: 75,
              change_amount: -2,
              change: -2,
              change_percent: -2.6,
              changePercent: -2.6,
              market_cap: 25000000000,
              marketCap: 25000000000,
              volume: 98432,
              currency: "GBX"
            }
          ]
        } as T
      } as ApiResponse<T>;
    }

    if (endpoint.startsWith('/portfolio') || endpoint.startsWith('/mobile/portfolio')) {
      return {
        success: true,
        data: {
          portfolio: {
            id: 'default-portfolio-bina',
            user_id: 'Bina',
            portfolio_type: 'default',
            cash_balance: '10000000', // £100,000 in pence
            total_value: '10000000',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
          },
          holdings: []
        }
  } as ApiResponse<T>;
    }

    if (endpoint.startsWith('/trades')) {
      return {
        success: true,
        data: {
          trades: [
            {
              id: 'trade-1',
              symbol: 'AZN.L',
              company_name: 'AstraZeneca PLC',
              companyname: 'AstraZeneca PLC',
              quantity: 10,
              price: 11942,
              action: 'buy',
              timestamp: new Date().toISOString(),
              total_value: 119420
            },
            {
              id: 'trade-2',
              symbol: 'HSBA.L',
              company_name: 'HSBC Holdings plc',
              companyname: 'HSBC Holdings plc',
              quantity: 50,
              price: 948,
              action: 'sell',
              timestamp: new Date(Date.now() - 60000).toISOString(),
              total_value: 47400
            },
            {
              id: 'trade-3',
              symbol: 'VOD.L',
              company_name: 'Vodafone Group Plc',
              companyname: 'Vodafone Group Plc',
              quantity: 25,
              price: 75,
              action: 'buy',
              timestamp: new Date(Date.now() - 120000).toISOString(),
              total_value: 1875
            }
          ]
        } as T
      } as ApiResponse<T>;
    }

    if (endpoint.startsWith('/leaderboards') || endpoint.startsWith('/leaderboard')) {
      // Basic leaderboard list
      if (!endpoint.includes('/user/')) {
  return {
          success: true,
          data: {
            leaderboard: [
              {
                rank: 1,
                user_id: 'Bina',
                username: 'Bina',
                total_portfolio_value: 10125000, // pence
                profit_loss: 125000, // pence
                profit_loss_percent: 1.25,
                cash_balance: 9875000
              },
              {
                rank: 2,
                user_id: 'Alex',
                username: 'Alex',
                total_portfolio_value: 10050000,
                profit_loss: 50000,
                profit_loss_percent: 0.5,
                cash_balance: 9950000
              }
            ],
            totalParticipants: 2,
            competition: {
              status: 'active',
              start_date: new Date(Date.now() - 3*24*3600*1000).toISOString(),
              end_date: new Date(Date.now() + 4*24*3600*1000).toISOString(),
              prize_pool: 100,
              time_remaining: '4d 0h'
            }
          } as T
        } as ApiResponse<T>;
      }

      // User portfolio view within leaderboard
      return {
        success: true,
        data: {
          rank: 1,
          cash_balance: 9875000,
          holdings: [
            { symbol: 'AZN.L', company_name: 'AstraZeneca PLC', quantity: 10, average_price: 11942, current_price: 12100 },
            { symbol: 'HSBA.L', company_name: 'HSBC Holdings plc', quantity: 50, average_price: 948, current_price: 960 }
          ]
        } as T
      } as ApiResponse<T>;
    }
    
    // Default mock response
  return {
      success: true,
      data: {} as T
  } as ApiResponse<T>;
  }

  private async privateRequest<T = any>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseUrl}${endpoint}`;
    console.log('🌐 Making API request to:', url);

    // Ensure token is loaded before making request
    await this.ensureTokenLoaded();

    // If in offline mode, return mock response
    if (this.isOfflineMode()) {
      console.log('🔌 Using offline mock for:', endpoint);
      return this.handleOfflineModeRequest<T>(endpoint, options);
    }

    // Get user info from storage to set x-user-id header
    let userId = 'Penfold'; // Default fallback
    try {
      const userDataStr = await AsyncStorage.getItem('user_data');
      if (userDataStr) {
        const userData = JSON.parse(userDataStr);
        userId = userData.username || userData.id || userId;
        console.log('🔑 Using authenticated user:', userId);
      }
    } catch (err) {
      console.warn('⚠️  Could not load user data from storage, using fallback');
    }

    // Normalize and merge headers safely into a plain object
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'x-user-id': userId,
    };

    const incoming = options.headers as any;
    if (incoming) {
      // Convert to a plain Record<string,string>
      if (typeof incoming.forEach === 'function' && typeof incoming.entries === 'function') {
        // Headers-like
        incoming.forEach((value: string, key: string) => {
          headers[key] = String(value);
        });
      } else if (Array.isArray(incoming)) {
        (incoming as Array<[string, string]>).forEach(([key, value]) => {
          headers[key] = String(value);
        });
      } else {
        Object.assign(headers, incoming as Record<string, string>);
      }
    }

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
      console.log('🔑 Sending request with token');
    } else {
      console.log('⚠️  No token available, using user ID header for Bina');
    }

    try {
      console.log('🚀 Starting fetch request to:', url);
      console.log('📋 Request headers:', headers);
      console.log('⚙️  Request options:', options);
      
      // Add timeout to prevent hanging - increased to 10 seconds to prevent AbortError
      const controller = new AbortController();
      const timeoutId = setTimeout(() => {
        console.log('⏰ Request timeout after 10 seconds');
        controller.abort();
      }, 10000);

      // For React Native Web, we need to be more careful with fetch options
      const fetchOptions = {
        ...options,
        headers,
        signal: controller.signal,
        // Remove mode for React Native Web compatibility
        // mode: 'cors',
        credentials: 'omit',
      } as RequestInit;
      
      console.log('🌐 Making fetch request to:', url);
      console.log('🌐 Fetch options:', JSON.stringify(fetchOptions, null, 2));
      console.log('🌐 Platform:', Platform.OS);
      
      const response = await fetch(url, fetchOptions);
      console.log('🌐 Fetch completed successfully!');
      console.log('📡 Response status:', response.status);
      console.log('📡 Response statusText:', response.statusText);
      console.log('📡 Response headers:', Object.fromEntries(response.headers.entries()));

      clearTimeout(timeoutId);

      // Try to parse JSON, fallback to empty object
      let data: any = null;
      try {
        data = await response.json();
      } catch (e) {
        data = null;
      }

      if (!response.ok) {
        console.error('❌ API Error:', response.status, data);
        return {
          success: false,
          error: data?.message || data?.error || `HTTP ${response.status}: ${response.statusText}`,
        };
      }

      console.log('✅ API Success:', data);
      return {
        success: true,
        data: (data && (data.data ?? data)) as T,
      };
    } catch (error) {
      console.error('❌ API request failed:', error);
      
      let errorMessage = 'Network error';
      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          errorMessage = 'Request timed out. Please try again.';
        } else if (error.message.includes('Network request failed') || error.message.includes('Failed to fetch')) {
          errorMessage = `Unable to connect to ${this.baseUrl}. Please check if the main app is running and accessible.`;
        } else {
          errorMessage = error.message;
        }
      }
      
      return {
        success: false,
        error: errorMessage,
      };
    }
  }

  // Method to try alternative API URLs
  private async tryAlternativeUrls(): Promise<string | null> {
    const alternatives = [
      'http://127.0.0.1:3000/api',
      'http://localhost:3000/api',
      'http://192.168.1.213:3000/api',
      'http://10.0.2.2:3000/api' // Android emulator host
    ];

    for (const url of alternatives) {
      if (url === this.baseUrl) continue; // Skip current URL
      
      console.log('🔄 Trying alternative URL:', url);
      try {
        // Test with the test endpoint first, then mobile login
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 8000);
        
        let response = await fetch(`${url}/test`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
          },
          signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        
        if (response.ok) {
          console.log('✅ Alternative URL test endpoint works:', url);
          
          // Double-check with mobile login endpoint
          const loginController = new AbortController();
          const loginTimeoutId = setTimeout(() => loginController.abort(), 8000);
          
          response = await fetch(`${url}/mobile/auth/login`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ email: 'Bina', password: 'test' }),
            signal: loginController.signal
          });
          
          clearTimeout(loginTimeoutId);
          
          if (response.ok) {
            console.log('✅ Alternative URL mobile login works:', url);
            return url;
          } else {
            console.log('⚠️  Alternative URL test works but mobile login failed:', url, response.status);
            // Still return it since test endpoint works
            return url;
          }
        }
      } catch (err) {
        console.log('❌ Alternative URL failed:', url, (err as Error).message);
      }
    }
    
    return null;
  }

  // Connection test method (public)
  async testConnection(): Promise<ApiResponse<any>> {
    console.log('🧪 Testing API connection to:', this.baseUrl);
    
    // For development debugging, let's be very explicit about what we're doing
    try {
      // Force use of real API, not offline mode
      const wasOffline = this.isOfflineMode();
      if (wasOffline) {
        console.log('🔄 Temporarily disabling offline mode for connection test');
        const originalToken = this.token;
        this.token = null; // Temporarily clear to force real API usage
        
        try {
          const result = await this.privateRequest('/test', { method: 'GET' });
          this.token = originalToken; // Restore token
          
          if (result.success) {
            console.log('✅ Real API connection successful!');
            return result;
          }
          
          console.log('❌ Real API failed:', result.error);
        } catch (testError) {
          this.token = originalToken; // Restore token on error
          console.error('❌ Real API test failed:', testError);
          throw testError;
        }
      } else {
        // Direct test when not in offline mode
        const result = await this.privateRequest('/test', { method: 'GET' });
        
        if (result.success) {
          console.log('✅ API connection successful');
          return result;
        }
        
        console.log('❌ API test failed:', result.error);
        throw new Error(result.error || 'Connection failed');
      }
      
      // Try alternative URLs if direct connection failed
      console.log('🔄 Testing alternative URLs...');
      const alternativeUrl = await this.tryAlternativeUrls();
      if (alternativeUrl) {
        console.log('🔄 Switching to working URL:', alternativeUrl);
        this.baseUrl = alternativeUrl;
        
        // Test again with new URL
        const retryResult = await this.privateRequest('/test', { method: 'GET' });
        if (retryResult.success) {
          console.log('✅ Alternative URL works!');
          return retryResult;
        }
      }
      
      // Provide detailed debugging information
      console.log('🔍 Connection test failed - Debug info:');
      console.log('  - Base URL:', this.baseUrl);
      console.log('  - Platform:', Platform.OS);
      console.log('  - Is development?', __DEV__);
      console.log('  - Was offline mode?', wasOffline);
      console.log('  - Token present?', !!this.token);
      console.log('  - Current timestamp:', new Date().toISOString());
      
      throw new Error('All connection attempts failed');
    } catch (error) {
      console.error('🚫 Connection test completely failed:', error);
      throw error;
    }
  }

  // Authentication methods
  async login(email: string, password: string): Promise<ApiResponse<{ token: string; user: any }>> {
    console.log('🔐 Attempting login for:', email);
    console.log('🔍 Current API base URL:', this.baseUrl, 'localMode:', this.localMode);

    if (this.localMode) {
      try {
        const result = await localBackend.login(email, password);
        await this.saveToken(result.token);
        return { success: true, data: { token: result.token, user: result.user } };
      } catch (e) {
        return { success: false, error: (e as Error).message };
      }
    }
    
    // No more offline mode - always use real API through mobile API server
    
    // Clear any existing offline tokens to force real API usage
    if (this.token && this.token.startsWith('dev-token-')) {
      console.log('🧹 Clearing offline token to force real API usage');
      await this.clearToken();
    }
    
    // First, let's test the connection explicitly
    console.log('🧪 Testing connection before login attempt...');
    try {
      const connectionTest = await this.testConnection();
      if (!connectionTest.success) {
        console.error('❌ Connection test failed before login');
        throw new Error('Cannot connect to API server');
      }
      console.log('✅ Connection test passed, proceeding with login');
    } catch (connError) {
      console.error('❌ Connection test error:', connError);
      // Don't return here, still try login in case test is wrong
    }
    
    // Try real API login first
    console.log('🚀 Attempting real API login to /mobile/auth/login...');
    
    const response = await this.privateRequest<{ token: string; user: any }>('/mobile/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });

    if (response.success && response.data?.token) {
      await this.saveToken(response.data.token);
      // Save user data to AsyncStorage for x-user-id header
      if (response.data.user) {
        try {
          await AsyncStorage.setItem('user_data', JSON.stringify(response.data.user));
          console.log('✅ User data saved to storage:', response.data.user.username || response.data.user.id);
        } catch (err) {
          console.error('❌ Failed to save user data to storage:', err);
        }
      }
      console.log('✅ Real API login successful, token saved');
      return response;
    } else {
      console.error('❌ Real API login failed:', response.error);
      
      // If login fails, this is likely a real API connectivity issue
      // Let's provide detailed debugging info
      console.log('🔍 Login failure debug info:');
      console.log('  - API URL:', this.baseUrl);
      console.log('  - Endpoint:', '/mobile/auth/login');
      console.log('  - Error:', response.error);
      console.log('  - Success flag:', response.success);
      
      // Only fall back to offline mode if explicitly requested in development
      if (__DEV__ && email === 'offline') {
        console.log('🧪 Special offline user detected - using offline mode');
        
        const mockToken = 'dev-token-' + email + '-' + Date.now();
        await this.saveToken(mockToken);
        
        return {
          success: true,
          data: {
            token: mockToken,
            user: {
              id: email,
              username: email,
              email: email,
              first_name: email,
              last_name: 'User',
              isAdmin: false
            }
          }
        };
      }
    }

    // Return the actual API response (whether success or failure)
    return response;
  }

  async register(email: string, username: string, password: string, additionalData?: any): Promise<ApiResponse<{ token: string; user: any }>> {
    const registrationData = {
      email,
      username,
      password,
      ...additionalData
    };

    const response = await this.privateRequest<{ token: string; user: any }>('/mobile/auth/register', {
      method: 'POST',
      body: JSON.stringify(registrationData),
    });

    if (response.success && response.data?.token) {
      await this.saveToken(response.data.token);
      // Save user data to AsyncStorage for x-user-id header
      if (response.data.user) {
        try {
          await AsyncStorage.setItem('user_data', JSON.stringify(response.data.user));
          console.log('✅ User data saved to storage:', response.data.user.username || response.data.user.id);
        } catch (err) {
          console.error('❌ Failed to save user data to storage:', err);
        }
      }
    }

    return response;
  }

  async logout(): Promise<void> {
    await this.clearToken();
    // Clear user data on logout
    try {
      await AsyncStorage.removeItem('user_data');
    } catch (err) {
      console.error('❌ Failed to clear user data from storage:', err);
    }
  }

  async getProfile(): Promise<ApiResponse<any>> {
    if (this.localMode) {
      if (!this.token) return { success: false, error: 'Not logged in' };
      const userId = (this.token.split('-')[2]) || 'bina';
      const user = await localBackend.me(userId);
      return user ? { success: true, data: user } : { success: false, error: 'User not found' };
    }
    return this.privateRequest<any>('/mobile/auth/me');
  }

  // Stock methods
  async searchStocks(query: string): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams({ q: query });
    return this.privateRequest<any[]>(`/mobile/stocks/search?${params}`);
  }

  async getTop100(limit: number = 100): Promise<ApiResponse<any[]>> {
    // Use mobile FTSE100 endpoint (Top 100 UK stocks)
    const response = await this.privateRequest<any>(`/mobile/stocks/ftse100?limit=${limit}`);
    if (response.success && response.data) {
      // Transform to match expected format
      return {
        success: true,
        data: response.data.stocks || response.data
      };
    }
    return response;
  }

  async getFTSE100(limit: number = 100): Promise<ApiResponse<any[]>> {
    const response = await this.privateRequest<any>(`/mobile/stocks/ftse100?limit=${limit}`);
    if (response.success && response.data) {
      // Transform to match expected format
      return {
        success: true,
        data: response.data.stocks || response.data
      };
    }
    return response;
  }

  async getFTSE250(limit: number = 250): Promise<ApiResponse<any[]>> {
    const response = await this.privateRequest<any>(`/mobile/stocks/ftse250?limit=${limit}`);
    if (response.success && response.data) {
      // Transform to match expected format
      return {
        success: true,
        data: response.data.stocks || response.data
      };
    }
    return response;
  }

  async getStock(symbol: string): Promise<ApiResponse<any>> {
    // Use mobile quote endpoint
    const response = await this.request<any>(`/mobile/stocks/${symbol}/quote`, {
      method: 'GET'
    });
    
    // Transform the response to match expected format
    if (response.success && response.data) {
      const transformedData = {
        symbol: response.data.symbol,
        companyName: response.data.companyName || response.data.quote?.longName || symbol,
        quote: response.data.quote,
        profile: {
          longName: response.data.companyName || response.data.quote?.longName || symbol,
          description: 'Stock quote data available.',
          sector: 'Unknown',
          sectorDisp: 'Unknown',
          country: 'United Kingdom',
        },
        details: {}
      };
      
      return {
        success: true,
        data: transformedData
      };
    }
    
    return response;
  }

  async getStockQuote(symbol: string): Promise<ApiResponse<any>> {
    return this.privateRequest<any>(`/mobile/stocks/${symbol}/quote`);
  }

  async getBatchPrices(symbols: string[]): Promise<ApiResponse<Record<string, any>>> {
    return this.privateRequest<Record<string, any>>('/mobile/stocks/batch-prices', {
      method: 'POST',
      body: JSON.stringify({ symbols }),
    });
  }

  // Portfolio methods
  async getPortfolios(): Promise<ApiResponse<any[]>> {
    return this.privateRequest<any[]>('/mobile/portfolio');
  }

  async getPortfolio(type: string): Promise<ApiResponse<any>> {
    if (this.localMode) {
      const userId = 'bina';
      const p = await localBackend.listPortfolio(userId, type as any);
      return p ? { success: true, data: { portfolio: p, holdings: p.holdings } } : { success: false, error: 'Portfolio not found' };
    }
    // FIXED: Use mobile-specific portfolio endpoint
    return this.request<any>(`/mobile/portfolio/${type}?refresh=true&t=${Date.now()}`, {
      method: 'GET',
      headers: {
        'Cache-Control': 'no-cache'
      }
    });
  }

  async getPortfolioHoldings(type: string): Promise<ApiResponse<any[]>> {
    // FIXED: Use mobile portfolio endpoint which includes holdings data
    const portfolioResponse = await this.getPortfolio(type);
    if (portfolioResponse.success && portfolioResponse.data.holdings) {
      return {
        success: true,
        data: portfolioResponse.data.holdings
      };
    }
    return {
      success: false,
      error: 'No holdings data available',
      data: []
    };
  }

  async getPortfolioTransactions(type: string): Promise<ApiResponse<any[]>> {
    // Use mobile portfolio transactions endpoint
    return this.request<any[]>(`/mobile/portfolio/${type}/transactions?t=${Date.now()}`, {
      method: 'GET',
      headers: {
        'Cache-Control': 'no-cache'
      }
    });
  }

  async getPortfolioPerformance(type: string, days: number = 30): Promise<ApiResponse<any[]>> {
    // Use mobile portfolio performance endpoint
    return this.request<any[]>(`/mobile/portfolio/${type}/performance?days=${days}&t=${Date.now()}`, {
      method: 'GET',
      headers: {
        'Cache-Control': 'no-cache'
      }
    });
  }

  async trade(type: string, symbol: string, quantity: number, action: 'buy' | 'sell', price?: number): Promise<ApiResponse<any>> {
    // Get current stock price if not provided
    let tradePrice = price;
    if (!tradePrice) {
      try {
        const stockResponse = await this.getStock(symbol);
        if (stockResponse.success && stockResponse.data?.quote?.price) {
          tradePrice = stockResponse.data.quote.price;
        } else {
          throw new Error('Unable to get current stock price');
        }
      } catch (error) {
        console.error('Error fetching stock price for trade:', error);
        throw error;
      }
    }

    if (this.localMode) {
      try {
  const upperAction = action.toUpperCase() as 'BUY' | 'SELL';
  const res = await localBackend.trade('bina', type as any, symbol, quantity, upperAction);
        return { success: true, data: res };
      } catch (e) {
        return { success: false, error: (e as Error).message };
      }
    }
    // Use mobile trade endpoint
    return this.request<any>(`/mobile/trade`, {
      method: 'POST',
      body: JSON.stringify({
        symbol,
        quantity,
        price: tradePrice,
        action,
        portfolioType: type,
        companyName: symbol,
      }),
    });
  }

  // Leaderboard methods
  async getLeaderboard(type: string): Promise<ApiResponse<any>> {
    if (this.localMode) {
      const data = await localBackend.leaderboard(type as any);
      return { success: true, data };
    }
    // Use mobile leaderboard endpoint
    return this.privateRequest<any>(`/mobile/leaderboard/${type}`);
  }

  async getLeaderboardUserPortfolio(type: string, userId: string): Promise<ApiResponse<any>> {
    if (this.localMode) {
      const p = await localBackend.listPortfolio(userId, type as any);
      return p ? { success: true, data: { holdings: p.holdings, cash_balance: p.cash_balance } } : { success: false, error: 'Not found' };
    }
    // Use mobile leaderboard user portfolio endpoint
    return this.privateRequest<any>(`/mobile/leaderboard/${type}/user/${encodeURIComponent(userId)}`);
  }

  // League methods
  async getLeagues(): Promise<ApiResponse<any>> {
    return this.privateRequest<any>('/mobile/leagues');
  }

  async createLeague(name: string, maxMembers: number = 20, isPublic: boolean = false): Promise<ApiResponse<any>> {
    return this.privateRequest<any>('/mobile/leagues', {
      method: 'POST',
      body: JSON.stringify({
        name,
        maxMembers,
        isPublic
      }),
    });
  }

  async joinLeague(code: string): Promise<ApiResponse<any>> {
    return this.privateRequest<any>(`/mobile/leagues/join/${encodeURIComponent(code)}`, {
      method: 'POST',
    });
  }

  // Community methods
  async getPosts(stock?: string, limit?: number): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (stock) params.append('stock', stock);
    if (limit) params.append('limit', limit.toString());
    
    return this.privateRequest<any[]>(`/community/posts?${params}`);
  }

  async createPost(content: string, stock?: string): Promise<ApiResponse<any>> {
    return this.privateRequest<any>('/community/posts', {
      method: 'POST',
      body: JSON.stringify({ content, stock }),
    });
  }

  async getStockComments(symbol: string): Promise<ApiResponse<any[]>> {
    return this.privateRequest<any[]>(`/stocks/${symbol}/comments`);
  }

  async addStockComment(symbol: string, content: string): Promise<ApiResponse<any>> {
    return this.privateRequest<any>(`/stocks/${symbol}/comments`, {
      method: 'POST',
      body: JSON.stringify({ content }),
    });
  }

  // User methods
  async updateProfile(data: { first_name?: string; last_name?: string; username?: string }): Promise<ApiResponse<any>> {
    return this.privateRequest<any>('/mobile/profile', {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  async uploadAvatar(imageUri: string): Promise<ApiResponse<{ avatarUrl: string }>> {
    const token = await this.getToken();
    if (!token) return { success: false, error: 'Not authenticated' };

    const formData = new FormData();
    const filename = imageUri.split('/').pop() || 'avatar.jpg';
    const ext = filename.split('.').pop()?.toLowerCase() || 'jpg';
    const type = ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg';

    formData.append('avatar', {
      uri: imageUri,
      name: filename,
      type,
    } as any);

    const baseUrl = this.getBaseUrl();
    try {
      const response = await fetch(`${baseUrl}/api/mobile/profile/avatar`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
        },
        body: formData,
      });
      const data = await response.json();
      return { success: data.success, data, error: data.error };
    } catch (err) {
      return { success: false, error: 'Failed to upload avatar' };
    }
  }

  // Trading window and pending orders methods
  async getTradingWindow(): Promise<ApiResponse<{
    tradingWindow: {
      type: 'market_open' | 'after_hours' | 'pre_market' | 'weekend_holiday';
      canTradeImmediately: boolean;
      canCreatePendingOrder: boolean;
      executionPrice: 'live' | 'close' | 'open';
      message: string;
    };
    marketInfo: {
      isMarketOpen: boolean;
      nextMarketOpen: string;
      openTime: string;
      closeTime: string;
      isHoliday: boolean;
      lastTradingDay: string;
    };
  }>> {
    return this.privateRequest('/mobile/trading-window');
  }

  async getPendingOrders(portfolioType?: string): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    params.append('status', 'pending');
    if (portfolioType) params.append('portfolioType', portfolioType);
    return this.privateRequest<any[]>(`/pending-orders?${params}`);
  }

  async cancelPendingOrder(orderId: string): Promise<ApiResponse<any>> {
    return this.privateRequest<any>(`/pending-orders?id=${orderId}`, {
      method: 'DELETE',
    });
  }

  // Force clear token and reset to use real API (for debugging)
  async forceRealApiMode(): Promise<void> {
    console.log('🔄 Forcing real API mode...');
    await this.clearToken();
    console.log('✅ Token cleared, will use real API on next request');
  }

  // Debug method to test all connectivity options
  async debugConnectivity(): Promise<void> {
    console.log('🔍 === API CONNECTIVITY DEBUG ===');
    console.log('Current base URL:', this.baseUrl);
    console.log('Platform:', Platform.OS);
    console.log('Is development:', __DEV__);
    console.log('Offline mode:', this.isOfflineMode());
    console.log('Token present:', !!this.token);
    console.log('Token type:', this.token ? (this.token.startsWith('dev-token') ? 'Mock' : 'Real') : 'None');
    
    // Test subscriptions endpoint
    try {
      console.log('🧪 Testing subscriptions endpoint...');
      const subResult = await this.request('/subscriptions');
      if (subResult.success) {
        console.log('✅ Subscriptions works!');
      } else {
        console.log('❌ Subscriptions failed:', subResult.error);
      }
    } catch (error) {
      console.log('❌ Subscriptions error:', (error as Error).message);
    }
    
    console.log('🔍 === END DEBUG ===');
  }

  // ─── Gamification ───

  async getGamificationProfile() {
    return this.privateRequest('/mobile/gamification/profile');
  }

  async recordDailyLogin() {
    return this.privateRequest('/mobile/gamification/login', { method: 'POST' });
  }

  async getAchievements() {
    return this.privateRequest('/mobile/gamification/achievements');
  }

  async getDailyChallenges() {
    return this.privateRequest('/mobile/gamification/challenges');
  }

  async getWeeklyChallenges() {
    return this.privateRequest('/mobile/gamification/challenges/weekly');
  }

  async getStockHunt() {
    return this.privateRequest('/mobile/gamification/challenges/stock-hunt');
  }

  async searchStockHunt(q: string) {
    return this.privateRequest(`/mobile/gamification/challenges/stock-hunt/search?q=${encodeURIComponent(q)}`);
  }

  async claimStockHunt(symbol: string) {
    return this.privateRequest('/mobile/gamification/challenges/stock-hunt/claim', {
      method: 'POST',
      body: JSON.stringify({ symbol }),
    });
  }

  async updateChallengeProgress(criteriaType: string, increment: number = 1) {
    return this.privateRequest('/mobile/gamification/challenges/progress', {
      method: 'POST',
      body: JSON.stringify({ criteria_type: criteriaType, increment }),
    });
  }

  async checkAchievements() {
    return this.privateRequest('/mobile/gamification/check', { method: 'POST' });
  }
}

export const apiService = new ApiService();
export default apiService;
