/// Formats the actual data span covered by chart points for summary labels.
String formatChartChangeSpanLabel(Duration span) {
  final hours = span.inHours;
  if (hours < 36) return '24h';
  final days = span.inDays;
  if (days < 60) return '${days}d';
  final months = (days / 30).round().clamp(1, 999);
  return '${months}mo';
}

/// Human-readable span for partial-range captions (e.g. "2 days").
String formatChartSpanCaption(Duration span) {
  final hours = span.inHours;
  if (hours < 36) return '24h';
  final days = span.inDays;
  if (days == 1) return '1 day';
  if (days < 60) return '$days days';
  final months = (days / 30).round().clamp(1, 999);
  return months == 1 ? '1 month' : '$months months';
}
