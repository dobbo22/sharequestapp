// Subscription hook for mobile app
import { useState, useEffect } from 'react';
import { apiService } from '../services/api';

export interface UserSubscriptions {
  weekly: boolean;
  monthly: boolean;
  annual: boolean;
  default: boolean;
}

export function useSubscriptions() {
  const [subscriptions, setSubscriptions] = useState<UserSubscriptions>({
    weekly: false,
    monthly: false,
    annual: false,
    default: true
  });
  
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchSubscriptions = async () => {
    try {
      setError(null);
      const response = await apiService.request('/mobile/subscriptions');
      
      if (response.success && response.data) {
        const subs = response.data.subscriptions || response.data;
        setSubscriptions({
          weekly: subs.weekly || false,
          monthly: subs.monthly || false,
          annual: subs.annual || false,
          default: true
        });
      } else {
        throw new Error(response.error || 'Failed to fetch subscriptions');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load subscriptions');
    } finally {
      setLoading(false);
    }
  };

  const subscribe = async (portfolioType: string): Promise<boolean> => {
    try {
      setError(null);
      const response = await apiService.request('/mobile/subscriptions', {
        method: 'POST',
        body: JSON.stringify({ portfolioType }),
      });
      
      if (response.success) {
        // Update local state
        setSubscriptions(prev => ({
          ...prev,
          [portfolioType]: true
        }));
        return true;
      } else {
        setError(response.error || 'Failed to subscribe');
        return false;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to subscribe');
      return false;
    }
  };

  const unsubscribe = async (portfolioType: string): Promise<boolean> => {
    try {
      setError(null);
      const response = await apiService.request('/mobile/subscriptions', {
        method: 'DELETE',
        body: JSON.stringify({ portfolioType }),
      });
      
      if (response.success) {
        // Update local state
        setSubscriptions(prev => ({
          ...prev,
          [portfolioType]: false
        }));
        return true;
      } else {
        setError(response.error || 'Failed to unsubscribe');
        return false;
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unsubscribe');
      return false;
    }
  };

  const refetch = async () => {
    setLoading(true);
    await fetchSubscriptions();
  };

  useEffect(() => {
    fetchSubscriptions();
  }, []);

  return {
    subscriptions,
    loading,
    error,
    subscribe,
    unsubscribe,
    refetch
  };
}