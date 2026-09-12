import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timora/core/theme/design_tokens.dart';
import 'package:timora/features/clock/features/world_clock/data/models/world_clock_city_model.dart';
import 'package:timora/features/clock/features/world_clock/data/sources/world_cities_database.dart';
import 'package:timora/features/clock/features/world_clock/presentation/providers/world_clock_provider.dart';

class AddCitySheet extends ConsumerStatefulWidget {
  const AddCitySheet({super.key});

  @override
  ConsumerState<AddCitySheet> createState() => _AddCitySheetState();
}

class _AddCitySheetState extends ConsumerState<AddCitySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<WorldClockCityModel> _filteredCities = WorldCitiesDatabase.allCities;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredCities = WorldCitiesDatabase.search(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedCities = ref.watch(worldClockCitiesProvider);
    final is24 = ref.watch(worldClockIs24HourProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceDark : AppTokens.surfaceLight,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radiusXLarge)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // Title bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTokens.space20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add World City',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Search Box
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTokens.space16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.cardDark : AppTokens.bgLight,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMedium),
                      border: Border.all(
                        color: isDark
                            ? AppTokens.borderDark
                            : AppTokens.borderLight,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                          color: isDark
                              ? AppTokens.textPrimaryDark
                              : AppTokens.textPrimaryLight),
                      decoration: InputDecoration(
                        icon: const Icon(Icons.search_rounded,
                            color: AppTokens.primaryBlue),
                        hintText: 'Search city, country, or timezone...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppTokens.textMutedDark
                              : AppTokens.textMutedLight,
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cities List
                Expanded(
                  child: _filteredCities.isEmpty
                      ? Center(
                          child: Text(
                            'No cities found matching "${_searchController.text}"',
                            style: TextStyle(
                              color: isDark
                                  ? AppTokens.textSecondaryDark
                                  : AppTokens.textSecondaryLight,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.space16, vertical: 8),
                          itemCount: _filteredCities.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark
                                ? AppTokens.borderDark
                                : AppTokens.borderLight,
                          ),
                          itemBuilder: (context, index) {
                            final city = _filteredCities[index];
                            final isAlreadyAdded = selectedCities.any(
                              (c) =>
                                  c.cityName == city.cityName &&
                                  c.countryName == city.countryName,
                            );

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              leading: Text(
                                city.flagEmoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    city.cityName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isDark
                                          ? AppTokens.textPrimaryDark
                                          : AppTokens.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      city.countryName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppTokens.textSecondaryDark
                                            : AppTokens.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${city.timeZoneDisplayName} • ${city.formattedUtcOffset()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.textMutedLight,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    city.formatTime(is24Hour: is24),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: AppTokens.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  isAlreadyAdded
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: AppTokens.emeraldGreen,
                                          size: 22)
                                      : const Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: AppTokens.primaryBlue,
                                          size: 22),
                                ],
                              ),
                              onTap: isAlreadyAdded
                                  ? null
                                  : () async {
                                      await ref
                                          .read(
                                              worldClockCitiesProvider.notifier)
                                          .addCity(city);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Added ${city.cityName} to World Clock'),
                                            behavior: SnackBarBehavior.floating,
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
