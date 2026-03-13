import React from 'react';
import { View, Text } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons } from '@expo/vector-icons';

export default function MarketSentiment({ sentiment, styles }: { sentiment: any, styles: any }) {
  if (!sentiment) return null;
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Market Sentiment</Text>
      <LinearGradient
        colors={['rgba(31, 41, 55, 0.8)', 'rgba(17, 24, 39, 0.8)']}
        style={styles.sentimentCard}
      >
        <View style={styles.sentimentHeader}>
          <View style={styles.sentimentScore}>
            <Text style={[
              styles.sentimentScoreValue,
              { color: sentiment.overall.sentiment === 'bullish' ? '#10B981' :
                       sentiment.overall.sentiment === 'bearish' ? '#EF4444' : '#F59E0B' }
            ]}>
              {sentiment.overall.score}
            </Text>
            <Text style={styles.sentimentScoreLabel}>/100</Text>
          </View>
          <View style={styles.sentimentInfo}>
            <View style={[
              styles.sentimentBadge,
              { backgroundColor: sentiment.overall.sentiment === 'bullish' ? '#10B98120' :
                                sentiment.overall.sentiment === 'bearish' ? '#EF444420' : '#F59E0B20' }
            ]}>
              <MaterialCommunityIcons
                name={sentiment.overall.direction === 'up' ? 'trending-up' :
                      sentiment.overall.direction === 'down' ? 'trending-down' : 'minus'}
                size={16}
                color={sentiment.overall.sentiment === 'bullish' ? '#10B981' :
                       sentiment.overall.sentiment === 'bearish' ? '#EF4444' : '#F59E0B'}
              />
              <Text style={[
                styles.sentimentBadgeText,
                { color: sentiment.overall.sentiment === 'bullish' ? '#10B981' :
                         sentiment.overall.sentiment === 'bearish' ? '#EF4444' : '#F59E0B' }
              ]}>
                {sentiment.overall.sentiment.toUpperCase()}
              </Text>
            </View>
            <View style={styles.sentimentStats}>
              <Text style={styles.sentimentStatUp}>
                <MaterialCommunityIcons name="arrow-up" size={12} color="#10B981" /> {sentiment.metrics.gainerCount}
              </Text>
              <Text style={styles.sentimentStatDown}>
                <MaterialCommunityIcons name="arrow-down" size={12} color="#EF4444" /> {sentiment.metrics.loserCount}
              </Text>
            </View>
          </View>
        </View>
      </LinearGradient>
    </View>
  );
}
