import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/world_clock/data/models/world_clock_city_model.dart';
import 'package:timora/features/clock/features/world_clock/presentation/providers/world_clock_provider.dart';
import 'package:timora/features/clock/features/world_clock/presentation/screens/add_city_sheet.dart';

class WorldClockScreen extends ConsumerWidget {
  const WorldClockScreen({super.key});

  void _openAddCitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddCitySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listening to clockTickProvider ensures the screen updates in real time every second
    ref.watch(clockTickProvider);
    final cities = ref.watch(worldClockCitiesProvider);
    final is24 = ref.watch(worldClockIs24HourProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTokens.bgDark : AppTokens.bgLight,
      appBar: AppBar(
        title: const Text('World Clock',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 12h / 24h format toggle chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: ActionChip(
              avatar: const Icon(Icons.schedule_rounded,
                  size: 16, color: AppTokens.primaryBlue),
              label: Text(
                is24 ? '24H' : '12H',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              backgroundColor:
                  isDark ? AppTokens.cardDark : AppTokens.cardLight,
              side: BorderSide(
                  color: isDark ? AppTokens.borderDark : AppTokens.borderLight),
              onPressed: () {
                ref.read(worldClockIs24HourProvider.notifier).toggle();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined, size: 26),
            tooltip: 'Add City',
            onPressed: () => _openAddCitySheet(context),
          ),
        ],
      ),
      body: cities.isEmpty
          ? _buildEmptyState(context, isDark)
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.space16, AppTokens.space12, AppTokens.space16, 80),
              itemCount: cities.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(worldClockCitiesProvider.notifier)
                    .reorderCities(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final city = cities[index];
                return _buildCityCard(context, ref, city, isDark, is24, index);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCitySheet(context),
        backgroundColor: AppTokens.primaryBlue,
        icon: const Icon(Icons.public_rounded, color: Colors.white),
        label: const Text('Add City',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.cardDark : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color:
                        isDark ? AppTokens.borderDark : AppTokens.borderLight),
              ),
              child: Icon(
                Icons.public_off_rounded,
                size: 56,
                color:
                    isDark ? AppTokens.textMutedDark : AppTokens.textMutedLight,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Cities Added',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTokens.textPrimaryDark
                    : AppTokens.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track timezones around the world by adding cities to your World Clock.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTokens.textSecondaryDark
                    : AppTokens.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openAddCitySheet(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTokens.primaryBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusMedium)),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Add Your First City',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityCard(
    BuildContext context,
    WidgetRef ref,
    WorldClockCityModel city,
    bool isDark,
    bool is24,
    int index,
  ) {
    final timeFormatted = city.formatTime(is24Hour: is24);
    final dateFormatted = city.formatDate();
    final relativeDiff = city.relativeTimeDifference();
    final parts = timeFormatted.split(' ');
    final timeDigits = parts[0];
    final period = parts.length > 1 ? parts[1] : '';

    return Dismissible(
      key: ValueKey('world_city_${city.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppTokens.coralRed,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        ),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 28),
      ),
      onDismissed: (_) {
        ref.read(worldClockCitiesProvider.notifier).removeCity(city.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${city.cityName}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  ref.read(worldClockCitiesProvider.notifier).addCity(city),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.cardDark : AppTokens.cardLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
          border: Border.all(
            color: isDark ? AppTokens.borderDark : AppTokens.borderLight,
          ),
          boxShadow:
              isDark ? AppTokens.cardShadowDark : AppTokens.cardShadowLight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Row(
            children: [
              // Reorder Handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark
                        ? AppTokens.textMutedDark
                        : AppTokens.textMutedLight,
                    size: 22,
                  ),
                ),
              ),

              // Flag & City Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(city.flagEmoji,
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Text(
                          city.cityName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark
                                ? AppTokens.textPrimaryDark
                                : AppTokens.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      relativeDiff,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTokens.textSecondaryDark
                            : AppTokens.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${city.timeZoneDisplayName} • ${city.formattedUtcOffset()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTokens.textMutedDark
                            : AppTokens.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Time & Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeDigits,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppTokens.textPrimaryDark
                              : AppTokens.textPrimaryLight,
                        ),
                      ),
                      if (period.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          period,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.primaryBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateFormatted,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTokens.textSecondaryDark
                          : AppTokens.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
