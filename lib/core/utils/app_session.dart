import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sessionCountKey = 'app_session_count';
const _syncBannerDismissedKey = 'sync_banner_dismissed';

/// Increments the app session counter on each cold start / foreground.
Future<int> incrementSessionCount() async {
  final prefs = await SharedPreferences.getInstance();
  final next = (prefs.getInt(_sessionCountKey) ?? 0) + 1;
  await prefs.setInt(_sessionCountKey, next);
  return next;
}

Future<int> sessionCount() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_sessionCountKey) ?? 0;
}

Future<bool> isSyncBannerDismissed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_syncBannerDismissedKey) ?? false;
}

Future<void> dismissSyncBanner() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_syncBannerDismissedKey, true);
}

bool isGuestUser() {
  final user = FirebaseAuth.instance.currentUser;
  return user == null || user.isAnonymous;
}

const _onboardingCompleteKey = 'onboarding_complete';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingCompleteKey) ?? false;
}

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingCompleteKey, true);
}

const _widgetPromptShownKey = 'widget_prompt_shown';

Future<bool> wasWidgetPromptShown() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_widgetPromptShownKey) ?? false;
}

Future<void> markWidgetPromptShown() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_widgetPromptShownKey, true);
}

const _calculatorUseCountKey = 'calculator_use_count';

Future<int> incrementCalculatorUseCount() async {
  final prefs = await SharedPreferences.getInstance();
  final next = (prefs.getInt(_calculatorUseCountKey) ?? 0) + 1;
  await prefs.setInt(_calculatorUseCountKey, next);
  return next;
}
