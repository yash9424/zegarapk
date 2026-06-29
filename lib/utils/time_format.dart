// Time display helpers shared across attendance screens.

/// Converts a backend punch time into a friendly 12-hour label like `5:13 PM`.
///
/// The ZedGift API already records punch times in **local IST** (verified live:
/// a punch made at ~16:06 IST is stored as `15:59:55`), so we do NOT shift the
/// clock — we only reformat it to 12-hour. Handles the shapes the API returns:
/// * blank / all-zero (`00:00:00`, i.e. a missing punch) → `''`
/// * bare time: `09:15`, `09:15:00`
/// * full datetime: `2026-06-22 09:15:00`, ISO `2026-06-22T09:15:00`
/// * already 12-hour (contains AM/PM) → returned unchanged
///
/// Anything it can't parse is returned as-is so we never hide real data.
String to12Hour(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';

  // Already a 12-hour string — leave as-is.
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

  // Time is already IST — just format it, no shift.
  final period = h >= 12 ? 'PM' : 'AM';
  var hour12 = h % 12;
  if (hour12 == 0) hour12 = 12;
  return '$hour12:${m.toString().padLeft(2, '0')} $period';
}
