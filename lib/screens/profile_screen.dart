import 'package:flutter/material.dart';
import '../theme/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Mon Profil",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 👤 Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.gray800 : AppColors.gray100,
                border: Border.all(
                  color: isDark
                      ? AppColors.accentYellow
                      : AppColors.primaryBlue,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.person,
                size: 60,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),

            // Nom de l'utilisateur
            Text(
              "Utilisateur AtaoQuiz",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),

            // Email (placeholder)
            Text(
              "user@atao.quiz",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: isDark
                    ? AppColors.darkText.withOpacity(0.7)
                    : AppColors.lightText.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),

            // 📊 Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _StatRow(label: "Quiz résolus", value: "24", isDark: isDark),
                  const Divider(),
                  _StatRow(label: "Score moyen", value: "78%", isDark: isDark),
                  const Divider(),
                  _StatRow(label: "Trophées", value: "5", isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bouton Éditer le profil
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.accentYellow
                    : AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Éditer le profil",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
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

  const _StatRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: isDark
                  ? AppColors.darkText.withOpacity(0.8)
                  : AppColors.lightText.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
