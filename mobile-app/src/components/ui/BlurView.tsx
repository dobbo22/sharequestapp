// Fallback BlurView component for compatibility
import React from 'react';
import { View, ViewStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';

interface BlurViewProps {
  intensity?: number;
  style?: ViewStyle;
  children?: React.ReactNode;
}

export const BlurView: React.FC<BlurViewProps> = ({ 
  intensity = 100, 
  style, 
  children 
}) => {
  // Calculate opacity based on intensity
  const opacity = Math.min(intensity / 100, 0.95);
  
  return (
    <View style={style}>
      <LinearGradient
        colors={[
          `rgba(17, 24, 39, ${opacity * 0.9})`,
          `rgba(31, 41, 55, ${opacity * 0.95})`
        ]}
        style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
      />
      {children}
    </View>
  );
};