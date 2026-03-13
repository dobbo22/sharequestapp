
import React from 'react';
import { View, Text, StyleSheet, Image, Dimensions } from 'react-native';
import { useRouter } from 'expo-router';
import { FlatList, Animated } from 'react-native';
import { TouchableOpacity } from 'react-native-gesture-handler';
import AsyncStorage from '@react-native-async-storage/async-storage';

const SLIDES = [
  {
    title: 'Practice Trading',
    description: 'Trade stocks with virtual money and build your skills risk-free.',
    image: require('../assets/sharequest-splash.png'),
  },
  {
    title: 'Compete in Leagues',
    description: 'Join competitions, climb leaderboards, and win rewards.',
    image: require('../assets/sharequest-crop.png'),
  },
  {
    title: 'Learn & Earn',
    description: 'Access tutorials, improve your knowledge, and earn badges.',
    image: require('../assets/splash-icon.png'),
  },
];

const { width } = Dimensions.get('window');
const DOT_SIZE = 10;
const DOT_SPACING = 8;
const DOT_COLOR_ACTIVE = '#3B82F6';
const DOT_COLOR_INACTIVE = '#b0c4de';

export default function OnboardingCarousel() {
  const router = useRouter();
  const scrollX = React.useRef(new Animated.Value(0)).current;
  const [currentIndex, setCurrentIndex] = React.useState(0);

  const renderItem = ({ item }) => (
    <View style={styles.slide}>
      <Image source={item.image} style={styles.image} />
      <View style={styles.textTile}>
        <Text style={styles.title}>{item.title}</Text>
        <Text style={styles.description}>{item.description}</Text>
      </View>
    </View>
  );

  return (
    <View style={styles.container}>
      <View style={{ flex: 1, justifyContent: 'center', alignItems: 'center' }}>
        <FlatList
          data={SLIDES}
          renderItem={renderItem}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          keyExtractor={(_, idx) => idx.toString()}
          onScroll={Animated.event(
            [{ nativeEvent: { contentOffset: { x: scrollX } } }],
            { useNativeDriver: false }
          )}
          onMomentumScrollEnd={e => {
            const index = Math.round(e.nativeEvent.contentOffset.x / width);
            setCurrentIndex(index);
          }}
          style={{ marginTop: 40 }}
          snapToInterval={width}
          decelerationRate="fast"
          contentContainerStyle={{ alignItems: 'center' }}
          getItemLayout={(_, index) => ({ length: width, offset: width * index, index })}
        />
      </View>
      <View style={styles.dotsContainer}>
        {SLIDES.map((_, idx) => (
          <View
            key={idx}
            style={{
              width: DOT_SIZE,
              height: DOT_SIZE,
              borderRadius: DOT_SIZE / 2,
              marginHorizontal: DOT_SPACING / 2,
              backgroundColor:
                idx === currentIndex ? DOT_COLOR_ACTIVE : DOT_COLOR_INACTIVE,
            }}
          />
        ))}
      </View>
      <TouchableOpacity style={styles.button} onPress={async () => {
        await AsyncStorage.removeItem('pending_xp');
        router.replace('/first-trade');
      }}>
        <Text style={styles.buttonText}>Get Started</Text>
      </TouchableOpacity>
      <TouchableOpacity style={styles.skipButton} onPress={() => {
        router.replace('/(auth)/login');
      }}>
        <Text style={styles.skipButtonText}>Skip to Login</Text>
      </TouchableOpacity>
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
  slide: {
    width: width,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  image: {
    width: 280,
    height: 280,
    resizeMode: 'contain',
    marginBottom: 24,
    marginTop: -40,
  },
  textTile: {
    backgroundColor: '#182848',
    borderRadius: 16,
    paddingVertical: 20,
    paddingHorizontal: 24,
    alignItems: 'center',
    width: width - 48,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 8,
  },
  description: {
    fontSize: 16,
    color: '#b0c4de',
    textAlign: 'center',
  },
  dotsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 16,
    marginBottom: 16,
  },
  button: {
    backgroundColor: '#3B82F6',
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: 8,
    marginTop: 16,
  },
  buttonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  skipButton: {
    marginTop: 16,
    marginBottom: 24,
    paddingVertical: 8,
    paddingHorizontal: 16,
  },
  skipButtonText: {
    color: '#6B7280',
    fontSize: 14,
  },
});
