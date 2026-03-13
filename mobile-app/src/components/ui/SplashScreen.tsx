import React from 'react';
import { View, Image, Text, StyleSheet, Animated, Dimensions } from 'react-native';

const { width, height } = Dimensions.get('window');

interface SplashScreenProps {
  fadeAnim: Animated.Value;
}

export const SplashScreen: React.FC<SplashScreenProps> = ({ fadeAnim }) => {
  return (
    <View style={styles.container}>
      <Animated.View style={[styles.content, { opacity: fadeAnim }]}>
        <Image
          source={require('../../../assets/sharequest-crop.png')}
          style={styles.logo}
          resizeMode="contain"
        />
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>Loading...</Text>
          <View style={styles.loadingBar}>
            <Animated.View 
              style={[
                styles.loadingProgress,
                { 
                  transform: [{
                    scaleX: fadeAnim.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0, 1]
                    })
                  }],
                  opacity: fadeAnim
                }
              ]}
            />
          </View>
        </View>
      </Animated.View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1e3a5f', // ShareQuest brand color
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
  },
  logo: {
    width: width * 0.8,
    height: 120,
    marginBottom: 60,
  },
  loadingContainer: {
    alignItems: 'center',
    width: width * 0.6,
  },
  loadingText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '500',
    marginBottom: 20,
    opacity: 0.9,
  },
  loadingBar: {
    width: '100%',
    height: 4,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    borderRadius: 2,
    overflow: 'hidden',
  },
  loadingProgress: {
    height: '100%',
    width: '100%', // Add this to ensure full width for scale transform
    backgroundColor: '#4AAEE8', // Light blue accent
    borderRadius: 2,
    transformOrigin: 'left', // Make it scale from left to right
  },
});