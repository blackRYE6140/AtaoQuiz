import 'package:flutter/material.dart';
import '../../theme/colors.dart';


/// HEADER : Illustration étudiant malgache

class HomeHeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Tongasoa e!\nPrêt à apprendre en jouant ?",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Image.asset(
            "assets/illustrations/student_welcome.png",
            height: 90,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}


/// CARD GÉNÉRIQUE : Section PDF / Quiz / WiFi / Challenge

class HomeSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;

  const HomeSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
        ),

        child: Row(
          children: [
            // Illustration — fond + image sans crop
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark
                    ? AppColors.gray800
                    : AppColors.gray100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.accentYellow
                          : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkText.withOpacity(0.7)
                          : AppColors.lightText.withOpacity(0.7),
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
