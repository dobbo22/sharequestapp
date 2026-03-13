import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, ScrollView, Dimensions, Image } from 'react-native';
import { useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
import { useAuth } from '../../src/hooks/useAuth';

const { width } = Dimensions.get('window');

export default function ManualSignInScreen() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { signIn, error } = useAuth();
  const router = useRouter();

  const handleSubmit = async () => {
    if (!username || !password) {
      Alert.alert('Error', 'Username and password are required');
      return;
    }
    setLoading(true);
    const success = await signIn(username, password);
    setLoading(false);
    if (success) {
      try {
        const AsyncStorage = (await import('@react-native-async-storage/async-storage')).default;
        await AsyncStorage.setItem('has_account', 'true');
      } catch (e) {
        console.warn('Failed to set has_account flag:', e);
      }
      router.replace('/(tabs)');
    } else {
      Alert.alert('Login Failed', error || 'Unknown error occurred');
    }
  };

  return (
    <View style={{ flex: 1 }}>
      <LinearGradient
        colors={['#0f172a', '#1e3a8a', '#581c87']}
        locations={[0, 0.5, 1]}
        style={StyleSheet.absoluteFillObject}
      />
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', padding: 24 }}
        showsVerticalScrollIndicator={false}
      >
        <View style={{ alignItems: 'center', marginBottom: 24 }}>
          <Image
            source={require('../../assets/sharequest-splash.png')}
            style={{ width: width - 48, height: 70, marginBottom: 24, borderRadius: 16 }}
            resizeMode="contain"
          />
        </View>
        <View style={{ width: '100%', maxWidth: 400, backgroundColor: 'rgba(17,24,39,0.85)', borderRadius: 20, padding: 24, alignItems: 'center' }}>
          <Text style={{ color: '#fff', fontSize: 22, fontWeight: 'bold', marginBottom: 24 }}>Manual Sign In</Text>
          <TextInput
            style={styles.input}
            placeholder="Username"
            placeholderTextColor="#94a3b8"
            value={username}
            onChangeText={setUsername}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="email-address"
            textContentType="username"
          />
          <TextInput
            style={styles.input}
            placeholder="Password"
            placeholderTextColor="#94a3b8"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            textContentType="password"
          />
          <TouchableOpacity
            style={styles.signInButton}
            onPress={handleSubmit}
            disabled={loading}
          >
            <Text style={{ color: '#fff', fontSize: 18, fontWeight: 'bold' }}>{loading ? 'Signing in...' : 'Sign in'}</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={{ marginTop: 16 }}
            onPress={() => router.back()}
          >
            <Text style={{ color: '#60a5fa', fontSize: 16 }}>Back to login options</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={{ marginTop: 8 }}
            onPress={() => router.push('/(auth)/register')}
          >
            <Text style={{ color: '#a78bfa', fontSize: 16 }}>Don't have an account? Register</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  input: {
    width: '100%',
    backgroundColor: '#1e293b',
    color: '#fff',
    borderRadius: 8,
    paddingVertical: 14,
    paddingHorizontal: 16,
    fontSize: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#334155',
  },
  signInButton: {
    backgroundColor: '#3B82F6',
    paddingVertical: 14,
    borderRadius: 8,
    width: '100%',
    alignItems: 'center',
    marginTop: 8,
  },
});
