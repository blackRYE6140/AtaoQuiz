import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  final ThemeMode? currentThemeMode;

  const SettingsScreen({
    super.key,
    this.onThemeModeChanged,
    this.currentThemeMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // État local pour suivre la sélection manuelle (null = pas de choix manuel)
  ThemeMode? _localThemeMode;

  @override
  void initState() {
    super.initState();
    // Initialize local selection: if parent provided a manual mode, use it; if parent is system, keep null
    if (widget.currentThemeMode != null &&
        widget.currentThemeMode != ThemeMode.system) {
      _localThemeMode = widget.currentThemeMode;
    } else {
      _localThemeMode = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // brightness appliquée par le thème actuel
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Mode effectif : priorité -> choix local (_localThemeMode) -> valeur passée depuis parent -> défaut light
    final ThemeMode effectiveMode =
        _localThemeMode ?? widget.currentThemeMode ?? ThemeMode.light;

    // Déterminer l'état du switch à afficher
    final bool isDarkModeEnabled = effectiveMode == ThemeMode.dark;

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
          "Paramètres",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //  Mode Sombre / Clair
            _SettingsSectionTitle("Apparence", isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.brightness_4,
              title: "Mode sombre",
              trailing: Switch(
                value: isDarkModeEnabled,
                onChanged: (value) {
                  // L'utilisateur force le mode : light ou dark
                  final ThemeMode newMode = value
                      ? ThemeMode.dark
                      : ThemeMode.light;
                  setState(() {
                    _localThemeMode = newMode;
                  });
                  // Propager au parent pour appliquer globalement
                  widget.onThemeModeChanged?.call(newMode);
                },
                activeColor: AppColors.accentYellow,
                activeTrackColor: AppColors.accentYellow.withOpacity(0.5),
              ),
            ),

            const SizedBox(height: 12),

            // Information sur le mode actuel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "Initialisé en mode clair par défaut. Utilisez l'interrupteur pour basculer Clair/Sombre (préférence enregistrée).",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkText.withOpacity(0.7)
                      : AppColors.lightText.withOpacity(0.7),
                ),
              ),
            ),

            const SizedBox(height: 24),

            //  Paramètres Généraux
            _SettingsSectionTitle("Général", isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.settings,
              title: "Paramètres avancés",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Paramètres avancés (à développer)"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.info_outline,
              title: "À propos",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("AtaoQuiz v1.0.0"),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            //  Déconnexion
            _SettingsSectionTitle("Compte", isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.logout,
              title: "Déconnexion",
              iconColor: AppColors.error,
              onTap: () {
                _showLogoutDialog(context, isDark);
              },
            ),

            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.close,
              title: "Fermer",
              iconColor: isDark ? AppColors.error : AppColors.error,
              onTap: () {
                _showCloseDialog(context, isDark);
              },
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          "Déconnexion",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          "Êtes-vous sûr de vouloir vous déconnecter ?",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Annuler",
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text(
              "Déconnexion",
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showCloseDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          "Fermer l'application",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          "Voulez-vous fermer complètement l'application ?",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Annuler",
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Close the dialog first
              Navigator.pop(context);
              // Then close the app
              SystemNavigator.pop();
            },
            child: Text(
              "Fermer",
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SettingsSectionTitle(this.title, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.accentYellow : AppColors.primaryBlue,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsCard({
    required this.isDark,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  iconColor ??
                  (isDark ? AppColors.accentYellow : AppColors.primaryBlue),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
