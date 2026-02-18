import 'dart:async';

import 'package:atao_quiz/services/challenge_service.dart';
import 'package:atao_quiz/services/user_profile_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/components/profile_avatar.dart';
import 'package:atao_quiz/screens/profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final ChallengeService _challengeService = ChallengeService();
  final UserProfileService _profileService = UserProfileService();

  List<LeaderboardEntry> _entries = [];
  UserProfile _profile = const UserProfile(
    displayName: UserProfileService.defaultDisplayName,
    avatarIndex: 0,
    isConfigured: false,
  );
  bool _isLoading = true;
  bool _profilePromptHandled = false;

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_onProfileChanged);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _profileService.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) {
      return;
    }
    final profile = _profileService.profileOrDefault;
    if (profile.displayName == _profile.displayName &&
        profile.avatarIndex == _profile.avatarIndex &&
        profile.profileImageBase64 == _profile.profileImageBase64 &&
        profile.isConfigured == _profile.isConfigured) {
      return;
    }
    setState(() => _profile = profile);
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileService.getProfile();
      final entries = await _challengeService.getLeaderboard();

      if (!mounted) {
        return;
      }

      setState(() {
        _entries = entries;
        _profile = profile;
        _isLoading = false;
      });
      unawaited(_ensureProfileConfiguredOnce());
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      unawaited(_ensureProfileConfiguredOnce());
    }
  }

  Future<void> _ensureProfileConfiguredOnce() async {
    if (_profilePromptHandled) {
      return;
    }
    _profilePromptHandled = true;

    final shouldPrompt = await _profileService.shouldPromptProfileSetupOnce(
      area: UserProfileService.promptAreaLeaderboard,
    );
    if (!shouldPrompt || !mounted) {
      return;
    }

    await _profileService.markProfileSetupPromptShown(
      area: UserProfileService.promptAreaLeaderboard,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          title: Text(
            'Profil requis',
            style: TextStyle(
              color: textColor,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Configurez votre profil pour synchroniser le classement.',
            style: TextStyle(color: textColor, fontFamily: 'Poppins'),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.person),
              label: const Text('Configurer'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen(setupFlow: true)),
    );
    await _loadLeaderboard();
  }

  BoxDecoration _cardDecoration(bool isDark, Color primaryColor) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      border: Border.all(color: primaryColor.withValues(alpha: 0.32)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) {
      return const Color(0xFFFFC107);
    }
    if (rank == 2) {
      return const Color(0xFFB0BEC5);
    }
    if (rank == 3) {
      return const Color(0xFFCD7F32);
    }
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    LeaderboardEntry? localEntry;
    for (final entry in _entries) {
      if (entry.playerName.toLowerCase() ==
          _profile.displayName.toLowerCase()) {
        localEntry = entry;
        break;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (localEntry != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mon niveau',
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(
                            avatarIndex: _profile.avatarIndex,
                            imageBase64: _profile.profileImageBase64,
                            radius: 18,
                            accentColor: primaryColor,
                          ),
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Lv.${localEntry.level}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${localEntry.playerName} • Rang #${localEntry.rank}',
                          style: TextStyle(color: textColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: localEntry.levelProgress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(primaryColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${localEntry.pointsIntoLevel}/${localEntry.pointsForNextLevel} points vers le niveau suivant',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total: ${localEntry.points} pts • ${localEntry.challengeWins} victoire(s) challenge'
                    ' • ${localEntry.timedChallengeWins} victoire(s) chrono'
                    '${localEntry.averageCompletionDurationMs == null ? '' : ' • Vitesse moy.: ${_formatDuration(localEntry.averageCompletionDurationMs!)}'}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Text(
                'Aucune progression enregistrée pour le moment.',
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Classement global',
            style: TextStyle(
              color: textColor,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(isDark, primaryColor),
              child: Text(
                'Aucun joueur classé.',
                style: TextStyle(color: secondaryTextColor),
              ),
            )
          else
            ..._entries.map((entry) {
              final rankColor = _rankColor(entry.rank);
              final percent = (entry.averageSuccessRate * 100).toStringAsFixed(
                0,
              );
              final isLocal =
                  entry.playerName.toLowerCase() ==
                  _profile.displayName.toLowerCase();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: _cardDecoration(isDark, primaryColor),
                child: ListTile(
                  leading: isLocal
                      ? ProfileAvatar(
                          avatarIndex: _profile.avatarIndex,
                          imageBase64: _profile.profileImageBase64,
                          radius: 18,
                          accentColor: primaryColor,
                        )
                      : CircleAvatar(
                          backgroundColor: rankColor.withValues(alpha: 0.18),
                          child: Text(
                            '${entry.rank}',
                            style: TextStyle(
                              color: rankColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  title: Text(
                    isLocal ? '${entry.playerName} (Moi)' : entry.playerName,
                    style: TextStyle(
                      color: textColor,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Lv.${entry.level} • ${entry.points} pts • '
                    '${entry.challengeWins} victoire(s)\n'
                    'Challenges: ${entry.challengesPlayed} • Chrono: ${entry.timedChallengesPlayed} • Entraînements: ${entry.practiceRuns} • '
                    'Réussite moyenne: $percent%'
                    '${entry.averageCompletionDurationMs == null ? '' : ' • Vitesse: ${_formatDuration(entry.averageCompletionDurationMs!)}'}',
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _formatDuration(int durationMs) {
    if (durationMs <= 0) {
      return '--';
    }
    final minutes = durationMs ~/ 60000;
    final seconds = (durationMs % 60000) ~/ 1000;
    final centiseconds = (durationMs % 1000) ~/ 10;
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '$seconds.${centiseconds.toString().padLeft(2, '0')}s';
  }
}
