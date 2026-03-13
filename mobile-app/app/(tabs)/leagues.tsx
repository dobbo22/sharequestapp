import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  RefreshControl,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  Modal,
  Alert,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/hooks/useAuth';
import { apiService } from '../../src/services/api';

type TabType = 'my-leagues' | 'discover';

interface League {
  id: string;
  name: string;
  description?: string;
  creator_id?: string;
  creator_username?: string;
  member_count?: number;
  max_members?: number;
  is_private?: boolean;
  join_code?: string;
  competition_type?: string;
  status?: string;
  start_date?: string;
  end_date?: string;
  prize_pool?: number;
  created_at?: string;
  is_member?: boolean;
}

interface LeagueMember {
  user_id: string;
  username: string;
  rank?: number;
  total_value?: number;
  profit_loss?: number;
  profit_loss_percent?: number;
}

export default function LeaguesScreen() {
  const router = useRouter();
  const { user } = useAuth();

  const [activeTab, setActiveTab] = useState<TabType>('my-leagues');
  const [myLeagues, setMyLeagues] = useState<League[]>([]);
  const [publicLeagues, setPublicLeagues] = useState<League[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Create league modal
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newLeagueName, setNewLeagueName] = useState('');
  const [newLeagueDescription, setNewLeagueDescription] = useState('');
  const [newLeaguePrivate, setNewLeaguePrivate] = useState(false);
  const [creating, setCreating] = useState(false);

  // Join league modal
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [joinCode, setJoinCode] = useState('');
  const [joining, setJoining] = useState(false);

  // League detail modal
  const [selectedLeague, setSelectedLeague] = useState<League | null>(null);
  const [leagueMembers, setLeagueMembers] = useState<LeagueMember[]>([]);
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);

  const fetchLeagues = useCallback(async () => {
    try {
      setError(null);

      // Fetch user's leagues only
      const myResponse = await apiService.request<{ myLeagues: League[] }>('/mobile/leagues');
      if (myResponse.success && myResponse.data) {
        const leagues = Array.isArray(myResponse.data) ? myResponse.data : myResponse.data.myLeagues || [];
        setMyLeagues(leagues);
      }
      // No public leagues fetch
    } catch (err) {
      console.error('Error fetching leagues:', err);
      setError('Unable to load leagues');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchLeagues();
    apiService.updateChallengeProgress('leaderboard').catch(() => {});
  }, [fetchLeagues]);

  const onRefresh = async () => {
    setRefreshing(true);
    await fetchLeagues();
    setRefreshing(false);
  };

  const openLeagueDetail = async (league: League) => {
    setSelectedLeague(league);
    setShowDetailModal(true);
    setDetailLoading(true);

    try {
      const response = await apiService.request<{ members: LeagueMember[] }>(`/mobile/leagues/${league.id}/members`);
      if (response.success && response.data) {
        const members = Array.isArray(response.data) ? response.data : response.data.members || [];
        setLeagueMembers(members);
      }
    } catch (err) {
      console.error('Error fetching league members:', err);
    } finally {
      setDetailLoading(false);
    }
  };

  const createLeague = async () => {
    if (!newLeagueName.trim()) {
      Alert.alert('Error', 'Please enter a league name');
      return;
    }

    setCreating(true);
    try {
      const response = await apiService.request('/mobile/leagues', {
        method: 'POST',
        body: JSON.stringify({
          name: newLeagueName.trim(),
          description: newLeagueDescription.trim(),
          is_private: newLeaguePrivate,
        }),
      });

      if (response.success) {
        setShowCreateModal(false);
        setNewLeagueName('');
        setNewLeagueDescription('');
        setNewLeaguePrivate(false);
        fetchLeagues();
        Alert.alert('Success', 'League created successfully!');
      } else {
        Alert.alert('Error', response.error || 'Failed to create league');
      }
    } catch (err) {
      Alert.alert('Error', 'An error occurred');
    } finally {
      setCreating(false);
    }
  };

  const joinLeague = async (leagueId?: string, code?: string) => {
    setJoining(true);
    try {
      const body = code ? { join_code: code } : {};
      const endpoint = leagueId ? `/mobile/leagues/${leagueId}/join` : '/mobile/leagues/join';

      const response = await apiService.request(endpoint, {
        method: 'POST',
        body: JSON.stringify(body),
      });

      if (response.success) {
        setShowJoinModal(false);
        setJoinCode('');
        fetchLeagues();
        Alert.alert('Success', 'Joined league successfully!');
      } else {
        Alert.alert('Error', response.error || 'Failed to join league');
      }
    } catch (err) {
      Alert.alert('Error', 'An error occurred');
    } finally {
      setJoining(false);
    }
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return '--';
    try {
      return new Date(dateString).toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      });
    } catch {
      return '--';
    }
  };

  const renderLeagueCard = (league: League, showJoinButton = false) => {
    const memberText = league.max_members
      ? `${league.member_count || 0}/${league.max_members} members`
      : `${league.member_count || 0} members`;

    return (
      <TouchableOpacity
        key={league.id}
        style={styles.leagueCard}
        onPress={() => openLeagueDetail(league)}
      >
        <View style={styles.leagueCardHeader}>
          <View style={styles.leagueIconContainer}>
            <LinearGradient
              colors={league.is_private ? ['#8B5CF6', '#7C3AED'] : ['#3B82F6', '#1D4ED8']}
              style={styles.leagueIcon}
            >
              <MaterialCommunityIcons
                name={league.is_private ? 'lock-closed' : 'people'}
                size={20}
                color="#FFFFFF"
              />
            </LinearGradient>
          </View>
          <View style={styles.leagueInfo}>
            <Text style={styles.leagueName} numberOfLines={1}>{league.name}</Text>
            <Text style={styles.leagueMembers}>{memberText}</Text>
          </View>
          {showJoinButton && !league.is_member && (
            <TouchableOpacity
              style={styles.joinButton}
              onPress={(e) => {
                e.stopPropagation();
                joinLeague(league.id);
              }}
            >
              <Text style={styles.joinButtonText}>Join</Text>
            </TouchableOpacity>
          )}
        </View>

        {league.description && (
          <Text style={styles.leagueDescription} numberOfLines={2}>
            {league.description}
          </Text>
        )}

        <View style={styles.leagueFooter}>
          {league.creator_username && (
            <Text style={styles.leagueCreator}>Created by {league.creator_username}</Text>
          )}
          {league.status && (
            <View style={[
              styles.statusBadge,
              league.status === 'active' && styles.statusActive,
            ]}>
              <Text style={styles.statusText}>{league.status}</Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  const displayLeagues = activeTab === 'my-leagues' ? myLeagues : publicLeagues;

  if (loading) {
    return (
      <View style={styles.container}>
        <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#3B82F6" />
          <Text style={styles.loadingText}>Loading leagues...</Text>
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <LinearGradient colors={['#0f172a', '#1e3a5f', '#581c87']} style={StyleSheet.absoluteFillObject} />

      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header */}
        <View style={styles.header}>
          <Text style={styles.headerTitle}>Leagues</Text>
          <View style={styles.headerButtons}>
            <TouchableOpacity style={styles.headerButton} onPress={() => setShowJoinModal(true)}>
              <MaterialCommunityIcons name="login" size={24} color="#3B82F6" />
            </TouchableOpacity>
            <TouchableOpacity style={styles.headerButton} onPress={() => setShowCreateModal(true)}>
              <MaterialCommunityIcons name="plus-circle-outline" size={24} color="#10B981" />
            </TouchableOpacity>
          </View>
        </View>

        {/* Tabs */}
        <View style={styles.tabsContainer}>
          <TouchableOpacity
            style={[styles.tab, activeTab === 'my-leagues' && styles.activeTab]}
            onPress={() => setActiveTab('my-leagues')}
          >
            <MaterialCommunityIcons
              name="trophy-outline"
              size={18}
              color={activeTab === 'my-leagues' ? '#3B82F6' : '#9CA3AF'}
            />
            <Text style={[styles.tabText, activeTab === 'my-leagues' && styles.activeTabText]}>
              My Leagues
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.tab, activeTab === 'discover' && styles.activeTab]}
            onPress={() => setActiveTab('discover')}
          >
            <MaterialCommunityIcons
              name="compass-outline"
              size={18}
              color={activeTab === 'discover' ? '#3B82F6' : '#9CA3AF'}
            />
            <Text style={[styles.tabText, activeTab === 'discover' && styles.activeTabText]}>
              Discover
            </Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#3B82F6" />}
          showsVerticalScrollIndicator={false}
        >
          {error ? (
            <View style={styles.errorContainer}>
              <MaterialCommunityIcons name="alert-circle-outline" size={48} color="#EF4444" />
              <Text style={styles.errorText}>{error}</Text>
              <TouchableOpacity style={styles.retryButton} onPress={fetchLeagues}>
                <Text style={styles.retryButtonText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : displayLeagues.length === 0 ? (
            <View style={styles.emptyContainer}>
              <MaterialCommunityIcons name="account-group-outline" size={64} color="#4B5563" />
              <Text style={styles.emptyTitle}>
                {activeTab === 'my-leagues' ? 'No leagues yet' : 'No public leagues found'}
              </Text>
              <Text style={styles.emptySubtext}>
                {activeTab === 'my-leagues'
                  ? 'Create a league or join one to compete with friends!'
                  : 'Check back later for public leagues to join'}
              </Text>
              {activeTab === 'my-leagues' && (
                <View style={styles.emptyActions}>
                  <TouchableOpacity
                    style={styles.emptyButton}
                    onPress={() => setShowCreateModal(true)}
                  >
                    <LinearGradient colors={['#10B981', '#059669']} style={styles.emptyButtonGradient}>
                      <MaterialCommunityIcons name="plus" size={20} color="#FFFFFF" />
                      <Text style={styles.emptyButtonText}>Create League</Text>
                    </LinearGradient>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.emptyButton}
                    onPress={() => setShowJoinModal(true)}
                  >
                    <LinearGradient colors={['#3B82F6', '#1D4ED8']} style={styles.emptyButtonGradient}>
                      <MaterialCommunityIcons name="login" size={20} color="#FFFFFF" />
                      <Text style={styles.emptyButtonText}>Join League</Text>
                    </LinearGradient>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          ) : (
            displayLeagues.map((league) => renderLeagueCard(league, activeTab === 'discover'))
          )}

          <View style={{ height: 100 }} />
        </ScrollView>
      </SafeAreaView>

      {/* Create League Modal */}
      <Modal visible={showCreateModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <LinearGradient colors={['#1e293b', '#0f172a']} style={StyleSheet.absoluteFillObject} />

            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Create League</Text>
              <TouchableOpacity onPress={() => setShowCreateModal(false)}>
                <MaterialCommunityIcons name="close" size={24} color="#9CA3AF" />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody}>
              <Text style={styles.inputLabel}>League Name *</Text>
              <TextInput
                style={styles.textInput}
                placeholder="Enter league name"
                placeholderTextColor="#6B7280"
                value={newLeagueName}
                onChangeText={setNewLeagueName}
              />

              <Text style={styles.inputLabel}>Description</Text>
              <TextInput
                style={[styles.textInput, styles.textArea]}
                placeholder="Describe your league (optional)"
                placeholderTextColor="#6B7280"
                value={newLeagueDescription}
                onChangeText={setNewLeagueDescription}
                multiline
                numberOfLines={3}
              />

              <TouchableOpacity
                style={styles.toggleRow}
                onPress={() => setNewLeaguePrivate(!newLeaguePrivate)}
              >
                <View style={styles.toggleInfo}>
                  <MaterialCommunityIcons
                    name={newLeaguePrivate ? 'lock-closed' : 'earth'}
                    size={24}
                    color={newLeaguePrivate ? '#8B5CF6' : '#3B82F6'}
                  />
                  <View style={styles.toggleText}>
                    <Text style={styles.toggleTitle}>
                      {newLeaguePrivate ? 'Private League' : 'Public League'}
                    </Text>
                    <Text style={styles.toggleSubtitle}>
                      {newLeaguePrivate
                        ? 'Only people with the code can join'
                        : 'Anyone can discover and join'}
                    </Text>
                  </View>
                </View>
                <View style={[styles.toggle, newLeaguePrivate && styles.toggleActive]}>
                  <View style={[styles.toggleKnob, newLeaguePrivate && styles.toggleKnobActive]} />
                </View>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.createButton}
                onPress={createLeague}
                disabled={creating}
              >
                <LinearGradient colors={['#10B981', '#059669']} style={styles.createButtonGradient}>
                  {creating ? (
                    <ActivityIndicator color="#FFFFFF" />
                  ) : (
                    <>
                      <MaterialCommunityIcons name="plus-circle" size={20} color="#FFFFFF" />
                      <Text style={styles.createButtonText}>Create League</Text>
                    </>
                  )}
                </LinearGradient>
              </TouchableOpacity>
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* Join League Modal */}
      <Modal visible={showJoinModal} animationType="fade" transparent>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { maxHeight: '40%' }]}>
            <LinearGradient colors={['#1e293b', '#0f172a']} style={StyleSheet.absoluteFillObject} />

            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Join League</Text>
              <TouchableOpacity onPress={() => setShowJoinModal(false)}>
                <MaterialCommunityIcons name="close" size={24} color="#9CA3AF" />
              </TouchableOpacity>
            </View>

            <View style={styles.modalBody}>
              <Text style={styles.inputLabel}>League Code</Text>
              <TextInput
                style={styles.textInput}
                placeholder="Enter join code"
                placeholderTextColor="#6B7280"
                value={joinCode}
                onChangeText={setJoinCode}
                autoCapitalize="characters"
              />

              <TouchableOpacity
                style={styles.createButton}
                onPress={() => joinLeague(undefined, joinCode)}
                disabled={joining || !joinCode.trim()}
              >
                <LinearGradient colors={['#3B82F6', '#1D4ED8']} style={styles.createButtonGradient}>
                  {joining ? (
                    <ActivityIndicator color="#FFFFFF" />
                  ) : (
                    <>
                      <MaterialCommunityIcons name="login" size={20} color="#FFFFFF" />
                      <Text style={styles.createButtonText}>Join League</Text>
                    </>
                  )}
                </LinearGradient>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* League Detail Modal */}
      <Modal visible={showDetailModal} animationType="slide" transparent>
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { height: '80%' }]}>
            <LinearGradient colors={['#1e293b', '#0f172a']} style={StyleSheet.absoluteFillObject} />

            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setShowDetailModal(false)}>
                <MaterialCommunityIcons name="arrow-back" size={24} color="#FFFFFF" />
              </TouchableOpacity>
              <Text style={styles.modalTitle}>{selectedLeague?.name || 'League'}</Text>
              <View style={{ width: 24 }} />
            </View>

            {detailLoading ? (
              <View style={styles.loadingContainer}>
                <ActivityIndicator size="large" color="#3B82F6" />
              </View>
            ) : (
              <ScrollView style={styles.modalBody} showsVerticalScrollIndicator={false}>
                {selectedLeague?.description && (
                  <Text style={styles.leagueDetailDescription}>{selectedLeague.description}</Text>
                )}

                <View style={styles.leagueStats}>
                  <View style={styles.leagueStat}>
                    <MaterialCommunityIcons name="people" size={20} color="#3B82F6" />
                    <Text style={styles.leagueStatValue}>{selectedLeague?.member_count || 0}</Text>
                    <Text style={styles.leagueStatLabel}>Members</Text>
                  </View>
                  <View style={styles.leagueStat}>
                    <MaterialCommunityIcons name="calendar" size={20} color="#10B981" />
                    <Text style={styles.leagueStatValue}>{formatDate(selectedLeague?.start_date)}</Text>
                    <Text style={styles.leagueStatLabel}>Start Date</Text>
                  </View>
                </View>

                <Text style={styles.sectionTitle}>Leaderboard</Text>

                {leagueMembers.length === 0 ? (
                  <View style={styles.noMembers}>
                    <Text style={styles.noMembersText}>No members yet</Text>
                  </View>
                ) : (
                  leagueMembers.map((member, index) => (
                    <View key={member.user_id} style={styles.memberRow}>
                      <View style={styles.memberRank}>
                        <Text style={styles.memberRankText}>{member.rank || index + 1}</Text>
                      </View>
                      <View style={styles.memberInfo}>
                        <Text style={styles.memberName}>{member.username}</Text>
                        {member.profit_loss_percent !== undefined && (
                          <Text style={[
                            styles.memberPL,
                            { color: (member.profit_loss_percent || 0) >= 0 ? '#10B981' : '#EF4444' }
                          ]}>
                            {(member.profit_loss_percent || 0) >= 0 ? '+' : ''}
                            {(member.profit_loss_percent || 0).toFixed(2)}%
                          </Text>
                        )}
                      </View>
                      {member.total_value !== undefined && (
                        <Text style={styles.memberValue}>
                          £{((member.total_value || 0) / 100).toLocaleString()}
                        </Text>
                      )}
                    </View>
                  ))
                )}

                <View style={{ height: 40 }} />
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  loadingText: { color: '#9CA3AF', fontSize: 16, marginTop: 12 },
  safeArea: { flex: 1 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  headerTitle: { color: '#FFFFFF', fontSize: 28, fontWeight: 'bold' },
  headerButtons: { flexDirection: 'row' },
  headerButton: { marginLeft: 16, padding: 4 },
  tabsContainer: { flexDirection: 'row', paddingHorizontal: 20, marginBottom: 16 },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 12,
    marginRight: 10,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  activeTab: { backgroundColor: 'rgba(59, 130, 246, 0.2)', borderColor: '#3B82F6' },
  tabText: { color: '#9CA3AF', fontSize: 14, fontWeight: '600', marginLeft: 8 },
  activeTabText: { color: '#3B82F6' },
  scrollView: { flex: 1 },
  scrollContent: { paddingHorizontal: 20 },
  errorContainer: { alignItems: 'center', paddingVertical: 60 },
  errorText: { color: '#EF4444', fontSize: 16, marginTop: 16, textAlign: 'center' },
  retryButton: {
    marginTop: 20,
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#3B82F6',
  },
  retryButtonText: { color: '#3B82F6', fontSize: 14, fontWeight: '600' },
  emptyContainer: { alignItems: 'center', paddingVertical: 60 },
  emptyTitle: { color: '#FFFFFF', fontSize: 20, fontWeight: 'bold', marginTop: 20 },
  emptySubtext: { color: '#9CA3AF', fontSize: 14, marginTop: 8, textAlign: 'center', paddingHorizontal: 20 },
  emptyActions: { flexDirection: 'row', marginTop: 24, gap: 12 },
  emptyButton: { borderRadius: 12, overflow: 'hidden' },
  emptyButtonGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 14,
  },
  emptyButtonText: { color: '#FFFFFF', fontSize: 14, fontWeight: '600', marginLeft: 8 },
  leagueCard: {
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
  },
  leagueCardHeader: { flexDirection: 'row', alignItems: 'center' },
  leagueIconContainer: { marginRight: 12 },
  leagueIcon: {
    width: 44,
    height: 44,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  leagueInfo: { flex: 1 },
  leagueName: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold' },
  leagueMembers: { color: '#9CA3AF', fontSize: 13, marginTop: 2 },
  joinButton: {
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3B82F6',
  },
  joinButtonText: { color: '#3B82F6', fontSize: 13, fontWeight: '600' },
  leagueDescription: { color: '#D1D5DB', fontSize: 13, marginTop: 12, lineHeight: 18 },
  leagueFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: 'rgba(75, 85, 99, 0.3)',
  },
  leagueCreator: { color: '#6B7280', fontSize: 12 },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 8,
    backgroundColor: 'rgba(107, 114, 128, 0.2)',
  },
  statusActive: { backgroundColor: 'rgba(16, 185, 129, 0.2)' },
  statusText: { color: '#10B981', fontSize: 11, fontWeight: '600', textTransform: 'capitalize' },
  // Modal styles
  modalOverlay: { flex: 1, backgroundColor: 'rgba(0,0,0,0.7)', justifyContent: 'flex-end' },
  modalContent: { maxHeight: '70%', borderTopLeftRadius: 24, borderTopRightRadius: 24, overflow: 'hidden' },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  modalTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold' },
  modalBody: { padding: 20 },
  inputLabel: { color: '#9CA3AF', fontSize: 14, marginBottom: 8 },
  textInput: {
    backgroundColor: 'rgba(31, 41, 55, 0.8)',
    borderRadius: 12,
    padding: 16,
    color: '#FFFFFF',
    fontSize: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 16,
  },
  textArea: { minHeight: 80, textAlignVertical: 'top' },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 16,
    borderTopWidth: 1,
    borderTopColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 20,
  },
  toggleInfo: { flexDirection: 'row', alignItems: 'center', flex: 1 },
  toggleText: { marginLeft: 12 },
  toggleTitle: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  toggleSubtitle: { color: '#9CA3AF', fontSize: 12, marginTop: 2 },
  toggle: {
    width: 50,
    height: 28,
    borderRadius: 14,
    backgroundColor: 'rgba(75, 85, 99, 0.5)',
    padding: 2,
  },
  toggleActive: { backgroundColor: '#8B5CF6' },
  toggleKnob: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
  },
  toggleKnobActive: { marginLeft: 22 },
  createButton: { borderRadius: 12, overflow: 'hidden', marginTop: 8 },
  createButtonGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
  },
  createButtonText: { color: '#FFFFFF', fontSize: 16, fontWeight: '600', marginLeft: 8 },
  // League detail styles
  leagueDetailDescription: {
    color: '#D1D5DB',
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 20,
  },
  leagueStats: { flexDirection: 'row', marginBottom: 24 },
  leagueStat: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 16,
    marginRight: 12,
  },
  leagueStatValue: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginTop: 8 },
  leagueStatLabel: { color: '#9CA3AF', fontSize: 12, marginTop: 4 },
  sectionTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginBottom: 16 },
  noMembers: { alignItems: 'center', paddingVertical: 20 },
  noMembersText: { color: '#9CA3AF', fontSize: 14 },
  memberRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
  },
  memberRank: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  memberRankText: { color: '#3B82F6', fontSize: 14, fontWeight: 'bold' },
  memberInfo: { flex: 1 },
  memberName: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
  memberPL: { fontSize: 12, marginTop: 2 },
  memberValue: { color: '#FFFFFF', fontSize: 14, fontWeight: '600' },
});
