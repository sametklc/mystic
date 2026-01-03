/// Mystic Date Utilities
///
/// The Mystic app uses a custom "Mystic Day" concept where
/// the day resets at 07:00 AM instead of midnight.
///
/// This is because:
/// - Many users check their daily readings in the morning
/// - Late-night users (after midnight) should see "yesterday's" reading
/// - The 7 AM reset aligns with natural wake cycles

/// Returns the "Mystic Date" string in YYYY-MM-DD format.
///
/// The Mystic Day changes at 07:00 AM instead of midnight:
/// - If current time is before 7 AM → return yesterday's date
/// - If current time is 7 AM or later → return today's date
///
/// Example:
/// - Jan 2nd, 02:00 AM → Returns "2024-01-01" (yesterday)
/// - Jan 2nd, 07:01 AM → Returns "2024-01-02" (today)
String getMysticDateString([DateTime? dateTime]) {
  final now = dateTime ?? DateTime.now();

  // If before 7 AM, use yesterday's date
  final logicalDate = now.hour < 7
      ? now.subtract(const Duration(days: 1))
      : now;

  return '${logicalDate.year}-${logicalDate.month.toString().padLeft(2, '0')}-${logicalDate.day.toString().padLeft(2, '0')}';
}

/// Returns the DateTime representing the start of the current Mystic Day.
///
/// This is useful for calculating time until reset.
DateTime getMysticDayStart([DateTime? dateTime]) {
  final now = dateTime ?? DateTime.now();

  if (now.hour < 7) {
    // We're in "yesterday's" mystic day, which started yesterday at 7 AM
    final yesterday = now.subtract(const Duration(days: 1));
    return DateTime(yesterday.year, yesterday.month, yesterday.day, 7, 0, 0);
  } else {
    // We're in "today's" mystic day, which started today at 7 AM
    return DateTime(now.year, now.month, now.day, 7, 0, 0);
  }
}

/// Returns the DateTime when the next Mystic Day begins (next 7 AM).
///
/// Useful for showing "resets in X hours" countdown.
DateTime getNextMysticDayStart([DateTime? dateTime]) {
  final now = dateTime ?? DateTime.now();

  if (now.hour < 7) {
    // Next reset is today at 7 AM
    return DateTime(now.year, now.month, now.day, 7, 0, 0);
  } else {
    // Next reset is tomorrow at 7 AM
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7, 0, 0);
  }
}

/// Returns the duration until the next Mystic Day reset.
Duration getTimeUntilMysticReset([DateTime? dateTime]) {
  final now = dateTime ?? DateTime.now();
  final nextReset = getNextMysticDayStart(now);
  return nextReset.difference(now);
}

/// Returns a human-readable string for time until reset.
/// Example: "5h 32m" or "32m"
String getTimeUntilResetString([DateTime? dateTime]) {
  final duration = getTimeUntilMysticReset(dateTime);
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}
