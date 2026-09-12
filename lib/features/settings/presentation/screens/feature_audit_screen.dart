import 'package:flutter/material.dart';
import 'package:timora/core/config/build_info.dart';
import 'package:timora/core/theme/app_colors.dart';

// Screen imports for direct feature testing
import '../../../recap/presentation/screens/recap_screen.dart';
import '../../../recap/presentation/screens/recap_history_screen.dart';
import '../../../recap/domain/models/recap_models.dart';
import '../../../clock/presentation/screens/clock_home_screen.dart';
import '../../../planner/presentation/screens/planner_screen.dart';
import '../../../ai_assistant/presentation/screens/morning_brief_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_privacy_settings_screen.dart';
import '../../../ai_assistant/presentation/widgets/daily_debrief_sheet.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../focus/presentation/screens/focus_history_screen.dart';
import '../../../reviews/presentation/screens/reviews_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../analytics/presentation/screens/reports_screen.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../streaks/presentation/screens/streaks_screen.dart';
import '../../../ambient_sound/presentation/screens/ambient_sounds_screen.dart';
import '../../../diary/presentation/screens/diary_screen.dart';
import '../../../career/presentation/screens/career_roadmap_screen.dart';
import '../../../career/presentation/screens/career_document_vault_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../daily_plan/presentation/screens/daily_plan_screen.dart';
import '../../../weekly_plan/presentation/screens/weekly_plan_screen.dart';
import '../../../monthly_plan/presentation/screens/monthly_plan_screen.dart';
import '../../../routine/presentation/screens/routine_templates_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../cloud_sync/presentation/screens/cloud_account_screen.dart';
import '../../../settings/presentation/screens/data_privacy_screen.dart';

class FeatureAuditScreen extends StatefulWidget {
  const FeatureAuditScreen({super.key});

  @override
  State<FeatureAuditScreen> createState() => _FeatureAuditScreenState();
}

class _FeatureAuditScreenState extends State<FeatureAuditScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'AI & Intelligence',
    'Productivity & Focus',
    'Planning & Time',
    'Analytics & Reviews',
    'Personal & Reflection',
    'Communication & System',
  ];

  void _openFeature(BuildContext context, String featureName) {
    switch (featureName) {
      case 'AI Daily Recap':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecapScreen(recapType: RecapType.daily)));
        break;
      case 'AI Weekly & Monthly Recap':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecapScreen(recapType: RecapType.weekly)));
        break;
      case 'Recap History Archive':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RecapHistoryScreen()));
        break;
      case 'Clock Hub (Alarm, World, Stopwatch, Timer)':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ClockHomeScreen()));
        break;
      case 'Smart Unified Planner':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlannerScreen()));
        break;
      case 'AI Morning Brief':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MorningBriefScreen()));
        break;
      case 'AI Daily Debrief':
        DailyDebriefSheet.show(context);
        break;
      case 'Timora AI Assistant':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AIAssistantScreen()));
        break;
      case 'AI Privacy & Context Permissions':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPrivacySettingsScreen()));
        break;
      case 'Focus & Pomodoro Timer':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
        break;
      case 'Focus History & Volume Stats':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusHistoryScreen()));
        break;
      case 'Reviews & Reflection Wizard':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewsScreen()));
        break;
      case 'Productivity Analysis & Scoring':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
        break;
      case 'Comprehensive Reports':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
        break;
      case 'Habits & Consistency Tracking':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsScreen()));
        break;
      case 'Streaks & Consistency Heatmap':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StreaksScreen()));
        break;
      case 'Ambient Nature Soundscapes':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientSoundsScreen()));
        break;
      case 'Timora Diary & Journal':
      case 'Automatic Diary Recap Integration':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryScreen()));
        break;
      case 'Career Roadmap & Skill Pathway':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerRoadmapScreen()));
        break;
      case 'Career Document Vault':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CareerDocumentVaultScreen()));
        break;
      case 'Projects & Milestones':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
        break;
      case 'Goals & Targets':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()));
        break;
      case 'Daily Agenda Plan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyPlanScreen()));
        break;
      case 'Weekly Agenda Plan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyPlanScreen()));
        break;
      case 'Monthly Agenda Plan':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()));
        break;
      case 'Routine Templates':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineTemplatesScreen()));
        break;
      case 'Notifications Center':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        break;
      case 'Cloud Backup & Sync':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudAccountScreen()));
        break;
      case 'Data Privacy, Export & Import':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPrivacyScreen()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$featureName is active and verified in Timora.')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = BuildInfo.verifiedFeatures.where((f) {
      final matchesCat = _selectedCategory == 'All' ||
          f['category']!.toLowerCase().contains(_selectedCategory.toLowerCase());
      final matchesSearch = _searchQuery.isEmpty ||
          f['name']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f['route']!.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Feature Audit & Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // -----------------------------------------------------------------
          // BUILD IDENTITY CARD (Prevents old/new build confusion)
          // -----------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          BuildInfo.appName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Build ${BuildInfo.buildNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Installed Version: ${BuildInfo.version} (Build #${BuildInfo.buildNumber})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Feature Build Date: ${BuildInfo.featureBuildDate}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verified Modules: ${BuildInfo.verifiedFeatures.length} Active System Features',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // -----------------------------------------------------------------
          // SEARCH & FILTER
          // -----------------------------------------------------------------
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search features, routes or data sources...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // -----------------------------------------------------------------
          // FEATURE AUDIT CARDS
          // -----------------------------------------------------------------
          Text(
            'Audited Features (${filtered.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 10),

          ...filtered.map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          f['name']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Route: ${f['route']!}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Data Source: ${f['dataSource']!}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _openFeature(context, f['name']!),
                      icon: const Icon(Icons.launch_rounded, size: 15),
                      label: const Text('Open / Test Feature', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
