---
title: Mobile
nav_order: 9
parent: Templates
---
# CLAUDE.md — React Native / Mobile Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your framework and platform targets -->
This is a React Native project using TypeScript. Target platforms: iOS and Android. Use functional components with hooks exclusively. All code must pass TypeScript strict mode.

## Navigation

<!-- Navigation library and patterns -->
- React Navigation for all routing
- Type-safe navigation: define `RootStackParamList` and use `NativeStackScreenProps`
- Deep linking config lives in `src/navigation/linking.ts`
- Keep navigation logic out of components — use navigation hooks

## State Management

<!-- How state is organized -->
- Local state (`useState`) for component-specific UI state
- React Context for auth state, theme, and user preferences
- React Query / TanStack Query for all server state (API data)
- Never store derived data in state — compute it
- Persist critical state with AsyncStorage (auth tokens, preferences)

## Platform-Specific Code

<!-- How to handle iOS/Android differences -->
- Use `Platform.select()` for minor differences (padding, shadows)
- Use `.ios.tsx` / `.android.tsx` file extensions for major platform divergence
- Test on both platforms before declaring any UI change done
- Shadow styles: use `elevation` on Android, `shadowX` properties on iOS

## Styling

<!-- Styling approach -->
- StyleSheet.create for all styles — no inline style objects
- Design tokens in `src/theme/` — colors, spacing, typography, shadows
- Responsive sizing: use `Dimensions` or `useWindowDimensions`, not hardcoded pixels
- Safe area: wrap screens with `SafeAreaView` or use `useSafeAreaInsets`
- No web CSS patterns — use Flexbox as React Native implements it

## Performance

<!-- Performance patterns -->
- Use `React.memo()` for list items and expensive components
- `FlatList` for all lists — never map + ScrollView for dynamic content
- `useCallback` for functions passed to child components or FlatList
- Avoid anonymous functions in `renderItem` — extract named components
- Images: use `FastImage` or equivalent for caching, specify dimensions

## Testing

<!-- Testing approach -->
- React Native Testing Library for component tests
- Jest for unit tests on business logic
- Detox or Maestro for E2E tests on critical user flows
- Test on real devices for performance-sensitive features
- Mock native modules in `jest.setup.js`

## Common Pitfalls

<!-- Things that frequently go wrong -->
- Don't use `console.log` in production — use a logging library with log levels
- Don't hardcode status bar height — use SafeAreaView
- Don't forget to handle keyboard avoiding for forms
- Don't assume fast network — handle loading, error, and offline states
- Don't ignore the Android back button — test back navigation on every screen
- Metro bundler cache issues: `npx react-native start --reset-cache`

## Build & Deploy

<!-- Build conventions -->
- iOS: `npx react-native run-ios` for dev, Xcode archive for release
- Android: `npx react-native run-android` for dev, `./gradlew assembleRelease` for release
- Check that native dependencies are linked: `npx react-native config`
- After adding native modules: `cd ios && pod install && cd ..`
- Environment configs: use `react-native-config` for `.env` management

## Verification

<!-- What to check before declaring done -->
- App builds and runs on both iOS and Android simulators
- TypeScript: `npx tsc --noEmit` passes
- Tests: `npm test` passes
- No yellow box warnings in dev mode
- Test on at least one physical device for UI/UX changes

## Git & GitHub

<!-- Safety rules -->
- Do not push code or create PRs without explicit permission
- Do not perform destructive or irreversible operations without asking first
- Never commit `ios/Pods/` or `android/.gradle/` directories
