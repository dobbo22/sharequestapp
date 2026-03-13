import { Tabs } from 'expo-router';
import { View, StyleSheet, Platform } from 'react-native';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from '../../src/components/ui/BlurView';
import { colors } from '../../src/lib/theme';

type MCIcon = keyof typeof MaterialCommunityIcons.glyphMap;

const ACTIVE_COLOR = '#4AAEE8';
const INACTIVE_COLOR = '#6B7280';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: MCIcon;

          switch (route.name) {
            case 'index':
              iconName = focused ? 'view-dashboard' : 'view-dashboard-outline';
              break;
            case 'portfolio':
              iconName = focused ? 'briefcase' : 'briefcase-outline';
              break;
            case 'stocks':
              iconName = focused ? 'chart-line' : 'chart-line-variant';
              break;
            case 'leagues':
              iconName = focused ? 'account-group' : 'account-group-outline';
              break;
            case 'leaderboards':
              iconName = focused ? 'trophy' : 'trophy-outline';
              break;
            case 'profile':
              iconName = focused ? 'account-circle' : 'account-circle-outline';
              break;
            default:
              iconName = 'help-circle-outline';
          }

          return (
            <View style={[styles.iconContainer, focused && styles.activeIconContainer]}>
              <MaterialCommunityIcons name={iconName} size={size} color={color} />
              {focused && <View style={styles.activeIndicator} />}
            </View>
          );
        },
        tabBarActiveTintColor: ACTIVE_COLOR,
        tabBarInactiveTintColor: INACTIVE_COLOR,
        tabBarLabelStyle: {
          fontSize: 10,
          fontWeight: '600',
          marginTop: 2,
        },
        tabBarBackground: () => (
          <BlurView intensity={95} style={StyleSheet.absoluteFillObject}>
            <LinearGradient
              colors={['rgba(30, 58, 95, 0.97)', 'rgba(17, 24, 39, 0.97)']}
              style={StyleSheet.absoluteFillObject}
            />
          </BlurView>
        ),
        tabBarStyle: {
          position: 'absolute',
          bottom: 0,
          left: 0,
          right: 0,
          elevation: 8,
          backgroundColor: 'transparent',
          borderTopWidth: 1,
          borderTopColor: 'rgba(75, 85, 99, 0.3)',
          height: Platform.OS === 'ios' ? 85 : 65,
          paddingBottom: Platform.OS === 'ios' ? 25 : 10,
          paddingTop: 8,
          borderTopLeftRadius: 20,
          borderTopRightRadius: 20,
        },
        headerShown: false,
      })}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
        }}
      />
      <Tabs.Screen
        name="portfolio"
        options={{
          title: 'Portfolio',
        }}
      />
      <Tabs.Screen
        name="stocks"
        options={{
          title: 'Stocks',
        }}
      />
      <Tabs.Screen
        name="leagues"
        options={{
          title: 'Leagues',
        }}
      />
      <Tabs.Screen
        name="leaderboards"
        options={{
          title: 'Leaders',
        }}
      />
      <Tabs.Screen
        name="aiert-index"
        options={{
          title: 'SQ Index',
        }}
      />
      <Tabs.Screen
        name="StockScoreDetail"
        options={{
          title: 'Stock Detail',
          presentation: 'modal',
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  iconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 2,
  },
  activeIconContainer: {
    transform: [{ scale: 1.15 }],
  },
  activeIndicator: {
    width: 5,
    height: 5,
    borderRadius: 2.5,
    backgroundColor: ACTIVE_COLOR,
    marginTop: 3,
  },
});
