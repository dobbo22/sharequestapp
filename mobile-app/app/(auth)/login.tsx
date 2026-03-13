import React from 'react';
import { SocialLoginButtons } from '../../components/SocialLoginButtons';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Dimensions, Image } from 'react-native';
import { useRouter } from 'expo-router';
import { LinearGradient } from 'expo-linear-gradient';
const { width, height } = Dimensions.get('window');

export default function LoginScreen() {
  const router = useRouter();
  return (
    <View style={{ flex: 1 }}>
      <LinearGradient
        colors={['#0f172a', '#1e3a8a', '#581c87']}
        locations={[0, 0.5, 1]}
        style={StyleSheet.absoluteFillObject}
      />
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'center', alignItems: 'center', padding: 24 }}
        showsVerticalScrollIndicator={false}
      >
        <View style={{ alignItems: 'center', marginBottom: 24 }}>
          <Image
            source={require('../../assets/sharequest-splash.png')}
            style={{ width: width - 48, height: 70, marginBottom: 24, borderRadius: 16 }}
            resizeMode="contain"
          />
        </View>
        <View style={{ width: '100%', maxWidth: 400, backgroundColor: 'rgba(17,24,39,0.85)', borderRadius: 20, padding: 24, alignItems: 'center' }}>
          <SocialLoginButtons callbackUrl="/" />
          <TouchableOpacity
            style={{ backgroundColor: '#3B82F6', paddingVertical: 14, borderRadius: 8, marginTop: 24, width: '100%', alignItems: 'center' }}
            onPress={() => router.push('/(auth)/manual-signin')}
          >
            <Text style={{ color: '#fff', fontSize: 18, fontWeight: 'bold' }}>Manual sign in</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
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
    width: 320,
    height: 320,
    backgroundColor: 'rgba(59, 130, 246, 0.1)',
    top: -160,
    right: -160,
  },
  blob2: {
    width: 320,
    height: 320,
    backgroundColor: 'rgba(139, 92, 246, 0.1)',
    bottom: -160,
    left: -160,
  },
  blob3: {
    width: 384,
    height: 384,
    backgroundColor: 'rgba(34, 197, 94, 0.05)',
    top: '50%',
    left: '50%',
    marginTop: -192,
    marginLeft: -192,
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 24,
    paddingVertical: 48,
    minHeight: height,
  },
  header: {
    alignItems: 'center',
    marginBottom: 8,
  },
  logoContainer: {
    width: width - 48,
    height: 70,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
    overflow: 'hidden',
    borderRadius: 16,
  },
  logoImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'contain',
  },
  card: {
    backgroundColor: 'rgba(17, 24, 39, 0.8)',
    borderRadius: 24,
    padding: 0,
    marginBottom: 32,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    overflow: 'hidden',
  },
  errorContainer: {
    backgroundColor: 'rgba(248, 113, 113, 0.1)',
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(248, 113, 113, 0.3)',
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
  },
  errorIcon: {
    width: 32,
    height: 32,
    backgroundColor: 'rgba(248, 113, 113, 0.2)',
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  errorText: {
    color: '#FCA5A5',
    fontSize: 14,
    fontWeight: '500',
    flex: 1,
  },
  formHeader: {
    backgroundColor: 'rgba(59, 130, 246, 0.2)',
    padding: 24,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
    flexDirection: 'row',
    alignItems: 'center',
  },
  formTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
    marginLeft: 12,
  },
  fieldContainer: {
    paddingHorizontal: 32,
    paddingTop: 24,
  },
  label: {
    color: '#D1D5DB',
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 12,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    borderRadius: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  inputIcon: {
    marginRight: 12,
  },
  input: {
    flex: 1,
    color: '#FFFFFF',
    fontSize: 16,
  },
  eyeButton: {
    padding: 4,
  },
  optionsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingTop: 24,
    paddingBottom: 32,
  },
  rememberMeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 16,
    height: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.5)',
    borderRadius: 4,
    backgroundColor: 'rgba(31, 41, 55, 0.5)',
    marginRight: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  checkboxChecked: {
    backgroundColor: '#3B82F6',
    borderColor: '#3B82F6',
  },
  rememberMeText: {
    color: '#D1D5DB',
    fontSize: 14,
  },
  forgotPasswordText: {
    color: '#60A5FA',
    fontSize: 14,
    fontWeight: '500',
  },
  debugButton: {
    marginHorizontal: 32,
    marginBottom: 16,
    borderRadius: 12,
    overflow: 'hidden',
  },
  submitButton: {
    marginHorizontal: 32,
    marginBottom: 32,
    borderRadius: 12,
    overflow: 'hidden',
  },
  submitButtonDisabled: {
    opacity: 0.5,
  },
  buttonGradient: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonContent: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
    marginLeft: 8,
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  registerCard: {
    backgroundColor: 'rgba(17, 24, 39, 0.6)',
    borderRadius: 16,
    padding: 24,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.3)',
    marginBottom: 32,
  },
  registerPrompt: {
    color: '#D1D5DB',
    fontSize: 16,
    marginBottom: 16,
  },
  registerButton: {
    borderRadius: 12,
    overflow: 'hidden',
  },
  registerButtonGradient: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    flexDirection: 'row',
    alignItems: 'center',
  },
  registerButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
    marginRight: 8,
  },
  footer: {
    alignItems: 'center',
  },
  footerText: {
    color: '#9CA3AF',
    fontSize: 12,
    marginBottom: 12,
  },
  footerLinks: {
    flexDirection: 'row',
    justifyContent: 'center',
  },
  footerLink: {
    color: '#60A5FA',
    fontSize: 12,
    marginHorizontal: 24,
  },
});
