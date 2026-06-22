// Time display helpers shared across attendance screens.

/// Converts a backend time/datetime string into a friendly 12-hour label
/// like `9:15 AM`.
///
/// Handles the shapes the ZedGift API returns in practice:
/// * blank / null-ish → `''`
/// * bare time: `09:15`, `09:15:00`
/// * full datetime: `2026-06-22 09:15:00`, ISO `2026-06-22T09:15:00`
/// * already 12-hour (`09:15 AM`) → returned unchanged
///
/// Anything it can't parse is returned as-is so we never hide real data.
String to12Hour(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';

  // Already carries an AM/PM marker — assume it's display-ready.
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
  if (h == null || m == null) return s;

  final period = h >= 12 ? 'PM' : 'AM';
  var hour12 = h % 12;
  if (hour12 == 0) hour12 = 12;
  return '$hour12:${m.toString().padLeft(2, '0')} $period';
}
