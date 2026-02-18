import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  final String displayName;
  final int avatarIndex;
  final bool isConfigured;

  const UserProfile({
    required this.displayName,
    required this.avatarIndex,
    required this.isConfigured,
  });
}

class UserProfileService extends ChangeNotifier {
  static const String promptAreaChallenge = 'challenge';
  static const String promptAreaLeaderboard = 'leaderboard';

  static const int avatarCount = 8;
  static const String defaultDisplayName = 'Moi';

  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  UserProfileService._internal();

  static const String _displayNameKey = 'user_profile_display_name_v1';
  static const String _avatarIndexKey = 'user_profile_avatar_index_v1';
  static const String _configuredKey = 'user_profile_is_configured_v1';
  static const String _challengePromptShownKey =
      'user_profile_prompt_challenge_shown_v1';
  static const String _leaderboardPromptShownKey =
      'user_profile_prompt_leaderboard_shown_v1';
  static const String _legacyChallengeNameKey =
      'challenge_local_player_name_v1';

  UserProfile? _cachedProfile;

  UserProfile get profileOrDefault {
    return _cachedProfile ??
        const UserProfile(
          displayName: defaultDisplayName,
          avatarIndex: 0,
          isConfigured: false,
        );
  }

  Future<UserProfile> getProfile() async {
    final cached = _cachedProfile;
    if (cached != null) {
      return cached;
    }
    final loaded = await _loadProfileFromPrefs();
    _cachedProfile = loaded;
    return loaded;
  }

  Future<String> getDisplayName() async {
    return (await getProfile()).displayName;
  }

  Future<int> getAvatarIndex() async {
    return (await getProfile()).avatarIndex;
  }

  Future<bool> isProfileConfigured() async {
    return (await getProfile()).isConfigured;
  }

  Future<void> saveProfile({
    required String displayName,
    required int avatarIndex,
    bool markConfigured = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedName = normalizeDisplayName(displayName);
    final normalizedAvatar = _normalizeAvatarIndex(avatarIndex);
    final previous = await getProfile();
    final next = UserProfile(
      displayName: normalizedName,
      avatarIndex: normalizedAvatar,
      isConfigured: markConfigured || previous.isConfigured,
    );

    await prefs.setString(_displayNameKey, next.displayName);
    await prefs.setInt(_avatarIndexKey, next.avatarIndex);
    await prefs.setBool(_configuredKey, next.isConfigured);
    _cachedProfile = next;
    notifyListeners();
  }

  Future<void> updateDisplayName(String displayName) async {
    final current = await getProfile();
    await saveProfile(
      displayName: displayName,
      avatarIndex: current.avatarIndex,
      markConfigured: current.isConfigured,
    );
  }

  Future<bool> shouldPromptProfileSetupOnce({required String area}) async {
    final profile = await getProfile();
    if (profile.isConfigured) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _promptKeyForArea(area);
    final alreadyShown = prefs.getBool(key) ?? false;
    return !alreadyShown;
  }

  Future<void> markProfileSetupPromptShown({required String area}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_promptKeyForArea(area), true);
  }

  Future<UserProfile> _loadProfileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final storedName = prefs.getString(_displayNameKey);
    final legacyName = prefs.getString(_legacyChallengeNameKey);
    final storedAvatar = prefs.getInt(_avatarIndexKey);
    final storedConfigured = prefs.getBool(_configuredKey);

    final hasStoredName = storedName != null && storedName.trim().isNotEmpty;
    final hasLegacyName = legacyName != null && legacyName.trim().isNotEmpty;
    final derivedName = hasStoredName
        ? storedName
        : hasLegacyName
        ? legacyName
        : defaultDisplayName;
    final isConfigured = storedConfigured ?? hasStoredName || hasLegacyName;

    return UserProfile(
      displayName: normalizeDisplayName(derivedName),
      avatarIndex: _normalizeAvatarIndex(storedAvatar ?? 0),
      isConfigured: isConfigured,
    );
  }

  String _promptKeyForArea(String area) {
    if (area == promptAreaLeaderboard) {
      return _leaderboardPromptShownKey;
    }
    return _challengePromptShownKey;
  }

  int _normalizeAvatarIndex(int value) {
    if (value < 0) {
      return 0;
    }
    if (value >= avatarCount) {
      return value % avatarCount;
    }
    return value;
  }

  static String normalizeDisplayName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) {
      return defaultDisplayName;
    }
    if (cleaned.length == 1) {
      return cleaned.toUpperCase();
    }
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }
}
