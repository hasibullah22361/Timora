import '../models/world_clock_city_model.dart';

class WorldCitiesDatabase {
  static final List<WorldClockCityModel> allCities = [
    // Pakistan
    WorldClockCityModel(
      cityName: 'Islamabad',
      countryName: 'Pakistan',
      flagEmoji: '🇵🇰',
      timezoneId: 'Asia/Karachi',
      timeZoneDisplayName: 'Pakistan Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Karachi',
      countryName: 'Pakistan',
      flagEmoji: '🇵🇰',
      timezoneId: 'Asia/Karachi',
      timeZoneDisplayName: 'Pakistan Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Lahore',
      countryName: 'Pakistan',
      flagEmoji: '🇵🇰',
      timezoneId: 'Asia/Karachi',
      timeZoneDisplayName: 'Pakistan Standard Time',
    ),

    // Middle East
    WorldClockCityModel(
      cityName: 'Dubai',
      countryName: 'United Arab Emirates',
      flagEmoji: '🇦🇪',
      timezoneId: 'Asia/Dubai',
      timeZoneDisplayName: 'Gulf Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Abu Dhabi',
      countryName: 'United Arab Emirates',
      flagEmoji: '🇦🇪',
      timezoneId: 'Asia/Dubai',
      timeZoneDisplayName: 'Gulf Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Riyadh',
      countryName: 'Saudi Arabia',
      flagEmoji: '🇸🇦',
      timezoneId: 'Asia/Riyadh',
      timeZoneDisplayName: 'Arabian Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Doha',
      countryName: 'Qatar',
      flagEmoji: '🇶🇦',
      timezoneId: 'Asia/Qatar',
      timeZoneDisplayName: 'Arabian Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Kuwait City',
      countryName: 'Kuwait',
      flagEmoji: '🇰🇼',
      timezoneId: 'Asia/Kuwait',
      timeZoneDisplayName: 'Arabian Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Muscat',
      countryName: 'Oman',
      flagEmoji: '🇴🇲',
      timezoneId: 'Asia/Muscat',
      timeZoneDisplayName: 'Gulf Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Istanbul',
      countryName: 'Turkey',
      flagEmoji: '🇹🇷',
      timezoneId: 'Europe/Istanbul',
      timeZoneDisplayName: 'Turkey Time',
    ),
    WorldClockCityModel(
      cityName: 'Cairo',
      countryName: 'Egypt',
      flagEmoji: '🇪🇬',
      timezoneId: 'Africa/Cairo',
      timeZoneDisplayName: 'Eastern European Time',
    ),
    WorldClockCityModel(
      cityName: 'Beirut',
      countryName: 'Lebanon',
      flagEmoji: '🇱🇧',
      timezoneId: 'Asia/Beirut',
      timeZoneDisplayName: 'Eastern European Time',
    ),

    // Europe
    WorldClockCityModel(
      cityName: 'London',
      countryName: 'United Kingdom',
      flagEmoji: '🇬🇧',
      timezoneId: 'Europe/London',
      timeZoneDisplayName: 'British Time',
    ),
    WorldClockCityModel(
      cityName: 'Paris',
      countryName: 'France',
      flagEmoji: '🇫🇷',
      timezoneId: 'Europe/Paris',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Berlin',
      countryName: 'Germany',
      flagEmoji: '🇩🇪',
      timezoneId: 'Europe/Berlin',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Rome',
      countryName: 'Italy',
      flagEmoji: '🇮🇹',
      timezoneId: 'Europe/Rome',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Madrid',
      countryName: 'Spain',
      flagEmoji: '🇪🇸',
      timezoneId: 'Europe/Madrid',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Amsterdam',
      countryName: 'Netherlands',
      flagEmoji: '🇳🇱',
      timezoneId: 'Europe/Amsterdam',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Zurich',
      countryName: 'Switzerland',
      flagEmoji: '🇨🇭',
      timezoneId: 'Europe/Zurich',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Vienna',
      countryName: 'Austria',
      flagEmoji: '🇦🇹',
      timezoneId: 'Europe/Vienna',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Dublin',
      countryName: 'Ireland',
      flagEmoji: '🇮🇪',
      timezoneId: 'Europe/Dublin',
      timeZoneDisplayName: 'Irish Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Stockholm',
      countryName: 'Sweden',
      flagEmoji: '🇸🇪',
      timezoneId: 'Europe/Stockholm',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Oslo',
      countryName: 'Norway',
      flagEmoji: '🇳🇴',
      timezoneId: 'Europe/Oslo',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Athens',
      countryName: 'Greece',
      flagEmoji: '🇬🇷',
      timezoneId: 'Europe/Athens',
      timeZoneDisplayName: 'Eastern European Time',
    ),
    WorldClockCityModel(
      cityName: 'Lisbon',
      countryName: 'Portugal',
      flagEmoji: '🇵🇹',
      timezoneId: 'Europe/Lisbon',
      timeZoneDisplayName: 'Western European Time',
    ),
    WorldClockCityModel(
      cityName: 'Warsaw',
      countryName: 'Poland',
      flagEmoji: '🇵🇱',
      timezoneId: 'Europe/Warsaw',
      timeZoneDisplayName: 'Central European Time',
    ),
    WorldClockCityModel(
      cityName: 'Brussels',
      countryName: 'Belgium',
      flagEmoji: '🇧🇪',
      timezoneId: 'Europe/Brussels',
      timeZoneDisplayName: 'Central European Time',
    ),

    // North America
    WorldClockCityModel(
      cityName: 'New York',
      countryName: 'United States',
      flagEmoji: '🇺🇸',
      timezoneId: 'America/New_York',
      timeZoneDisplayName: 'Eastern Time',
    ),
    WorldClockCityModel(
      cityName: 'Los Angeles',
      countryName: 'United States',
      flagEmoji: '🇺🇸',
      timezoneId: 'America/Los_Angeles',
      timeZoneDisplayName: 'Pacific Time',
    ),
    WorldClockCityModel(
      cityName: 'Chicago',
      countryName: 'United States',
      flagEmoji: '🇺🇸',
      timezoneId: 'America/Chicago',
      timeZoneDisplayName: 'Central Time',
    ),
    WorldClockCityModel(
      cityName: 'San Francisco',
      countryName: 'United States',
      flagEmoji: '🇺🇸',
      timezoneId: 'America/Los_Angeles',
      timeZoneDisplayName: 'Pacific Time',
    ),
    WorldClockCityModel(
      cityName: 'Miami',
      countryName: 'United States',
      flagEmoji: '🇺🇸',
      timezoneId: 'America/New_York',
      timeZoneDisplayName: 'Eastern Time',
    ),
    WorldClockCityModel(
      cityName: 'Toronto',
      countryName: 'Canada',
      flagEmoji: '🇨🇦',
      timezoneId: 'America/Toronto',
      timeZoneDisplayName: 'Eastern Time',
    ),
    WorldClockCityModel(
      cityName: 'Vancouver',
      countryName: 'Canada',
      flagEmoji: '🇨🇦',
      timezoneId: 'America/Vancouver',
      timeZoneDisplayName: 'Pacific Time',
    ),
    WorldClockCityModel(
      cityName: 'Mexico City',
      countryName: 'Mexico',
      flagEmoji: '🇲🇽',
      timezoneId: 'America/Mexico_City',
      timeZoneDisplayName: 'Central Standard Time',
    ),

    // Asia & Pacific
    WorldClockCityModel(
      cityName: 'Tokyo',
      countryName: 'Japan',
      flagEmoji: '🇯🇵',
      timezoneId: 'Asia/Tokyo',
      timeZoneDisplayName: 'Japan Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Singapore',
      countryName: 'Singapore',
      flagEmoji: '🇸🇬',
      timezoneId: 'Asia/Singapore',
      timeZoneDisplayName: 'Singapore Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Hong Kong',
      countryName: 'Hong Kong',
      flagEmoji: '🇭🇰',
      timezoneId: 'Asia/Hong_Kong',
      timeZoneDisplayName: 'Hong Kong Time',
    ),
    WorldClockCityModel(
      cityName: 'Seoul',
      countryName: 'South Korea',
      flagEmoji: '🇰🇷',
      timezoneId: 'Asia/Seoul',
      timeZoneDisplayName: 'Korea Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Beijing',
      countryName: 'China',
      flagEmoji: '🇨🇳',
      timezoneId: 'Asia/Shanghai',
      timeZoneDisplayName: 'China Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Shanghai',
      countryName: 'China',
      flagEmoji: '🇨🇳',
      timezoneId: 'Asia/Shanghai',
      timeZoneDisplayName: 'China Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Bangkok',
      countryName: 'Thailand',
      flagEmoji: '🇹🇭',
      timezoneId: 'Asia/Bangkok',
      timeZoneDisplayName: 'Indochina Time',
    ),
    WorldClockCityModel(
      cityName: 'Kuala Lumpur',
      countryName: 'Malaysia',
      flagEmoji: '🇲🇾',
      timezoneId: 'Asia/Kuala_Lumpur',
      timeZoneDisplayName: 'Malaysia Time',
    ),
    WorldClockCityModel(
      cityName: 'Jakarta',
      countryName: 'Indonesia',
      flagEmoji: '🇮🇩',
      timezoneId: 'Asia/Jakarta',
      timeZoneDisplayName: 'Western Indonesia Time',
    ),
    WorldClockCityModel(
      cityName: 'Sydney',
      countryName: 'Australia',
      flagEmoji: '🇦🇺',
      timezoneId: 'Australia/Sydney',
      timeZoneDisplayName: 'Australian Eastern Time',
    ),
    WorldClockCityModel(
      cityName: 'Melbourne',
      countryName: 'Australia',
      flagEmoji: '🇦🇺',
      timezoneId: 'Australia/Melbourne',
      timeZoneDisplayName: 'Australian Eastern Time',
    ),
    WorldClockCityModel(
      cityName: 'Auckland',
      countryName: 'New Zealand',
      flagEmoji: '🇳🇿',
      timezoneId: 'Pacific/Auckland',
      timeZoneDisplayName: 'New Zealand Time',
    ),
    WorldClockCityModel(
      cityName: 'New Delhi',
      countryName: 'India',
      flagEmoji: '🇮🇳',
      timezoneId: 'Asia/Kolkata',
      timeZoneDisplayName: 'India Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Mumbai',
      countryName: 'India',
      flagEmoji: '🇮🇳',
      timezoneId: 'Asia/Kolkata',
      timeZoneDisplayName: 'India Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Dhaka',
      countryName: 'Bangladesh',
      flagEmoji: '🇧🇩',
      timezoneId: 'Asia/Dhaka',
      timeZoneDisplayName: 'Bangladesh Standard Time',
    ),

    // South America
    WorldClockCityModel(
      cityName: 'Sao Paulo',
      countryName: 'Brazil',
      flagEmoji: '🇧🇷',
      timezoneId: 'America/Sao_Paulo',
      timeZoneDisplayName: 'Brasilia Time',
    ),
    WorldClockCityModel(
      cityName: 'Buenos Aires',
      countryName: 'Argentina',
      flagEmoji: '🇦🇷',
      timezoneId: 'America/Argentina/Buenos_Aires',
      timeZoneDisplayName: 'Argentina Time',
    ),
    WorldClockCityModel(
      cityName: 'Santiago',
      countryName: 'Chile',
      flagEmoji: '🇨🇱',
      timezoneId: 'America/Santiago',
      timeZoneDisplayName: 'Chile Time',
    ),
    WorldClockCityModel(
      cityName: 'Bogota',
      countryName: 'Colombia',
      flagEmoji: '🇨🇴',
      timezoneId: 'America/Bogota',
      timeZoneDisplayName: 'Colombia Time',
    ),

    // Africa
    WorldClockCityModel(
      cityName: 'Johannesburg',
      countryName: 'South Africa',
      flagEmoji: '🇿🇦',
      timezoneId: 'Africa/Johannesburg',
      timeZoneDisplayName: 'South Africa Standard Time',
    ),
    WorldClockCityModel(
      cityName: 'Nairobi',
      countryName: 'Kenya',
      flagEmoji: '🇰🇪',
      timezoneId: 'Africa/Nairobi',
      timeZoneDisplayName: 'East Africa Time',
    ),
    WorldClockCityModel(
      cityName: 'Lagos',
      countryName: 'Nigeria',
      flagEmoji: '🇳🇬',
      timezoneId: 'Africa/Lagos',
      timeZoneDisplayName: 'West Africa Time',
    ),
    WorldClockCityModel(
      cityName: 'Casablanca',
      countryName: 'Morocco',
      flagEmoji: '🇲🇦',
      timezoneId: 'Africa/Casablanca',
      timeZoneDisplayName: 'Western European Time',
    ),
  ];

  static List<WorldClockCityModel> search(String query) {
    if (query.trim().isEmpty) return allCities;
    final q = query.toLowerCase().trim();
    return allCities.where((c) {
      return c.cityName.toLowerCase().contains(q) ||
          c.countryName.toLowerCase().contains(q) ||
          c.timezoneId.toLowerCase().contains(q) ||
          c.timeZoneDisplayName.toLowerCase().contains(q);
    }).toList();
  }
}
