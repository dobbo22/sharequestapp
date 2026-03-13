import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

interface ShareQuestScores {
  overall: number | null;
  fundamental: number | null;
  performance: number | null;
  technical: number | null;
  updatedAt: string | null;
  technicalMetrics: {
    sharpe: number | null;
    calmar: number | null;
    marketCapRisk: number | null;
  };
  performanceFigures: Record<string, number> | null;
}

interface Props {
  scores: ShareQuestScores | null;
}

const getScoreColor = (score: number) => {
  if (score >= 80) return '#34D399';
  if (score >= 60) return '#60A5FA';
  if (score >= 40) return '#FBBF24';
  return '#F87171';
};

const getScoreBg = (score: number) => {
  if (score >= 80) return 'rgba(52, 211, 153, 0.15)';
  if (score >= 60) return 'rgba(96, 165, 250, 0.15)';
  if (score >= 40) return 'rgba(251, 191, 36, 0.15)';
  return 'rgba(248, 113, 113, 0.15)';
};

const getScoreLabel = (score: number) => {
  if (score >= 80) return 'Strong';
  if (score >= 60) return 'Good';
  if (score >= 40) return 'Fair';
  return 'Weak';
};

const formatMetric = (value: number | null | undefined, decimals = 2) => {
  if (value === null || value === undefined || isNaN(value)) return '--';
  return value.toFixed(decimals);
};

function ScoreBar({ label, score, weight }: { label: string; score: number | null; weight: string }) {
  const val = score ?? 0;
  const color = getScoreColor(val);
  const pct = Math.min(Math.max(val, 0), 100);

  return (
    <View style={styles.scoreBarContainer}>
      <View style={styles.scoreBarHeader}>
        <Text style={styles.scoreBarLabel}>{label}</Text>
        <Text style={[styles.scoreBarWeight, { color: '#6B7280' }]}>{weight}</Text>
      </View>
      <View style={styles.scoreBarTrack}>
        <View style={[styles.scoreBarFill, { width: `${pct}%`, backgroundColor: color }]} />
      </View>
      <Text style={[styles.scoreBarValue, { color }]}>
        {score != null ? score.toFixed(1) : '--'}
      </Text>
    </View>
  );
}

function MetricRow({ label, value, isLast }: { label: string; value: string; isLast?: boolean }) {
  return (
    <View style={[styles.metricRow, isLast && styles.metricRowLast]}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

export default function ShareQuestAnalysisTab({ scores }: Props) {
  if (!scores || scores.overall == null) {
    return (
      <View style={styles.container}>
        <View style={styles.emptyState}>
          <Ionicons name="analytics-outline" size={64} color="#4B5563" />
          <Text style={styles.emptyTitle}>Analysis Unavailable</Text>
          <Text style={styles.emptyText}>
            ShareQuest analysis is not yet available for this stock.
          </Text>
        </View>
      </View>
    );
  }

  const overall = scores.overall;
  const color = getScoreColor(overall);
  const perfFigs = scores.performanceFigures;

  return (
    <View style={styles.container}>
      {/* Overall Score */}
      <View style={[styles.overallCard, { borderColor: color + '40' }]}>
        <View style={styles.overallHeader}>
          <Text style={styles.overallLabel}>Overall Score</Text>
          <View style={[styles.scoreBadge, { backgroundColor: getScoreBg(overall) }]}>
            <Text style={[styles.scoreBadgeText, { color }]}>{getScoreLabel(overall)}</Text>
          </View>
        </View>
        <Text style={[styles.overallValue, { color }]}>{overall.toFixed(1)}</Text>
        <View style={styles.overallBarTrack}>
          <View style={[styles.overallBarFill, { width: `${Math.min(overall, 100)}%`, backgroundColor: color }]} />
        </View>
        <Text style={styles.overallRange}>0 — 100</Text>
      </View>

      {/* Sub-scores */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name="bar-chart-outline" size={16} color="#60A5FA" />
          <Text style={styles.sectionTitle}>Score Breakdown</Text>
        </View>
        <View style={styles.scoresCard}>
          <ScoreBar label="Technical" score={scores.technical} weight="50%" />
          <ScoreBar label="Fundamental" score={scores.fundamental} weight="30%" />
          <ScoreBar label="Performance" score={scores.performance} weight="20%" />
        </View>
      </View>

      {/* Technical Metrics */}
      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Ionicons name="pulse-outline" size={16} color="#34D399" />
          <Text style={styles.sectionTitle}>Technical Metrics</Text>
        </View>
        <View style={styles.metricsCard}>
          <MetricRow label="Sharpe Ratio" value={formatMetric(scores.technicalMetrics?.sharpe)} />
          <MetricRow label="Calmar Ratio" value={formatMetric(scores.technicalMetrics?.calmar)} />
          <MetricRow label="Market Cap Risk" value={formatMetric(scores.technicalMetrics?.marketCapRisk)} isLast />
        </View>
      </View>

      {/* Performance Figures */}
      {perfFigs && (
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Ionicons name="trending-up-outline" size={16} color="#FBBF24" />
            <Text style={styles.sectionTitle}>Performance</Text>
          </View>
          <View style={styles.metricsCard}>
            {perfFigs.performance_1_month != null && (
              <MetricRow label="1 Month" value={`${perfFigs.performance_1_month >= 0 ? '+' : ''}${perfFigs.performance_1_month.toFixed(2)}%`} />
            )}
            {perfFigs.performance_3_month != null && (
              <MetricRow label="3 Months" value={`${perfFigs.performance_3_month >= 0 ? '+' : ''}${perfFigs.performance_3_month.toFixed(2)}%`} />
            )}
            {perfFigs.performance_current_year != null && (
              <MetricRow label="Year to Date" value={`${perfFigs.performance_current_year >= 0 ? '+' : ''}${perfFigs.performance_current_year.toFixed(2)}%`} />
            )}
            {perfFigs.performance_1_year != null && (
              <MetricRow label="1 Year" value={`${perfFigs.performance_1_year >= 0 ? '+' : ''}${perfFigs.performance_1_year.toFixed(2)}%`} isLast />
            )}
          </View>
        </View>
      )}

      {/* Updated at */}
      {scores.updatedAt && (
        <View style={styles.disclaimer}>
          <Ionicons name="time-outline" size={14} color="#6B7280" />
          <Text style={styles.disclaimerText}>
            Last updated: {new Date(scores.updatedAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })}
          </Text>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  emptyState: { alignItems: 'center', justifyContent: 'center', paddingVertical: 60 },
  emptyTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '600', marginTop: 16, marginBottom: 8 },
  emptyText: { color: '#9CA3AF', fontSize: 14, textAlign: 'center', paddingHorizontal: 40 },

  overallCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    marginBottom: 20,
    alignItems: 'center',
  },
  overallHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', width: '100%', marginBottom: 8 },
  overallLabel: { color: '#D1D5DB', fontSize: 14, fontWeight: '600' },
  scoreBadge: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 10 },
  scoreBadgeText: { fontSize: 12, fontWeight: '700' },
  overallValue: { fontSize: 48, fontWeight: 'bold', marginVertical: 4 },
  overallBarTrack: { height: 8, backgroundColor: 'rgba(55, 65, 81, 0.6)', borderRadius: 4, width: '100%', overflow: 'hidden', marginTop: 8 },
  overallBarFill: { height: '100%', borderRadius: 4 },
  overallRange: { color: '#6B7280', fontSize: 10, marginTop: 4 },

  section: { marginBottom: 20 },
  sectionHeader: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  sectionTitle: { color: '#D1D5DB', fontSize: 14, fontWeight: '600', marginLeft: 6 },

  scoresCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    gap: 16,
  },
  scoreBarContainer: { flexDirection: 'row', alignItems: 'center' },
  scoreBarHeader: { width: 100 },
  scoreBarLabel: { color: '#D1D5DB', fontSize: 13, fontWeight: '500' },
  scoreBarWeight: { fontSize: 10, marginTop: 1 },
  scoreBarTrack: { flex: 1, height: 8, backgroundColor: 'rgba(55, 65, 81, 0.6)', borderRadius: 4, overflow: 'hidden', marginHorizontal: 10 },
  scoreBarFill: { height: '100%', borderRadius: 4 },
  scoreBarValue: { width: 36, textAlign: 'right', fontSize: 13, fontWeight: '700' },

  metricsCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    overflow: 'hidden',
  },
  metricRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 14,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.2)',
  },
  metricRowLast: { borderBottomWidth: 0 },
  metricLabel: { color: '#9CA3AF', fontSize: 13, fontWeight: '500' },
  metricValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },

  disclaimer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.3)',
    borderRadius: 10,
    padding: 10,
    marginTop: 4,
  },
  disclaimerText: { color: '#6B7280', fontSize: 11, marginLeft: 6, flex: 1 },
});
