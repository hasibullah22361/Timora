class SupabaseConfig {
  /// Default project URL configured for Timora
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lgjzjzbbhmiejuovgtol.supabase.co',
  );

  /// Supabase public publishable / anon key. Inject via --dart-define=SUPABASE_ANON_KEY=your_key
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3bZUB_9UKKHXibPytFdl6Q_nTMpdio2',
  );

  /// Alias for publishable key
  static String get publishableKey => anonKey;

  /// Check whether Supabase is configured with a non-empty, non-placeholder key
  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !anonKey.contains('placeholder_key');
}


