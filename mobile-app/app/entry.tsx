import React, { useEffect } from 'react';
import SplashScreen from './SplashScreen';
import * as ExpoSplashScreen from 'expo-splash-screen';
import { useRouter } from 'expo-router';

export default function Entry() {
  const router = useRouter();

  useEffect(() => {
    // Hide the native splash screen so our custom one is visible
    ExpoSplashScreen.hideAsync();

    let timer: NodeJS.Timeout;
    const checkAccount = async () => {
      try {
        const AsyncStorage = (await import('@react-native-async-storage/async-storage')).default;
        const hasAccount = await AsyncStorage.getItem('has_account');
        timer = setTimeout(() => {
          if (hasAccount === 'true') {
            // User has registered before, go to login or main tabs
            router.replace('/(auth)/login');
          } else {
            router.replace('/welcome');
          }
        }, 2000);
      } catch (e) {
        // Fallback to welcome if error
        timer = setTimeout(() => router.replace('/welcome'), 2000);
      }
    };
    checkAccount();
    return () => clearTimeout(timer);
  }, [router]);

  return <SplashScreen />;
}
