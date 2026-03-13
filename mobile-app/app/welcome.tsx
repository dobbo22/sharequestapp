import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';

import { SocialLoginButtons } from '../components/SocialLoginButtons';

export default function WelcomeScreen() {
  const router = useRouter();
  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Welcome to{'\n'}ShareQuest!</Text>
        <Text style={styles.subtitle}>
          Practice trading, join competitions,{'\n'}and learn the markets.
        </Text>
      </View>
      <View style={styles.card}>
        <SocialLoginButtons callbackUrl="/" />
        <TouchableOpacity style={styles.createAccountButton} onPress={() => router.push('/(auth)/register')}>
          <Text style={styles.createAccountButtonText}>Create Account</Text>
        </TouchableOpacity>
        <View style={styles.signInRow}>
          <Text style={styles.signInText}>Already got an account?</Text>
          <TouchableOpacity onPress={() => router.push('/(auth)/login')}>
            <Text style={styles.signInButtonText}>Sign in here</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0a1a2f',
    padding: 24,
  },
  header: {
    alignItems: 'center',
    marginBottom: 32,
  },
  title: {
    fontSize: 34,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 12,
    textAlign: 'center',
    lineHeight: 42,
  },
  subtitle: {
    fontSize: 16,
    color: '#b0c4de',
    textAlign: 'center',
    lineHeight: 24,
  },
  card: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: 'rgba(17,24,39,0.85)',
    borderRadius: 20,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
  },
  createAccountButton: {
    backgroundColor: '#3B82F6',
    paddingVertical: 14,
    borderRadius: 12,
    marginTop: 4,
    marginBottom: 10,
    alignItems: 'center',
  },
  createAccountButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  signInRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 12,
  },
  signInText: {
    color: '#b0c4de',
    fontSize: 14,
    marginRight: 6,
  },
  signInButtonText: {
    color: '#3B82F6',
    fontSize: 14,
    fontWeight: 'bold',
    textDecorationLine: 'underline',
  },
});
