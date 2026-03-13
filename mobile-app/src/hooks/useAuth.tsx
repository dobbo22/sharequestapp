// Authentication hook for mobile app
import React, { useState, useEffect, useContext, createContext } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { apiService } from '../services/api';

export interface User {
  id: string;
  email: string;
  username: string;
  first_name?: string;
  last_name?: string;
  avatar_url?: string | null;
  isAdmin?: boolean;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<boolean>;
  signUp: (email: string, username: string, password: string, additionalData?: any) => Promise<boolean>;
  signOut: () => Promise<void>;
  updateUser: (updates: Partial<User>) => Promise<void>;
  error: string | null;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Load user from storage on startup
  useEffect(() => {
    // Try to load user from AsyncStorage (from login response)
    const loadUser = async () => {
      try {
        setLoading(true);
        const userDataStr = await AsyncStorage.getItem('user_data');
        if (userDataStr) {
          setUser(JSON.parse(userDataStr));
        } else {
          // Fallback: if no user_data, try getProfile
          const token = await AsyncStorage.getItem('auth_token');
          if (token) {
            const timeoutPromise = new Promise((_, reject) => 
              setTimeout(() => reject(new Error('Request timeout')), 5000)
            );
            const apiPromise = apiService.getProfile();
            try {
              const response = await Promise.race([apiPromise, timeoutPromise]) as any;
              if (response.success && response.data) {
                setUser(response.data);
              } else {
                await AsyncStorage.removeItem('auth_token');
                setError('Session expired. Please login again.');
              }
            } catch (timeoutError) {
              console.warn('Auth check timed out, proceeding without user');
              setError('Connection timeout. Please check your network.');
            }
          }
        }
      } catch (err) {
        console.error('Error loading user:', err);
        setError('Failed to load user session');
      } finally {
        setLoading(false);
      }
    };
    loadUser();
  }, []);

  const signIn = async (email: string, password: string): Promise<boolean> => {
    try {
      setLoading(true);
      setError(null);

      const response = await apiService.login(email, password);

      if (response.success && response.data) {
        setUser(response.data.user);
        return true;
      } else {
        setError(response.error || 'Login failed');
        return false;
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Login failed';
      setError(errorMessage);
      return false;
    } finally {
      setLoading(false);
    }
  };

  const signUp = async (email: string, username: string, password: string, additionalData?: any): Promise<boolean> => {
    try {
      setLoading(true);
      setError(null);

      const response = await apiService.register(email, username, password, additionalData);

      if (response.success && response.data) {
        setUser(response.data.user);
        return true;
      } else {
        setError(response.error || 'Registration failed');
        return false;
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Registration failed';
      setError(errorMessage);
      return false;
    } finally {
      setLoading(false);
    }
  };

  const signOut = async (): Promise<void> => {
    try {
      // Clear all session data
      await apiService.logout();
      await AsyncStorage.removeItem('auth_token');
      await AsyncStorage.removeItem('user_data');
      setUser(null);
      setError(null);
    } catch (err) {
      console.error('Error signing out:', err);
    }
  };

  const updateUser = async (updates: Partial<User>): Promise<void> => {
    if (!user) return;
    const updated = { ...user, ...updates };
    setUser(updated);
    await AsyncStorage.setItem('user_data', JSON.stringify(updated));
  };

  const value = {
    user,
    loading,
    signIn,
    signUp,
    signOut,
    updateUser,
    error,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}