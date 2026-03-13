// Enhanced loading spinner component with modern design
import React, { useEffect, useRef } from 'react';
import {
  View,
  ActivityIndicator,
  Text,
  StyleSheet,
  Animated,
  Dimensions,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';

const { width } = Dimensions.get('window');

interface LoadingSpinnerProps {
  size?: 'small' | 'large';
  text?: string;
  color?: string;
  showBackground?: boolean;
  variant?: 'spinner' | 'pulse' | 'dots';
}

export default function LoadingSpinner({ 
  size = 'large', 
  text = 'Loading...', 
  color = '#3B82F6',
  showBackground = true,
  variant = 'spinner'
}: LoadingSpinnerProps) {
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0.8)).current;
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Entrance animation
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 600,
        useNativeDriver: true,
      }),
      Animated.spring(scaleAnim, {
        toValue: 1,
        tension: 100,
        friction: 8,
        useNativeDriver: true,
      }),
    ]).start();

    // Pulse animation for pulse variant
    if (variant === 'pulse') {
      const pulse = () => {
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ]).start(pulse);
      };
      pulse();
    }
  }, [variant]);

  const renderSpinner = () => {
    switch (variant) {
      case 'pulse':
        return (
          <Animated.View style={[
            styles.pulseContainer,
            {
              transform: [{ scale: pulseAnim }]
            }
          ]}>
            <View style={[styles.pulseCircle, { backgroundColor: color }]} />
          </Animated.View>
        );
      
      case 'dots':
        return (
          <View style={styles.dotsContainer}>
            {[0, 1, 2].map((index) => (
              <Animated.View
                key={index}
                style={[
                  styles.dot,
                  { backgroundColor: color },
                  {
                    opacity: fadeAnim.interpolate({
                      inputRange: [0, 1],
                      outputRange: [0.3, 1],
                    }),
                  }
                ]}
              />
            ))}
          </View>
        );
      
      default:
        return <ActivityIndicator size={size} color={color} />;
    }
  };

  if (!showBackground) {
    return (
      <Animated.View style={[
        styles.inlineContainer,
        {
          opacity: fadeAnim,
          transform: [{ scale: scaleAnim }]
        }
      ]}>
        {renderSpinner()}
        {text && <Text style={[styles.inlineText, { color }]}>{text}</Text>}
      </Animated.View>
    );
  }

  return (
    <View style={styles.container}>
      <LinearGradient
        colors={['#0f172a', '#1e3a8a', '#581c87']}
        style={StyleSheet.absoluteFillObject}
      />
      
      {/* Background Effects */}
      <View style={styles.backgroundEffects}>
        <Animated.View 
          style={[
            styles.blob,
            styles.blob1,
            {
              opacity: fadeAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [0, 0.1]
              })
            }
          ]} 
        />
        <Animated.View 
          style={[
            styles.blob,
            styles.blob2,
            {
              opacity: fadeAnim.interpolate({
                inputRange: [0, 1],
                outputRange: [0, 0.08]
              })
            }
          ]} 
        />
      </View>

      <Animated.View style={[
        styles.content,
        {
          opacity: fadeAnim,
          transform: [{ scale: scaleAnim }]
        }
      ]}>
        <View style={styles.loadingCard}>
          <LinearGradient
            colors={['rgba(17, 24, 39, 0.9)', 'rgba(31, 41, 55, 0.9)']}
            style={styles.loadingCardGradient}
          >
            <View style={styles.iconContainer}>
              <Ionicons name="flash" size={32} color={color} />
            </View>
            
            {renderSpinner()}
            
            <View style={styles.textSection}>
              <Text style={styles.loadingTitle}>ShareQuest</Text>
              <Text style={[styles.loadingText, { color }]}>{text}</Text>
              <Text style={styles.loadingSubtext}>Preparing your trading environment...</Text>
            </View>
          </LinearGradient>
        </View>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backgroundEffects: {
    position: 'absolute',
    width: '100%',
    height: '100%',
  },
  blob: {
    position: 'absolute',
    borderRadius: 200,
  },
  blob1: {
    width: width * 0.8,
    height: width * 0.8,
    backgroundColor: 'rgba(59, 130, 246, 0.1)',
    top: -width * 0.4,
    right: -width * 0.4,
  },
  blob2: {
    width: width * 0.6,
    height: width * 0.6,
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    bottom: -width * 0.3,
    left: -width * 0.3,
  },
  content: {
    alignItems: 'center',
    zIndex: 10,
  },
  loadingCard: {
    borderRadius: 24,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 12,
    },
    shadowOpacity: 0.3,
    shadowRadius: 24,
    elevation: 20,
  },
  loadingCardGradient: {
    padding: 32,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    borderRadius: 24,
    minWidth: width * 0.8,
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 20,
    backgroundColor: 'rgba(59, 130, 246, 0.15)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
    borderWidth: 1,
    borderColor: 'rgba(59, 130, 246, 0.3)',
  },
  textSection: {
    alignItems: 'center',
    marginTop: 24,
  },
  loadingTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 8,
  },
  loadingText: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 8,
  },
  loadingSubtext: {
    fontSize: 14,
    color: '#9CA3AF',
    textAlign: 'center',
    lineHeight: 20,
  },
  
  // Inline variant styles
  inlineContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
  },
  inlineText: {
    marginLeft: 12,
    fontSize: 16,
    fontWeight: '500',
  },
  
  // Pulse variant styles
  pulseContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  pulseCircle: {
    width: 60,
    height: 60,
    borderRadius: 30,
    opacity: 0.6,
  },
  
  // Dots variant styles
  dotsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
});