import React from 'react';
import { View, Text, StyleSheet, Image } from 'react-native';

export default function SplashScreen() {
  return (
    <View style={styles.container}>
      <Image source={require('../assets/logo.png')} style={styles.logo} />
      <Text style={styles.title}>ShareQuest</Text>
      <Text style={styles.tagline}>Practice Trading. Compete. Learn.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0a1a2f',
  },
  logo: {
    width: 280,
    height: 280,
    resizeMode: 'contain',
    marginBottom: 24,
    marginTop: -40,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  tagline: {
    fontSize: 18,
    color: '#b0c4de',
  },
});
