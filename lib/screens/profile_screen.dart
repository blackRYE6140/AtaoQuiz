import 'package:atao_quiz/components/profile_avatar.dart';
import 'package:atao_quiz/services/challenge_service.dart';
import 'package:atao_quiz/services/storage_service.dart';
import 'package:atao_quiz/services/user_profile_service.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  final bool setupFlow;

  const ProfileScreen({super.key, this.setupFlow = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProfileService _profileService = UserProfileService();
  final ChallengeService _challengeService = ChallengeService();
  final StorageService _storageService = StorageService();
  final TextEditingController _nameController = TextEditingController();

  UserProfile _profile = const UserProfile(
    displayName: UserProfileService.defaultDisplayName,
    avatarIndex: 0,
    isConfigured: false,
  );
  bool _isLoading = true;
  bool _isSaving = false;
  int _solvedQuizCount = 0;
  double _averageSuccessRate = 0;
  int _trophies = 0;
  int _challengeWins = 0;
  int _timedWins = 0;

  @override
  void initState() {
    super.initState();
    _profileService.addListener(_onProfileChanged);
    _loadProfileData();
  }

  @override
  void dispose() {
    _profileService.removeListener(_onProfileChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) {
      return;
    }
    final nextProfile = _profileService.profileOrDefault;
    if (nextProfile.displayName == _profile.displayName &&
        nextProfile.avatarIndex == _profile.avatarIndex &&
        nextProfile.isConfigured == _profile.isConfigured) {
      return;
    }
    setState(() {
      _profile = nextProfile;
      _nameController.text = nextProfile.displayName;
    });
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _profileService.getProfile();
      final quizzes = await _storageService.getQuizzes();
      final leaderboard = await _challengeService.getLeaderboard();

      final solvedQuizzes = quizzes
          .where((quiz) => quiz.score != null && quiz.questionCount > 0)
          .toList();
      final solvedCount = solvedQuizzes.length;
      final practiceAverage = solvedCount == 0
          ? 0.0
          : solvedQuizzes
                    .map(
                      (quiz) => (quiz.score! / quiz.questionCount)
                          .clamp(0, 1)
                          .toDouble(),
                    )
                    .reduce((sum, item) => sum + item) /
                solvedCount;

      LeaderboardEntry? localEntry;
      for (final entry in leaderboard) {
        if (entry.playerName.toLowerCase() ==
            profile.displayName.toLowerCase()) {
          localEntry = entry;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _nameController.text = profile.displayName;
        _solvedQuizCount = solvedCount;
        _averageSuccessRate = localEntry?.averageSuccessRate ?? practiceAverage;
        _challengeWins = localEntry?.challengeWins ?? 0;
        _timedWins = localEntry?.timedChallengeWins ?? 0;
        _trophies = _challengeWins + _timedWins;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) {
      _showMessage('Le nom du profil est obligatoire.', isError: true);
      return;
    }

    final previousName = _profile.displayName;
    final normalizedName = UserProfileService.normalizeDisplayName(rawName);
    setState(() => _isSaving = true);

    try {
      await _profileService.saveProfile(
        displayName: normalizedName,
        avatarIndex: _profile.avatarIndex,
        markConfigured: true,
      );

      if (previousName.toLowerCase() != normalizedName.toLowerCase()) {
        await _challengeService.renamePlayerInAllSessions(
          oldName: previousName,
          newName: normalizedName,
        );
      }

      await _loadProfileData();
      if (!mounted) {
        return;
      }
      _showMessage('Profil mis à jour.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage('Impossible de sauvegarder le profil: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAvatar(Color primaryColor, bool isDark) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(color: primaryColor.withValues(alpha: 0.24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisir une image',
                style: TextStyle(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: profileAvatarOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.96,
                ),
                itemBuilder: (context, index) {
                  final selected = _profile.avatarIndex == index;
                  final option = profileAvatarByIndex(index);
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(sheetContext, index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? primaryColor
                              : primaryColor.withValues(alpha: 0.24),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ProfileAvatar(
                            avatarIndex: index,
                            radius: 14,
                            accentColor: primaryColor,
                            borderWidth: 1.2,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontFamily: 'Poppins',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _profile = UserProfile(
        displayName: _profile.displayName,
        avatarIndex: selected,
        isConfigured: _profile.isConfigured,
      );
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryColor),
        title: Text(
          'Mon Profil',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              color: primaryColor,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  if (widget.setupFlow)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: primaryColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Text(
                        'Configuration initiale: ajoutez votre nom et votre image.',
                        style: TextStyle(
                          color: textColor,
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _pickAvatar(primaryColor, isDark),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ProfileAvatar(
                                avatarIndex: _profile.avatarIndex,
                                radius: 52,
                                accentColor: primaryColor,
                                borderWidth: 2.4,
                              ),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Nom du profil',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryColor.withValues(alpha: 0.30),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryColor.withValues(alpha: 0.30),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Enregistrer le profil'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      children: [
                        _StatRow(
                          label: 'Quiz résolus',
                          value: '$_solvedQuizCount',
                          accentColor: primaryColor,
                          isDark: isDark,
                        ),
                        Divider(color: primaryColor.withValues(alpha: 0.16)),
                        _StatRow(
                          label: 'Score moyen',
                          value:
                              '${(_averageSuccessRate * 100).toStringAsFixed(0)}%',
                          accentColor: primaryColor,
                          isDark: isDark,
                        ),
                        Divider(color: primaryColor.withValues(alpha: 0.16)),
                        _StatRow(
                          label: 'Trophées',
                          value: '$_trophies',
                          accentColor: primaryColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Victoires: $_challengeWins • Chrono: $_timedWins',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontFamily: 'Poppins',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color accentColor;

  const _StatRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
