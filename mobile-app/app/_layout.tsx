import { useEffect } from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import * as SplashScreen from 'expo-splash-screen';
import { AuthProvider } from '../src/hooks/useAuth';
import { StyleSheet, View } from 'react-native';

// Prevent splash screen from auto-hiding
SplashScreen.preventAutoHideAsync();

// Create a client for React Query
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60, // 1 minute
      gcTime: 1000 * 60 * 5, // 5 minutes (previously cacheTime)
    },
  },
});

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={styles.container}>
      <SafeAreaProvider>
        <QueryClientProvider client={queryClient}>
          <AuthProvider>
            <View style={styles.container}>
              <StatusBar style="light" />
              <Stack
                initialRouteName="entry"
                screenOptions={{
                  headerShown: false,
                  contentStyle: { backgroundColor: '#0f172a' },
                  animation: 'slide_from_right',
                }}
              >
                <Stack.Screen name="entry" />
                <Stack.Screen name="index" />
                <Stack.Screen name="welcome" />
                <Stack.Screen name="(auth)" />
                <Stack.Screen name="(tabs)" />
              </Stack>
            </View>
          </AuthProvider>
        </QueryClientProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
});
