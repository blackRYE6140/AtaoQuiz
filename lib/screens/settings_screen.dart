import 'package:flutter/material.dart';
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
  // Variable pour suivre l'état manuel du switch
  bool? _manualOverride;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Déterminer l'état du switch
    bool isDarkModeEnabled;
    
    if (_manualOverride != null) {
      // Si l'utilisateur a changé manuellement, utiliser cette valeur
      isDarkModeEnabled = _manualOverride!;
    } else if (widget.currentThemeMode == ThemeMode.dark) {
      isDarkModeEnabled = true;
    } else if (widget.currentThemeMode == ThemeMode.light) {
      isDarkModeEnabled = false;
    } else {
      // Mode système
      isDarkModeEnabled = isDark;
    }

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
            // 🌙 Mode Sombre / Clair
            _SettingsSectionTitle("Apparence", isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              icon: Icons.brightness_4,
              title: "Mode sombre",
              trailing: Switch(
                value: isDarkModeEnabled,
                onChanged: (value) {
                  // Stocker la préférence manuelle
                  setState(() {
                    _manualOverride = value;
                  });
                  
                  // Changer le theme mode
                  ThemeMode newMode = value ? ThemeMode.dark : ThemeMode.light;
                  if (widget.onThemeModeChanged != null) {
                    widget.onThemeModeChanged!(newMode);
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value ? "Mode sombre activé" : "Mode clair activé",
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
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
                _getCurrentModeText(widget.currentThemeMode, isDark),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isDark ? AppColors.darkText.withOpacity(0.7) : AppColors.lightText.withOpacity(0.7),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ⚙️ Paramètres Généraux
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

            // 🚪 Déconnexion
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

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _getCurrentModeText(ThemeMode? currentMode, bool isDark) {
    switch (currentMode) {
      case ThemeMode.dark:
        return "Mode : Sombre (manuel)";
      case ThemeMode.light:
        return "Mode : Clair (manuel)";
      case ThemeMode.system:
        return "Mode : Système (${isDark ? 'Sombre' : 'Clair'})";
      default:
        return "Mode : Système (${isDark ? 'Sombre' : 'Clair'})";
    }
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
              color: iconColor ?? (isDark ? AppColors.accentYellow : AppColors.primaryBlue),
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