import 'package:flutter/material.dart';

class ProfileAvatarOption {
  final IconData icon;
  final String label;

  const ProfileAvatarOption({required this.icon, required this.label});
}

const List<ProfileAvatarOption> profileAvatarOptions = [
  ProfileAvatarOption(icon: Icons.person, label: 'Classique'),
  ProfileAvatarOption(icon: Icons.face, label: 'Sourire'),
  ProfileAvatarOption(icon: Icons.pets, label: 'Pet'),
  ProfileAvatarOption(icon: Icons.rocket_launch, label: 'Fusée'),
  ProfileAvatarOption(icon: Icons.auto_awesome, label: 'Étoile'),
  ProfileAvatarOption(icon: Icons.psychology, label: 'Esprit'),
  ProfileAvatarOption(icon: Icons.sports_esports, label: 'Gamer'),
  ProfileAvatarOption(icon: Icons.school, label: 'Étude'),
];

ProfileAvatarOption profileAvatarByIndex(int index) {
  if (index < 0) {
    return profileAvatarOptions.first;
  }
  return profileAvatarOptions[index % profileAvatarOptions.length];
}

class ProfileAvatar extends StatelessWidget {
  final int avatarIndex;
  final double radius;
  final Color accentColor;
  final Color? backgroundColor;
  final double borderWidth;

  const ProfileAvatar({
    super.key,
    required this.avatarIndex,
    required this.radius,
    required this.accentColor,
    this.backgroundColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = profileAvatarByIndex(avatarIndex);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? accentColor.withValues(alpha: 0.14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.85),
          width: borderWidth,
        ),
      ),
      child: Icon(avatar.icon, color: accentColor, size: radius),
    );
  }
}
