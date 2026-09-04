import 'package:flutter/material.dart';

class AmbientSound {
  final String id;
  final String name;
  final String icon;
  final String description;
  final Color themeColor;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.themeColor,
  });

  static const List<AmbientSound> allSounds = [
    AmbientSound(
      id: 'rain',
      name: 'Rain',
      icon: '🌧️',
      description: 'Gentle, steady rainfall patter for calm and focus',
      themeColor: Color(0xFF0284C7),
    ),
    AmbientSound(
      id: 'thunderstorm',
      name: 'Thunderstorm',
      icon: '⛈️',
      description: 'Distant rolling thunder with rhythmic heavy rain',
      themeColor: Color(0xFF475569),
    ),
    AmbientSound(
      id: 'ocean_waves',
      name: 'Ocean Waves',
      icon: '🌊',
      description: 'Continuous rhythmic oceanic swells washing ashore',
      themeColor: Color(0xFF0EA5E9),
    ),
    AmbientSound(
      id: 'forest',
      name: 'Forest',
      icon: '🌲',
      description: 'Whispering pine trees and gentle woodland breeze',
      themeColor: Color(0xFF059669),
    ),
    AmbientSound(
      id: 'birds',
      name: 'Birds',
      icon: '🐦',
      description: 'Morning birdsong chorus in a serene woodland garden',
      themeColor: Color(0xFF10B981),
    ),
    AmbientSound(
      id: 'fireplace',
      name: 'Fireplace',
      icon: '🔥',
      description: 'Cozy crackling firewood with warm soothing embers',
      themeColor: Color(0xFFEA580C),
    ),
    AmbientSound(
      id: 'cafe',
      name: 'Café',
      icon: '☕',
      description: 'Subtle coffee shop chatter, espresso clinks and warmth',
      themeColor: Color(0xFFB45309),
    ),
    AmbientSound(
      id: 'wind',
      name: 'Wind',
      icon: '🌬️',
      description: 'Soft atmospheric wind gusts across mountain passes',
      themeColor: Color(0xFF64748B),
    ),
    AmbientSound(
      id: 'water_stream',
      name: 'Water Stream',
      icon: '💧',
      description: 'Babbling freshwater brook flowing over smooth river stones',
      themeColor: Color(0xFF06B6D4),
    ),
    AmbientSound(
      id: 'night',
      name: 'Night',
      icon: '🌙',
      description: 'Peaceful nocturnal crickets, cicadas and twilight atmosphere',
      themeColor: Color(0xFF6366F1),
    ),
    AmbientSound(
      id: 'nature',
      name: 'Nature',
      icon: '🌿',
      description: 'Lush meadow ambience with rustling foliage and insects',
      themeColor: Color(0xFF16A34A),
    ),
    AmbientSound(
      id: 'rain_thunder',
      name: 'Rain + Thunder',
      icon: '🌧️⚡',
      description: 'Immersive blend of continuous rain shower and deep thunder',
      themeColor: Color(0xFF334155),
    ),
  ];

  static AmbientSound getById(String id) {
    return allSounds.firstWhere(
      (s) => s.id == id,
      orElse: () => allSounds.first,
    );
  }
}
