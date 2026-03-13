import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { AuthRequest, ResponseType, makeRedirectUri } from 'expo-auth-session';
import * as WebBrowser from 'expo-web-browser';
import * as AuthSession from 'expo-auth-session';
import * as Linking from 'expo-linking';
import { useRouter } from 'expo-router';

const PROVIDERS = [
  {
    name: 'Google',
    provider: 'google',
    icon: 'logo-google' as const,
    bg: '#FFFFFF',
    iconColor: '#4285F4',
    textColor: '#333',
    border: '#E5E7EB',
  },
  {
    name: 'Facebook',
    provider: 'facebook',
    icon: 'logo-facebook' as const,
    bg: '#1877F2',
    iconColor: '#FFFFFF',
    textColor: '#FFFFFF',
    border: '#1877F2',
  },
  {
    name: 'LinkedIn',
    provider: 'linkedin',
    icon: 'logo-linkedin' as const,
    bg: '#0A66C2',
    iconColor: '#FFFFFF',
    textColor: '#FFFFFF',
    border: '#0A66C2',
  },
];

export function SocialLoginButtons({ callbackUrl = '/' }: { callbackUrl?: string }) {
  const router = useRouter();

  // Google OAuth config
  const googleRedirectUri = makeRedirectUri({ scheme: 'sharequest' });
  const googleClientId = '<YOUR_GOOGLE_CLIENT_ID>';
  const googleDiscovery = {
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
    revocationEndpoint: 'https://oauth2.googleapis.com/revoke',
  };
  const [googleRequest, googleResponse, googlePromptAsync] = AuthSession.useAuthRequest(
    {
      clientId: googleClientId,
      redirectUri: googleRedirectUri,
      responseType: ResponseType.Code,
      scopes: ['openid', 'profile', 'email'],
    },
    googleDiscovery
  );

  // Facebook OAuth config
  const facebookRedirectUri = makeRedirectUri({ scheme: 'sharequest' });
  const facebookClientId = '<YOUR_FACEBOOK_CLIENT_ID>';
  const facebookDiscovery = {
    authorizationEndpoint: 'https://www.facebook.com/v18.0/dialog/oauth',
    tokenEndpoint: 'https://graph.facebook.com/v18.0/oauth/access_token',
  };
  const [facebookRequest, facebookResponse, facebookPromptAsync] = AuthSession.useAuthRequest(
    {
      clientId: facebookClientId,
      redirectUri: facebookRedirectUri,
      responseType: ResponseType.Code,
      scopes: ['public_profile', 'email'],
    },
    facebookDiscovery
  );

  // LinkedIn OAuth config
  const linkedinRedirectUri = makeRedirectUri({ scheme: 'sharequest' });
  const linkedinClientId = '<YOUR_LINKEDIN_CLIENT_ID>';
  const linkedinDiscovery = {
    authorizationEndpoint: 'https://www.linkedin.com/oauth/v2/authorization',
    tokenEndpoint: 'https://www.linkedin.com/oauth/v2/accessToken',
  };
  const [linkedinRequest, linkedinResponse, linkedinPromptAsync] = AuthSession.useAuthRequest(
    {
      clientId: linkedinClientId,
      redirectUri: linkedinRedirectUri,
      responseType: ResponseType.Code,
      scopes: ['r_liteprofile', 'r_emailaddress'],
    },
    linkedinDiscovery
  );

  React.useEffect(() => {
    // Google
    if (googleResponse?.type === 'success' && googleResponse.params?.code) {
      (async () => {
        try {
          const callbackRes = await fetch(`https://sharequest.co.uk/api/auth/callback/google?code=${encodeURIComponent(googleResponse.params.code)}&redirect=false`, {
            method: 'GET',
            credentials: 'include',
          });
          if (callbackRes.ok) {
            router.replace('/');
          } else {
            alert('Google login failed. Please try again.');
          }
        } catch {
          alert('Google login failed. Please try again.');
        }
      })();
    }
    // Facebook
    if (facebookResponse?.type === 'success' && facebookResponse.params?.code) {
      (async () => {
        try {
          const callbackRes = await fetch(`https://sharequest.co.uk/api/auth/callback/facebook?code=${encodeURIComponent(facebookResponse.params.code)}&redirect=false`, {
            method: 'GET',
            credentials: 'include',
          });
          if (callbackRes.ok) {
            router.replace('/');
          } else {
            alert('Facebook login failed. Please try again.');
          }
        } catch {
          alert('Facebook login failed. Please try again.');
        }
      })();
    }
    // LinkedIn
    if (linkedinResponse?.type === 'success' && linkedinResponse.params?.code) {
      (async () => {
        try {
          const callbackRes = await fetch(`https://sharequest.co.uk/api/auth/callback/linkedin?code=${encodeURIComponent(linkedinResponse.params.code)}&redirect=false`, {
            method: 'GET',
            credentials: 'include',
          });
          if (callbackRes.ok) {
            router.replace('/');
          } else {
            alert('LinkedIn login failed. Please try again.');
          }
        } catch {
          alert('LinkedIn login failed. Please try again.');
        }
      })();
    }
  }, [googleResponse, facebookResponse, linkedinResponse]);

  const openOAuth = async (provider: string) => {
    if (provider === 'google') {
      await googlePromptAsync();
    } else if (provider === 'facebook') {
      await facebookPromptAsync();
    } else if (provider === 'linkedin') {
      await linkedinPromptAsync();
    } else {
      const url = `https://sharequest.co.uk/api/auth/signin/${provider}?callbackUrl=${encodeURIComponent(callbackUrl)}`;
      Linking.openURL(url);
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.heading}>Continue with</Text>
      <View style={styles.column}>
        {PROVIDERS.map((p) => (
          <TouchableOpacity
            key={p.name}
            onPress={() => openOAuth(p.provider)}
            accessibilityLabel={`Continue with ${p.name}`}
            style={[styles.button, { backgroundColor: p.bg, borderColor: p.border }]}
          >
            <Ionicons name={p.icon} size={22} color={p.iconColor} />
            <Text style={[styles.buttonText, { color: p.textColor }]}>Continue with {p.name}</Text>
          </TouchableOpacity>
        ))}
      </View>
      <View style={styles.divider}>
        <View style={styles.dividerLine} />
        <Text style={styles.dividerText}>or</Text>
        <View style={styles.dividerLine} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingTop: 8,
    paddingBottom: 8,
  },
  heading: {
    color: '#9CA3AF',
    fontSize: 13,
    textAlign: 'center',
    marginBottom: 14,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  column: {
    gap: 10,
  },
  button: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderRadius: 12,
    borderWidth: 1,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  buttonText: {
    fontWeight: '600',
    fontSize: 16,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
    marginBottom: 4,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: 'rgba(75, 85, 99, 0.5)',
  },
  dividerText: {
    color: '#6B7280',
    fontSize: 12,
    marginHorizontal: 16,
    textTransform: 'uppercase',
  },
});
