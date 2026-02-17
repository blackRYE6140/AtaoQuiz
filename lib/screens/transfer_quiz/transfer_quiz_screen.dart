import 'package:atao_quiz/screens/transfer_quiz/receive_quiz_screen.dart';
import 'package:atao_quiz/screens/transfer_quiz/send_quiz_screen.dart';
import 'package:atao_quiz/theme/colors.dart';
import 'package:flutter/material.dart';

class TransferQuizScreen extends StatelessWidget {
  const TransferQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? AppColors.accentYellow
        : AppColors.primaryBlue;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryColor),
          title: Text(
            'Transfert de quiz',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            tabs: const [
              Tab(icon: Icon(Icons.send), text: 'Envoyer'),
              Tab(icon: Icon(Icons.download), text: 'Recevoir'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [SendQuizScreen(), ReceiveQuizScreen()],
        ),
      ),
    );
  }
}
