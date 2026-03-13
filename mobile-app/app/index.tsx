
import React, { useEffect, useState } from 'react';
import SplashScreen from './SplashScreen';
import { useRouter } from 'expo-router';
import * as ExpoSplashScreen from 'expo-splash-screen';

export default function Index() {
  const router = useRouter();
  const [showSplash, setShowSplash] = useState(true);

  useEffect(() => {
    // Hide native splash immediately
    ExpoSplashScreen.hideAsync();
    // Show custom splash for 2 seconds, then go to onboarding
    const timer = setTimeout(() => {
      setShowSplash(false);
      router.replace('/onboarding');
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  if (showSplash) {
    return <SplashScreen />;
  }
  return null;
}
