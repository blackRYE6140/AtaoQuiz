import 'package:atao_quiz/screens/challenge/challenge_sessions_screen.dart';
import 'package:atao_quiz/screens/challenge/leaderboard_screen.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class ChallengeCenterScreen extends StatelessWidget {
  final int initialTabIndex;

  const ChallengeCenterScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;
    final tabIndex = initialTabIndex < 0 || initialTabIndex > 1
        ? 0
        : initialTabIndex;

    return DefaultTabController(
      length: 2,
      initialIndex: tabIndex,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryColor),
          title: Text(
            'Challenge & Classement',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            dividerColor: Colors.transparent,
            labelColor: primaryColor,
            unselectedLabelColor: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.sports_esports), text: 'Challenges'),
              Tab(icon: Icon(Icons.leaderboard), text: 'Classement'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ChallengeSessionsScreen(), LeaderboardScreen()],
        ),
      ),
    );
  }
}
