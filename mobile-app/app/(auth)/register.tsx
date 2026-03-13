import React, { useState } from 'react';
import { SocialLoginButtons } from '../../components/SocialLoginButtons';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  Alert,
  ScrollView,
  Dimensions,
  Image,
  ActivityIndicator,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAuth } from '../../src/hooks/useAuth';
import { LinearGradient } from 'expo-linear-gradient';

const { width } = Dimensions.get('window');

export default function RegisterScreen() {
    const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    first_name: '',
    last_name: '',
    username: '',
    email: '',
    password: '',
    confirmPassword: '',
    date_of_birth: '',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [passwordStrength, setPasswordStrength] = useState({ score: 0, feedback: '' });
  const [ageValidation, setAgeValidation] = useState<{
    isValid: boolean;
    age: number;
    error?: string;
  } | null>(null);

  const router = useRouter();
  const { signUp, loading, error } = useAuth();

  const checkPasswordStrength = (password: string) => {
    if (!password) {
      setPasswordStrength({ score: 0, feedback: '' });
      return;
    }

    let score = 0;
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (/[A-Z]/.test(password)) score += 1;
    if (/[0-9]/.test(password)) score += 1;
    if (/[^A-Za-z0-9]/.test(password)) score += 1;

    let feedback = '';
    if (score < 3) feedback = 'Weak password. Add numbers, symbols, or uppercase letters.';
    else if (score < 5) feedback = 'Good password, but could be stronger.';
    else feedback = 'Strong password!';

    setPasswordStrength({ score, feedback });
  };

  const validateAge = (dateOfBirth: string) => {
    if (!dateOfBirth) return null;

    const today = new Date();
    const birthDate = new Date(dateOfBirth);
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      age--;
    }

    return {
      isValid: age >= 18,
      age,
      error: age < 18 ? 'You must be 18 or older to register' : undefined,
    };
  };

  const handleChange = (field: string, value: string | boolean) => {
    setFormData((prev) => ({ ...prev, [field]: value }));

    if (field === 'password' && typeof value === 'string') {
      checkPasswordStrength(value);
    }

    if (field === 'date_of_birth' && typeof value === 'string' && value) {
      setAgeValidation(validateAge(value));
    }
  };

  const handleSubmit = async () => {
    if (
      !formData.first_name ||
      !formData.last_name ||
      !formData.username ||
      !formData.email ||
      !formData.password ||
      !formData.confirmPassword
    ) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    if (!formData.date_of_birth) {
      Alert.alert('Error', 'Date of birth is required to verify you are 18 or older');
      return;
    }

    const ageCheck = validateAge(formData.date_of_birth);
    if (!ageCheck || !ageCheck.isValid) {
      Alert.alert('Age Verification Failed', ageCheck?.error || 'Age verification failed');
      return;
    }

    if (formData.password !== formData.confirmPassword) {
      Alert.alert('Error', 'Passwords do not match');
      return;
    }

    if (formData.password.length < 8) {
      Alert.alert('Error', 'Password must be at least 8 characters long');
      return;
    }

    if (passwordStrength.score < 3) {
      Alert.alert('Error', 'Please use a stronger password');
      return;
    }

    const success = await signUp(formData.email, formData.username, formData.password, {
      first_name: formData.first_name,
      last_name: formData.last_name,
      date_of_birth: formData.date_of_birth,
    });

    if (success) {
      // Store a persistent flag/cookie that user has registered
      try {
        const AsyncStorage = (await import('@react-native-async-storage/async-storage')).default;
        await AsyncStorage.setItem('has_account', 'true');
      } catch (e) {
        console.warn('Failed to set has_account flag:', e);
      }
      Alert.alert('Registration Successful', 'Your account has been created successfully!', [
        { text: 'OK', onPress: () => router.replace('/(tabs)') },
      ]);
    } else if (error) {
      Alert.alert('Registration Failed', error);
    }
  };

  const getStrengthColor = () => {
    if (passwordStrength.score < 3) return '#EF4444';
    if (passwordStrength.score < 5) return '#F59E0B';
    return '#10B981';
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <LinearGradient
        colors={['#0f172a', '#1e3a8a', '#581c87']}
        locations={[0, 0.5, 1]}
        style={StyleSheet.absoluteFillObject}
      />

      <View style={styles.backgroundEffects}>
        <View style={[styles.blob, styles.blob1]} />
        <View style={[styles.blob, styles.blob2]} />
      </View>

      <ScrollView
        contentContainerStyle={styles.scrollContent}
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.header}>
          <View style={styles.logoContainer}>
            <Image
              source={require('../../assets/sharequest-splash.png')}
              style={styles.logoImage}
              resizeMode="contain"
            />
          </View>
        </View>

        {/* Main Card */}
        <View style={styles.card}>
          {/* Social Register Buttons */}
          <SocialLoginButtons callbackUrl="/" />
          {error && (
            <View style={styles.errorContainer}>
              <View style={styles.errorIcon}>
                <Ionicons name="warning" size={16} color="#F87171" />
              </View>
              <Text style={styles.errorText}>{error}</Text>
            </View>
          )}

          <View style={styles.formHeader}>
            <Ionicons name="person-add-outline" size={24} color="#A78BFA" />
            <Text style={styles.formTitle}>Create Account</Text>
          </View>

          {!showForm && (
            <TouchableOpacity
              style={[styles.submitButton, { marginTop: 24 }]}
              onPress={() => setShowForm(true)}
            >
              <LinearGradient colors={['#8B5CF6', '#7C3AED']} style={styles.buttonGradient}>
                <View style={styles.buttonContent}>
                  <Ionicons name="person-add-outline" size={20} color="#FFFFFF" />
                  <Text style={styles.buttonText}>Create Account</Text>
                </View>
              </LinearGradient>
            </TouchableOpacity>
          )}

          {showForm && (
            <View style={styles.formContent}>
              {/* Name Fields */}
              <View style={styles.row}>
                <View style={styles.halfField}>
                  <Text style={styles.label}>First Name *</Text>
                  <View style={styles.inputContainer}>
                    <TextInput
                      style={styles.input}
                      placeholder="First name"
                      placeholderTextColor="#6B7280"
                      value={formData.first_name}
                      onChangeText={(v) => handleChange('first_name', v)}
                      editable={!loading}
                    />
                  </View>
                </View>
                <View style={styles.halfField}>
                  <Text style={styles.label}>Last Name *</Text>
                  <View style={styles.inputContainer}>
                    <TextInput
                      style={styles.input}
                      placeholder="Last name"
                      placeholderTextColor="#6B7280"
                      value={formData.last_name}
                      onChangeText={(v) => handleChange('last_name', v)}
                      editable={!loading}
                    />
                  </View>
                </View>
              </View>

              {/* Username */}
              <View style={styles.fieldContainer}>
                <Text style={styles.label}>Username *</Text>
                <View style={styles.inputContainer}>
                  <Ionicons name="at-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
                  <TextInput
                    style={styles.input}
                    placeholder="Choose a unique username"
                    placeholderTextColor="#6B7280"
                    value={formData.username}
                    onChangeText={(v) => handleChange('username', v)}
                    autoCapitalize="none"
                    editable={!loading}
                  />
                </View>
              </View>

              {/* Email */}
              <View style={styles.fieldContainer}>
                <Text style={styles.label}>Email Address *</Text>
                <View style={styles.inputContainer}>
                  <Ionicons name="mail-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
                  <TextInput
                    style={styles.input}
                    placeholder="Enter your email"
                    placeholderTextColor="#6B7280"
                    value={formData.email}
                    onChangeText={(v) => handleChange('email', v)}
                    keyboardType="email-address"
                    autoCapitalize="none"
                    editable={!loading}
                  />
                </View>
              </View>

              {/* Date of Birth */}
              <View style={styles.fieldContainer}>
                <Text style={styles.label}>
                  Date of Birth * <Text style={styles.labelNote}>(Required for age verification)</Text>
                </Text>
                <View style={styles.inputContainer}>
                  <Ionicons name="calendar-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
                  <TextInput
                    style={styles.input}
                    placeholder="YYYY-MM-DD"
                    placeholderTextColor="#6B7280"
                    value={formData.date_of_birth}
                    onChangeText={(v) => handleChange('date_of_birth', v)}
                    editable={!loading}
                  />
                </View>
                {ageValidation && (
                  <View style={styles.validationContainer}>
                    {ageValidation.isValid ? (
                      <View style={styles.validationRow}>
                        <Ionicons name="checkmark-circle" size={16} color="#10B981" />
                        <Text style={styles.validText}>Age verified: {ageValidation.age} years old</Text>
                      </View>
                    ) : (
                      <View style={styles.validationRow}>
                        <Ionicons name="warning" size={16} color="#EF4444" />
                        <Text style={styles.invalidText}>{ageValidation.error}</Text>
                      </View>
                    )}
                  </View>
                )}
              </View>

              {/* Password */}
              <View style={styles.fieldContainer}>
                <Text style={styles.label}>Password *</Text>
                <View style={styles.inputContainer}>
                  <Ionicons name="lock-closed-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
                  <TextInput
                    style={styles.input}
                    placeholder="Password"
                    placeholderTextColor="#6B7280"
                    value={formData.password}
                    onChangeText={(v) => handleChange('password', v)}
                    secureTextEntry={!showPassword}
                    editable={!loading}
                  />
                  <TouchableOpacity onPress={() => setShowPassword(!showPassword)}>
                    <Ionicons
                      name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                      size={20}
                      color="#9CA3AF"
                    />
                  </TouchableOpacity>
                </View>
                {formData.password && (
                  <View style={styles.strengthContainer}>
                    <View style={styles.strengthBar}>
                      <View
                        style={[
                          styles.strengthFill,
                          {
                            width: `${(passwordStrength.score / 5) * 100}%`,
                            backgroundColor: getStrengthColor(),
                          },
                        ]}
                      />
                    </View>
                    <Text style={[styles.strengthText, { color: getStrengthColor() }]}> 
                      {passwordStrength.feedback}
                    </Text>
                  </View>
                )}
              </View>

              {/* Confirm Password */}
              <View style={styles.fieldContainer}>
                <Text style={styles.label}>Confirm Password *</Text>
                <View style={styles.inputContainer}>
                  <Ionicons name="lock-closed-outline" size={20} color="#9CA3AF" style={styles.inputIcon} />
                  <TextInput
                    style={styles.input}
                    placeholder="Confirm password"
                    placeholderTextColor="#6B7280"
                    value={formData.confirmPassword}
                    onChangeText={(v) => handleChange('confirmPassword', v)}
                    secureTextEntry={!showConfirmPassword}
                    editable={!loading}
                  />
                  <TouchableOpacity onPress={() => setShowConfirmPassword(!showConfirmPassword)}>
                    <Ionicons
                      name={showConfirmPassword ? 'eye-off-outline' : 'eye-outline'}
                      size={20}
                      color="#9CA3AF"
                    />
                  </TouchableOpacity>
                </View>
              </View>

              {/* Terms Agreement */}
              <View style={styles.termsContainer}>
                <Text style={styles.termsText}>
                  By creating an account, you confirm you are 18+ and agree to our Terms of Service and Privacy Policy.
                </Text>
              </View>

              {/* Submit Button */}
              <TouchableOpacity
                style={[
                  styles.submitButton,
                  (loading || Boolean(ageValidation && !ageValidation.isValid)) &&
                    styles.submitButtonDisabled,
                ]}
                onPress={handleSubmit}
                disabled={loading || Boolean(ageValidation && !ageValidation.isValid)}
              >
                <LinearGradient
                  colors={loading ? ['#6B7280', '#6B7280'] : ['#8B5CF6', '#7C3AED']}
                  style={styles.buttonGradient}
                >
                  {loading ? (
                    <View style={styles.loadingContainer}>
                      <ActivityIndicator color="#FFFFFF" size="small" />
                      <Text style={styles.buttonText}>Creating Account...</Text>
                    </View>
                  ) : (
                    <View style={styles.buttonContent}>
                      <Ionicons name="checkmark-circle-outline" size={20} color="#FFFFFF" />
                      <Text style={styles.buttonText}>Create Account</Text>
                    </View>
                  )}
                </LinearGradient>
              </TouchableOpacity>
            </View>
          )}
        </View>

        {/* Login Link */}
        <View style={styles.loginCard}>
          <Text style={styles.loginPrompt}>Already have an account?</Text>
          <TouchableOpacity style={styles.loginButton} onPress={() => router.push('/(auth)/login')}>
            <LinearGradient colors={['#3B82F6', '#1D4ED8']} style={styles.loginButtonGradient}>
              <Text style={styles.loginButtonText}>Sign In</Text>
              <Ionicons name="arrow-forward-outline" size={16} color="#FFFFFF" />
            </LinearGradient>
          </TouchableOpacity>
        </View>

        <View style={styles.footer}>
          <Text style={styles.footerText}>
            {new Date().getFullYear()} ShareQuest by AIERT. All rights reserved.
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  backgroundEffects: { position: 'absolute', width: '100%', height: '100%' },
  blob: { position: 'absolute', borderRadius: 200 },
  blob1: { width: 320, height: 320, backgroundColor: 'rgba(59, 130, 246, 0.1)', top: -160, right: -160 },
  blob2: { width: 320, height: 320, backgroundColor: 'rgba(139, 92, 246, 0.1)', bottom: -160, left: -160 },
  scrollContent: { flexGrow: 1, paddingHorizontal: 24, paddingVertical: 48 },
  header: { alignItems: 'center', marginBottom: 8 },
  logoContainer: { width: width - 48, height: 70, justifyContent: 'center', alignItems: 'center', marginBottom: 24, borderRadius: 16 },
  logoImage: { width: '100%', height: '100%' },
  card: { backgroundColor: 'rgba(17, 24, 39, 0.8)', borderRadius: 24, marginBottom: 32, borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.5)', overflow: 'hidden' },
  errorContainer: { backgroundColor: 'rgba(248, 113, 113, 0.1)', borderBottomWidth: 1, borderBottomColor: 'rgba(248, 113, 113, 0.3)', padding: 16, flexDirection: 'row', alignItems: 'center' },
  errorIcon: { width: 32, height: 32, backgroundColor: 'rgba(248, 113, 113, 0.2)', borderRadius: 16, justifyContent: 'center', alignItems: 'center', marginRight: 12 },
  errorText: { color: '#FCA5A5', fontSize: 14, fontWeight: '500', flex: 1 },
  formHeader: { backgroundColor: 'rgba(139, 92, 246, 0.2)', padding: 24, borderBottomWidth: 1, borderBottomColor: 'rgba(75, 85, 99, 0.3)', flexDirection: 'row', alignItems: 'center' },
  formTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: 'bold', marginLeft: 12 },
  formContent: { padding: 24 },
  row: { flexDirection: 'row', gap: 16, marginBottom: 16 },
  halfField: { flex: 1 },
  fieldContainer: { marginBottom: 16 },
  label: { color: '#D1D5DB', fontSize: 14, fontWeight: '500', marginBottom: 8 },
  labelNote: { color: '#60A5FA' },
  inputContainer: { flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(31, 41, 55, 0.5)', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.5)', borderRadius: 12, paddingHorizontal: 16, paddingVertical: 12 },
  inputIcon: { marginRight: 12 },
  input: { flex: 1, color: '#FFFFFF', fontSize: 16 },
  validationContainer: { marginTop: 8 },
  validationRow: { flexDirection: 'row', alignItems: 'center' },
  validText: { color: '#10B981', fontSize: 14, marginLeft: 8 },
  invalidText: { color: '#EF4444', fontSize: 14, marginLeft: 8 },
  strengthContainer: { marginTop: 8 },
  strengthBar: { height: 8, backgroundColor: 'rgba(75, 85, 99, 0.5)', borderRadius: 4, overflow: 'hidden' },
  strengthFill: { height: '100%', borderRadius: 4 },
  strengthText: { fontSize: 12, marginTop: 8 },
  termsContainer: { marginBottom: 24, paddingHorizontal: 4 },
  termsText: { color: '#9CA3AF', fontSize: 13, lineHeight: 18, textAlign: 'center' },
  submitButton: { borderRadius: 12, overflow: 'hidden' },
  submitButtonDisabled: { opacity: 0.5 },
  buttonGradient: { paddingVertical: 12, paddingHorizontal: 24, alignItems: 'center', justifyContent: 'center' },
  buttonContent: { flexDirection: 'row', alignItems: 'center' },
  buttonText: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold', marginLeft: 8 },
  loadingContainer: { flexDirection: 'row', alignItems: 'center' },
  loginCard: { backgroundColor: 'rgba(17, 24, 39, 0.6)', borderRadius: 16, padding: 24, alignItems: 'center', borderWidth: 1, borderColor: 'rgba(75, 85, 99, 0.3)', marginBottom: 32 },
  loginPrompt: { color: '#D1D5DB', fontSize: 16, marginBottom: 16 },
  loginButton: { borderRadius: 12, overflow: 'hidden' },
  loginButtonGradient: { paddingVertical: 12, paddingHorizontal: 24, flexDirection: 'row', alignItems: 'center' },
  loginButtonText: { color: '#FFFFFF', fontSize: 16, fontWeight: 'bold', marginRight: 8 },
  footer: { alignItems: 'center' },
  footerText: { color: '#9CA3AF', fontSize: 12 },
});
