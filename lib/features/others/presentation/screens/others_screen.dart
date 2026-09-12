import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timora/core/providers/shared_prefs_provider.dart';
import 'package:timora/core/theme/app_colors.dart';

// Screens
import '../../../planner/presentation/screens/planner_screen.dart';
import '../../../projects/presentation/screens/projects_screen.dart';
import '../../../goals/presentation/screens/goals_screen.dart';
import '../../../analytics/presentation/screens/analytics_screen.dart';
import '../../../diary/presentation/screens/diary_screen.dart';
import '../../../career/presentation/screens/career_roadmap_screen.dart';
import '../../../career/presentation/screens/career_document_vault_screen.dart';
import '../../../clock/presentation/screens/clock_home_screen.dart';
import '../../../recap/presentation/screens/recaps_hub_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import 'package:timora/features/settings/services/feature_flags_service.dart';

enum FeaturesViewMode { grid, list }

class FeaturesViewModeNotifier extends StateNotifier<FeaturesViewMode> {
  static const String _storageKey = 'timora_features_view_mode';
  final SharedPreferences _prefs;

  FeaturesViewModeNotifier(this._prefs)
      : super(_prefs.getString(_storageKey) == 'list'
            ? FeaturesViewMode.list
            : FeaturesViewMode.grid);

  Future<void> setMode(FeaturesViewMode mode) async {
    state = mode;
    await _prefs.setString(_storageKey, mode.name);
  }
}

final featuresViewModeProvider =
    StateNotifierProvider<FeaturesViewModeNotifier, FeaturesViewMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FeaturesViewModeNotifier(prefs);
});

class OthersScreen extends ConsumerStatefulWidget {
  const OthersScreen({super.key});

  @override
  ConsumerState<OthersScreen> createState() => _OthersScreenState();
}

class _OthersScreenState extends ConsumerState<OthersScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Planning & Goals',
    'Reviews & Insights',
    'Personal & Career',
  ];

  List<_OthersItem> _getAllItems(BuildContext context, FeatureFlagsState flags) {
    return [
      // =====================================================================
      // 1. REVIEWS & INSIGHTS (COMBINED RECAPS & ANALYTICS)
      // =====================================================================
      if (flags.isAutomaticReportsEnabled)
        _OthersItem(
          title: 'Recaps',
        description: 'AI Daily, Weekly & Monthly performance recaps, productivity score, and history archive',
        icon: Icons.auto_graph_rounded,
        color: const Color(0xFF6366F1),
        category: 'Reviews & Insights',
        badgeText: 'AI Recaps',
        actionLabel: 'Explore',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecapsHubScreen()),
          );
        },
      ),
      if (flags.isProductivityHeatmapEnabled || flags.isAutomaticReportsEnabled)
        _OthersItem(
          title: 'Productivity Analysis',
        description: 'Understand focus patterns, task velocity, score breakdowns, and comprehensive reports',
        icon: Icons.insights_outlined,
        color: const Color(0xFF8B5CF6),
        category: 'Reviews & Insights',
        badgeText: 'Analytics',
        actionLabel: 'Analyze',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
          );
        },
      ),

      // =====================================================================
      // 2. PLANNING & GOALS
      // =====================================================================
      if (flags.isSmartDailyPlannerEnabled)
        _OthersItem(
          title: 'Smart Planner',
        description: 'Daily plan, agenda timelines, weekly overview & monthly calendar planning',
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFF2563EB),
        category: 'Planning & Goals',
        badgeText: 'Planner',
        actionLabel: 'Plan',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlannerScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Clock (Alarm, Timer, Stopwatch)',
        description: 'Wake-up alarms, global world clock, countdown timers, and precision stopwatch with lap tracking',
        icon: Icons.access_time_outlined,
        color: const Color(0xFF0284C7),
        category: 'Planning & Goals',
        badgeText: 'Alarm & Tools',
        actionLabel: 'Open',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClockHomeScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Projects',
        description: 'Manage ongoing projects, deliverables, milestones, and associated task breakdowns',
        icon: Icons.folder_outlined,
        color: const Color(0xFF0D9488),
        category: 'Planning & Goals',
        badgeText: 'Portfolio',
        actionLabel: 'Manage',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProjectsScreen()),
          );
        },
      ),
      _OthersItem(
        title: 'Goals & Targets',
        description: 'Set and track long-term targets, progress milestones, and completion percentages',
        icon: Icons.track_changes_outlined,
        color: const Color(0xFF10B981),
        category: 'Planning & Goals',
        badgeText: 'Goals',
        actionLabel: 'View',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          );
        },
      ),

      // =====================================================================
      // 3. PERSONAL & CAREER
      // =====================================================================
      _OthersItem(
        title: 'Timora Diary & Reflection',
        description: 'Log daily wins, track mood & energy levels, gratitude reflections, and AI recap entries',
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF06B6D4),
        category: 'Personal & Career',
        badgeText: 'Journal',
        actionLabel: 'Write',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiaryScreen()),
          );
        },
      ),
      if (flags.isCareerRoadmapEnabled)
        _OthersItem(
          title: 'Career Roadmap',
        description: 'Personalized career milestones, skill pathways, and task synchronization',
        icon: Icons.timeline_outlined,
        color: const Color(0xFF7C3AED),
        category: 'Personal & Career',
        badgeText: 'Career',
        actionLabel: 'Explore',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CareerRoadmapScreen()),
          );
        },
      ),
      if (flags.isCareerDocumentVaultEnabled)
        _OthersItem(
          title: 'Career Document Vault',
        description: 'Secure storage for CV, resumes, certificates, transcripts, and credentials',
        icon: Icons.lock_outline_rounded,
        color: const Color(0xFF4F46E5),
        category: 'Personal & Career',
        badgeText: 'Vault',
        actionLabel: 'Access',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CareerDocumentVaultScreen()),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewMode = ref.watch(featuresViewModeProvider);
    final flags = ref.watch(featureFlagsProvider);

    final allItems = _getAllItems(context, flags);

    final filteredItems = allItems.where((item) {
      final matchesCat = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 0.82;

    if (screenWidth >= 1000) {
      crossAxisCount = 4;
      childAspectRatio = 1.15;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.02;
    } else {
      crossAxisCount = 2;
      childAspectRatio = screenWidth < 380 ? 0.74 : 0.82;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Other Features', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        children: [
          // -----------------------------------------------------------------
          // 1. TOP HEADER & VIEW MODE SWITCHER
          // -----------------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Timora Features',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discover ${allItems.length} specialized tools across planning, growth & recaps.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // View Mode Switcher
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E2A42) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleBtn(
                      title: 'Grid',
                      icon: Icons.grid_view_rounded,
                      isSelected: viewMode == FeaturesViewMode.grid,
                      onTap: () => ref.read(featuresViewModeProvider.notifier).setMode(FeaturesViewMode.grid),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 2),
                    _buildToggleBtn(
                      title: 'List',
                      icon: Icons.view_list_rounded,
                      isSelected: viewMode == FeaturesViewMode.list,
                      onTap: () => ref.read(featuresViewModeProvider.notifier).setMode(FeaturesViewMode.list),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // -----------------------------------------------------------------
          // 2. SEARCH BAR
          // -----------------------------------------------------------------
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search features (e.g. Recaps, Planner, Clock, Projects)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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

          // -----------------------------------------------------------------
          // 3. CATEGORY FILTER CHIPS
          // -----------------------------------------------------------------
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
          // 4. MAIN FEATURES VIEW (GRID OR LIST)
          // -----------------------------------------------------------------
          if (filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'No features match "$_searchQuery"',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (viewMode == FeaturesViewMode.grid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildGridCard(context, item, isDark, theme);
              },
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                return _buildListRow(context, item, isDark, theme);
              },
            ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildToggleBtn({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isSelected
          ? const Color(0xFF2563EB)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(BuildContext context, _OthersItem item, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    if (item.badgeText != null)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.badgeText!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.actionLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: item.color,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: item.color),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListRow(BuildContext context, _OthersItem item, bool isDark, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (item.badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badgeText!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OthersItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final String? badgeText;
  final String actionLabel;
  final VoidCallback onTap;

  const _OthersItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    this.badgeText,
    required this.actionLabel,
    required this.onTap,
  });
}
