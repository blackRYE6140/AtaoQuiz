import 'package:atao_quiz/components/home_components.dart';
import 'package:atao_quiz/screens/generatequiz/quiz_list_screen.dart';
import 'package:atao_quiz/screens/pdf/pdf_list_screen.dart';
import 'package:atao_quiz/screens/profile_screen.dart';
import 'package:atao_quiz/screens/settings_screen.dart';
import 'package:atao_quiz/screens/transfer_quiz/transfer_quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:atao_quiz/theme/colors.dart';

class HomeScreen extends StatelessWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  final ThemeMode? currentThemeMode;

  const HomeScreen({super.key, this.onThemeModeChanged, this.currentThemeMode});

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
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Center(
            child: Text(
              "AtaoQuiz",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
                height: 1.0,
              ),
            ),
          ),
        ),
        leadingWidth: 128,
        actions: [
          //  Profile icon
          IconButton(
            icon: Icon(
              Icons.account_circle,
              color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),

          // ☰ Menu icon (settings)
          IconButton(
            icon: Icon(
              Icons.menu,
              color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              size: 28,
            ),
            onPressed: () {
              // Dans la navigation vers SettingsScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onThemeModeChanged: onThemeModeChanged,
                    currentThemeMode: currentThemeMode,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------------------
            //  WELCOME BANNER
            // ----------------------------------------------------------------
            HomeHeaderCard(),

            const SizedBox(height: 25),

            // ----------------------------------------------------------------
            //  SECTIONS (PDF / QUIZ / TRANSFERT)
            // ----------------------------------------------------------------
            Text(
              "Vos modules",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            HomeSectionCard(
              title: "Documents & Lecture",
              subtitle: "Transformez vos PDF en leçons faciles à lire",
              imagePath: "assets/illustrations/pdf_reader.png",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PdfListScreen(),
                  ),
                );
              },
            ),

            HomeSectionCard(
              title: "Quiz générés",
              subtitle: "Questions à 4 choix basées sur vos documents",
              imagePath: "assets/illustrations/quiz_4_choices.png",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuizListScreen(),
                  ),
                );
              },
            ),

            HomeSectionCard(
              title: "Partage via Wi-Fi",
              subtitle: "Envoyez des cours entre téléphones",
              imagePath: "assets/illustrations/file_transfer.png",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransferQuizScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // ----------------------------------------------------------------
            //  COMPETITION & SCORE
            // ----------------------------------------------------------------
            Text(
              "Challenge & Score",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),

            const SizedBox(height: 12),

            HomeSectionCard(
              title: "Classement & Challenge",
              subtitle: "Faites des quiz contre vos amis",
              imagePath: "assets/illustrations/competition.png",
              onTap: () {},
            ),

            HomeSectionCard(
              title: "Mes Scores",
              subtitle: "Gagnez des trophées et progressez !",
              imagePath: "assets/illustrations/trophy_success.png",
              onTap: () {},
            ),

            const SizedBox(height: 11),
          ],
        ),
      ),
    );
  }
}
