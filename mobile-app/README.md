# Trading App Mobile

React Native Expo mobile application for the UK trading platform.

## Features

✅ **Authentication**
- JWT-based authentication with main app backend
- Registration with age verification
- Secure login/logout

✅ **Portfolio Management**  
- Multi-portfolio support (weekly, monthly, annual, practice)
- Real-time portfolio balance and P&L tracking
- Holdings management with detailed views
- Transaction history

✅ **Trading System**
- Live stock trading with market hours validation
- Buy/sell orders with concentration limits
- Pending orders when market is closed
- Real-time price updates

✅ **Stock Discovery**
- Top 100 UK stocks browser
- Advanced search and filtering
- Sort by risers/fallers, market cap, A-Z
- Real-time stock quotes and charts

✅ **Leaderboards & Competitions**
- Portfolio type-specific leaderboards
- Competition tracking and rankings
- User position and performance metrics
- Prize pool information

✅ **Community Features**
- Discussion forums and posts
- Stock-specific conversations
- Like and comment system
- User profiles and interactions

## 🛠️ Tech Stack

- **React Native** with Expo
- **TypeScript** for type safety
- **React Navigation** for navigation
- **AsyncStorage** for local data persistence
- **Expo Vector Icons** for UI icons
- **React Native Elements** for UI components

## 🚀 Getting Started

### Prerequisites

- Node.js (v16 or later)
- npm or yarn
- Expo CLI: `npm install -g @expo/cli`
- Expo Go app on your mobile device (for testing)

### Installation

1. **Navigate to the mobile app directory:**
   ```bash
   cd trading-app-mobile
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Update API configuration:**
   - Edit `src/services/api.ts`
   - Update `API_BASE_URL` to point to your backend server

4. **Start the development server:**
   ```bash
   npm start
   ```

5. **Run on device/simulator:**
   ```bash
   # For iOS simulator
   npm run ios
   
   # For Android emulator
   npm run android
   
   # For web browser
   npm run web
   ```

## 📱 Testing on Device

1. Install the **Expo Go** app on your phone
2. Scan the QR code from the terminal/browser
3. The app will load on your device

## 🏗️ Project Structure

```
src/
├── components/           # Reusable UI components
│   ├── ui/              # Generic UI components
│   ├── portfolio/       # Portfolio-specific components
│   ├── stocks/          # Stock-related components
│   └── community/       # Community components
├── screens/             # Screen components
│   ├── auth/           # Authentication screens
│   ├── dashboard/      # Dashboard screen
│   ├── portfolio/      # Portfolio screens
│   ├── stocks/         # Stock screens
│   ├── community/      # Community screens
│   └── settings/       # Settings screens
├── navigation/         # Navigation configuration
├── hooks/             # Custom React hooks
├── services/          # API services
├── types/            # TypeScript type definitions
└── utils/           # Utility functions
```

## 🔗 API Integration

The mobile app connects to the same backend as the web application. Make sure your backend server is running and accessible.

### API Endpoints Used

- `POST /api/auth/login` - User authentication
- `POST /api/auth/register` - User registration
- `GET /api/stocks/search` - Stock search
- `GET /api/stocks/ftse100` - FTSE 100 data
- `GET /api/stocks/ftse250` - FTSE 250 data
- `POST /api/stocks/batch-prices` - Batch price updates

## 📱 Building for Production

### For App Store (iOS)

1. **Install EAS CLI:**
   ```bash
   npm install -g @expo/cli eas-cli
   ```

2. **Configure EAS:**
   ```bash
   eas login
   eas build:configure
   ```

3. **Build for iOS:**
   ```bash
   eas build --platform ios
   ```

### For Google Play Store (Android)

1. **Build for Android:**
   ```bash
   eas build --platform android
   ```

2. **Generate AAB file:**
   ```bash
   eas build --platform android --profile production
   ```

## 🎨 Customization

### Theme Colors

The app uses a consistent color scheme:
- Primary: `#3B82F6` (Blue)
- Secondary: `#10B981` (Green)
- Accent: `#8B5CF6` (Purple)
- Error: `#EF4444` (Red)

### Adding New Screens

1. Create a new screen in the appropriate `src/screens/` directory
2. Add the route to `src/navigation/AppNavigator.tsx`
3. Update type definitions in `src/types/index.ts`

## 🚧 Future Enhancements

- **Push Notifications**: Real-time price alerts and market updates
- **Advanced Charts**: Interactive candlestick and technical analysis charts
- **News Integration**: Real-time financial news and analysis
- **Watchlists**: Personal stock tracking and alerts
- **Social Features**: Follow other traders and copy strategies
- **Advanced Orders**: Stop-loss, limit orders, and conditional trading

## 🔒 Security

- API calls are secured with authentication tokens
- Sensitive data is stored securely using AsyncStorage
- Input validation on all user inputs
- Secure HTTP requests only

## 📝 Environment Variables

Create a `.env` file in the root directory:

```env
API_BASE_URL=https://your-api-url.com
EXPO_PROJECT_ID=your-expo-project-id
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on both iOS and Android
5. Submit a pull request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

For support and questions, please contact the development team.