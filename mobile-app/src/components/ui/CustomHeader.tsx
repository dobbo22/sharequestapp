import React from 'react';
import { View, Text, Image, StyleSheet, TouchableOpacity, Dimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Ionicons } from '@expo/vector-icons';
import { BlurView } from './BlurView';

const { width } = Dimensions.get('window');

interface CustomHeaderProps {
  title?: string;
  showLogo?: boolean;
  showBackButton?: boolean;
  onBackPress?: () => void;
  rightComponent?: React.ReactNode;
  subtitle?: string;
}

export const CustomHeader: React.FC<CustomHeaderProps> = ({
  title,
  showLogo = false,
  showBackButton = false,
  onBackPress,
  rightComponent,
  subtitle
}) => {
  return (
    <BlurView intensity={95} style={styles.headerContainer}>
      <LinearGradient
        colors={['rgba(30, 58, 95, 0.95)', 'rgba(17, 24, 39, 0.95)']}
        style={styles.gradient}
      >
        <View style={styles.headerContent}>
          {/* Left Section */}
          <View style={styles.leftSection}>
            {showBackButton && (
              <TouchableOpacity
                onPress={onBackPress}
                style={styles.backButton}
                activeOpacity={0.7}
              >
                <Ionicons name="arrow-back" size={24} color="white" />
              </TouchableOpacity>
            )}
            
            {showLogo && (
              <Image 
                source={require('../../../assets/sharequest-crop.png')}
                style={styles.logo}
                resizeMode="contain"
              />
            )}
          </View>

          {/* Center Section */}
          <View style={styles.centerSection}>
            {title && !showLogo && (
              <View style={styles.titleContainer}>
                <Text style={styles.title}>{title}</Text>
                {subtitle && (
                  <Text style={styles.subtitle}>{subtitle}</Text>
                )}
              </View>
            )}
          </View>

          {/* Right Section */}
          <View style={styles.rightSection}>
            {rightComponent}
          </View>
        </View>
      </LinearGradient>
    </BlurView>
  );
};

const styles = StyleSheet.create({
  headerContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
  },
  gradient: {
    paddingTop: 50, // Account for status bar
    paddingBottom: 15,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255, 255, 255, 0.1)',
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: 44,
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  centerSection: {
    flex: 2,
    alignItems: 'center',
  },
  rightSection: {
    flex: 1,
    alignItems: 'flex-end',
  },
  backButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  logo: {
    width: 140,
    height: 32,
  },
  titleContainer: {
    alignItems: 'center',
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: 'white',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 12,
    color: 'rgba(255, 255, 255, 0.7)',
    marginTop: 2,
    textAlign: 'center',
  },
});