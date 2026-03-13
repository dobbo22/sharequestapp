import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  Alert,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import { useAuth } from '../src/hooks/useAuth';
import { apiService } from '../src/services/api';

export default function EditProfileScreen() {
  const router = useRouter();
  const { user, updateUser } = useAuth();

  const [firstName, setFirstName] = useState(user?.first_name || '');
  const [lastName, setLastName] = useState(user?.last_name || '');
  const [username, setUsername] = useState(user?.username || '');
  const [avatarUri, setAvatarUri] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const currentAvatarUrl = user?.avatar_url;

  const pickImage = async () => {
    Alert.alert('Change Photo', 'Choose a source', [
      {
        text: 'Camera',
        onPress: async () => {
          const { status } = await ImagePicker.requestCameraPermissionsAsync();
          if (status !== 'granted') {
            Alert.alert('Permission needed', 'Camera access is required to take a photo.');
            return;
          }
          const result = await ImagePicker.launchCameraAsync({
            allowsEditing: true,
            aspect: [1, 1],
            quality: 0.8,
          });
          if (!result.canceled && result.assets[0]) {
            setAvatarUri(result.assets[0].uri);
          }
        },
      },
      {
        text: 'Gallery',
        onPress: async () => {
          const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
          if (status !== 'granted') {
            Alert.alert('Permission needed', 'Photo library access is required.');
            return;
          }
          const result = await ImagePicker.launchImageLibraryAsync({
            mediaTypes: ['images'],
            allowsEditing: true,
            aspect: [1, 1],
            quality: 0.8,
          });
          if (!result.canceled && result.assets[0]) {
            setAvatarUri(result.assets[0].uri);
          }
        },
      },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  const handleSave = async () => {
    if (!username.trim()) {
      Alert.alert('Error', 'Username is required.');
      return;
    }

    setSaving(true);
    try {
      // Update profile fields
      const profileResponse = await apiService.updateProfile({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        username: username.trim(),
      });

      if (!profileResponse.success) {
        Alert.alert('Error', profileResponse.error || 'Failed to update profile.');
        setSaving(false);
        return;
      }

      // Upload avatar if changed
      let newAvatarUrl = currentAvatarUrl;
      if (avatarUri) {
        const avatarResponse = await apiService.uploadAvatar(avatarUri);
        if (avatarResponse.success && avatarResponse.data) {
          newAvatarUrl = avatarResponse.data.avatarUrl;
        } else {
          Alert.alert('Warning', 'Profile updated but avatar upload failed.');
        }
      }

      // Update local auth context
      await updateUser({
        username: username.trim(),
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        avatar_url: newAvatarUrl,
      });

      router.back();
    } catch (err) {
      Alert.alert('Error', 'Something went wrong. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const displayAvatar = avatarUri || currentAvatarUrl;
  const initial = username?.charAt(0)?.toUpperCase() || user?.email?.charAt(0)?.toUpperCase() || 'U';

  return (
    <SafeAreaView style={styles.container}>
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        {/* Header */}
        <View style={styles.header}>
          <TouchableOpacity onPress={() => router.back()} style={styles.backButton}>
            <MaterialCommunityIcons name="chevron-left" size={28} color="#FFFFFF" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Edit Profile</Text>
          <View style={{ width: 28 }} />
        </View>

        <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
          {/* Avatar */}
          <TouchableOpacity onPress={pickImage} style={styles.avatarSection}>
            <View style={styles.avatarWrapper}>
              {displayAvatar ? (
                <Image source={{ uri: displayAvatar }} style={styles.avatarImage} />
              ) : (
                <LinearGradient colors={['#3B82F6', '#8B5CF6']} style={styles.avatarFallback}>
                  <Text style={styles.avatarInitial}>{initial}</Text>
                </LinearGradient>
              )}
              <View style={styles.cameraOverlay}>
                <MaterialCommunityIcons name="camera" size={18} color="#FFFFFF" />
              </View>
            </View>
            <Text style={styles.changePhotoText}>Change Photo</Text>
          </TouchableOpacity>

          {/* Form */}
          <View style={styles.formSection}>
            <View style={styles.inputGroup}>
              <Text style={styles.label}>First Name</Text>
              <TextInput
                style={styles.input}
                value={firstName}
                onChangeText={setFirstName}
                placeholder="Enter first name"
                placeholderTextColor="#6B7280"
                autoCapitalize="words"
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.label}>Last Name</Text>
              <TextInput
                style={styles.input}
                value={lastName}
                onChangeText={setLastName}
                placeholder="Enter last name"
                placeholderTextColor="#6B7280"
                autoCapitalize="words"
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.label}>Username</Text>
              <TextInput
                style={styles.input}
                value={username}
                onChangeText={setUsername}
                placeholder="Enter username"
                placeholderTextColor="#6B7280"
                autoCapitalize="none"
                autoCorrect={false}
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.label}>Email</Text>
              <TextInput
                style={[styles.input, styles.inputDisabled]}
                value={user?.email || ''}
                editable={false}
              />
              <Text style={styles.helperText}>Email cannot be changed</Text>
            </View>
          </View>

          {/* Save Button */}
          <TouchableOpacity
            style={[styles.saveButton, saving && styles.saveButtonDisabled]}
            onPress={handleSave}
            disabled={saving}
          >
            {saving ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.saveButtonText}>Save Changes</Text>
            )}
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0f172a',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(75, 85, 99, 0.3)',
  },
  backButton: {
    padding: 4,
  },
  headerTitle: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '700',
  },
  content: {
    padding: 24,
    paddingBottom: 60,
  },
  avatarSection: {
    alignItems: 'center',
    marginBottom: 32,
  },
  avatarWrapper: {
    width: 100,
    height: 100,
    borderRadius: 50,
    position: 'relative',
  },
  avatarImage: {
    width: 100,
    height: 100,
    borderRadius: 50,
  },
  avatarFallback: {
    width: 100,
    height: 100,
    borderRadius: 50,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarInitial: {
    color: '#FFFFFF',
    fontSize: 36,
    fontWeight: 'bold',
  },
  cameraOverlay: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#3B82F6',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: '#0f172a',
  },
  changePhotoText: {
    color: '#3B82F6',
    fontSize: 14,
    fontWeight: '600',
    marginTop: 12,
  },
  formSection: {
    gap: 20,
  },
  inputGroup: {},
  label: {
    color: '#D1D5DB',
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 8,
  },
  input: {
    backgroundColor: 'rgba(31, 41, 55, 0.6)',
    borderRadius: 12,
    padding: 14,
    color: '#FFFFFF',
    fontSize: 16,
    borderWidth: 1,
    borderColor: 'rgba(75, 85, 99, 0.4)',
  },
  inputDisabled: {
    opacity: 0.5,
  },
  helperText: {
    color: '#6B7280',
    fontSize: 12,
    marginTop: 4,
  },
  saveButton: {
    backgroundColor: '#3B82F6',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    marginTop: 32,
  },
  saveButtonDisabled: {
    opacity: 0.6,
  },
  saveButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '700',
  },
});
