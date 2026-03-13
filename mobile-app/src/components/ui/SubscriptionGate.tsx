import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';

interface SubscriptionGateProps {
  feature?: string;
}

export default function SubscriptionGate({ feature }: SubscriptionGateProps) {
  const router = useRouter();

  return (
    <View style={styles.container}>
      <LinearGradient
        colors={['rgba(88, 28, 135, 0.4)', 'rgba(49, 46, 129, 0.4)']}
        style={styles.card}
      >
        <View style={styles.iconRow}>
          <View style={styles.lockCircle}>
            <Ionicons name="lock-closed" size={28} color="#F0ABFC" />
          </View>
          <Text style={styles.title}>Subscription Required</Text>
        </View>

        <View style={styles.deniedBanner}>
          <Text style={styles.deniedTitle}>Access Denied</Text>
          <Text style={styles.deniedText}>
            Subscribe to unlock {feature || 'this premium content and analysis'}.
          </Text>
        </View>

        <View style={styles.featuresBox}>
          <Text style={styles.premiumTitle}>ShareQuest Premium</Text>
          <View style={styles.featureRow}>
            <Ionicons name="checkmark-circle" size={16} color="#A78BFA" />
            <Text style={styles.featureText}>View full analysis and financials</Text>
          </View>
          <View style={styles.featureRow}>
            <Ionicons name="checkmark-circle" size={16} color="#A78BFA" />
            <Text style={styles.featureText}>Access advanced metrics and score breakdowns</Text>
          </View>
          <View style={styles.featureRow}>
            <Ionicons name="checkmark-circle" size={16} color="#A78BFA" />
            <Text style={styles.featureText}>Compete in leaderboards and track your progress</Text>
          </View>

          <TouchableOpacity
            style={styles.subscribeButton}
            onPress={() => router.push('/(tabs)/portfolio')}
          >
            <LinearGradient
              colors={['#EC4899', '#7C3AED']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 0 }}
              style={styles.subscribeGradient}
            >
              <Text style={styles.subscribeText}>Subscribe Now</Text>
            </LinearGradient>
          </TouchableOpacity>

          <Text style={styles.supportText}>
            Your subscription supports platform development and fair competition.
          </Text>
        </View>
      </LinearGradient>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    flex: 1,
    justifyContent: 'center',
  },
  card: {
    borderRadius: 16,
    padding: 24,
    borderWidth: 2,
    borderColor: 'rgba(139, 92, 246, 0.4)',
  },
  iconRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
  },
  lockCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(139, 92, 246, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
  },
  deniedBanner: {
    backgroundColor: 'rgba(236, 72, 153, 0.1)',
    borderWidth: 1,
    borderColor: 'rgba(236, 72, 153, 0.3)',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginBottom: 16,
  },
  deniedTitle: {
    color: '#F9A8D4',
    fontWeight: '700',
    fontSize: 14,
  },
  deniedText: {
    color: '#FBCFE8',
    fontSize: 12,
    marginTop: 2,
  },
  featuresBox: {
    backgroundColor: 'rgba(88, 28, 135, 0.3)',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(139, 92, 246, 0.2)',
  },
  premiumTitle: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8,
  },
  featureText: {
    color: '#C4B5FD',
    fontSize: 13,
    flex: 1,
  },
  subscribeButton: {
    marginTop: 16,
    borderRadius: 10,
    overflow: 'hidden',
  },
  subscribeGradient: {
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: 10,
  },
  subscribeText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  supportText: {
    color: 'rgba(196, 181, 253, 0.6)',
    fontSize: 10,
    textAlign: 'center',
    marginTop: 8,
  },
});
