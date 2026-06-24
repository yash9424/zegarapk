// Time display helpers shared across attendance screens.

/// Converts a backend punch time into a friendly 12-hour **IST** label like
/// `5:13 PM`.
///
/// The ZedGift API records punch times in **UTC**, so we shift by +5:30 to
/// show India Standard Time (otherwise an 11:40 AM punch would show as
/// 6:10 AM). Handles the shapes the API returns:
/// * blank / all-zero (`00:00:00`, i.e. a missing punch) → `''`
/// * bare time: `09:15`, `09:15:00`
/// * full datetime: `2026-06-22 09:15:00`, ISO `2026-06-22T09:15:00`
/// * already 12-hour (contains AM/PM) → returned unchanged (no shift)
///
/// Anything it can't parse is returned as-is so we never hide real data.
String to12Hour(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';

  // Already a local 12-hour string — leave as-is (don't shift it again).
  final upper = s.toUpperCase();
  if (upper.contains('AM') || upper.contains('PM')) return s;

  // Isolate the time portion when a date is attached.
  String timePart = s;
  if (s.contains('T')) {
    timePart = s.split('T').last;
  } else if (s.contains(' ')) {
    timePart = s.split(' ').last;
  }

  // Drop fractional seconds / timezone suffix.
  timePart = timePart.split('.').first.split('+').first.trim();

  final bits = timePart.split(':');
  final h = bits.isNotEmpty ? int.tryParse(bits[0]) : null;
  final m = bits.length > 1 ? int.tryParse(bits[1]) : 0;
  final sec = bits.length > 2 ? (int.tryParse(bits[2]) ?? 0) : 0;
  if (h == null || m == null) return s;

  // The API sends "00:00:00" for a missing punch (e.g. not clocked out yet).
  // Treat an all-zero time as blank so the UI shows "—" instead of a time.
  if (h == 0 && m == 0 && sec == 0) return '';

  // Punch time is stored in UTC — shift +5:30 to IST, wrapping past midnight.
  final ist = (h * 60 + m + 330) % 1440;
  final hour24 = ist ~/ 60;
  final mm = ist % 60;

  final period = hour24 >= 12 ? 'PM' : 'AM';
  var hour12 = hour24 % 12;
  if (hour12 == 0) hour12 = 12;
  return '$hour12:${mm.toString().padLeft(2, '0')} $period';
}
