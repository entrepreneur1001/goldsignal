/// Lightweight widget copy for foreground and background isolates.
///
/// Background callbacks cannot use `context.tr()` / EasyLocalization, so metal
/// names and unit templates live here for en/ar/ur.
class WidgetStrings {
  final String gold;
  final String silver;
  final String unitTemplate; // "{currency} / gram"

  const WidgetStrings({
    required this.gold,
    required this.silver,
    required this.unitTemplate,
  });

  String unitLabel(String currency) =>
      unitTemplate.replaceAll('{currency}', currency);

  String metalLabel(String metal) => metal == 'gold' ? gold : silver;

  String rowLabel({required String metal, required String karat}) {
    final karatLabel = metal == 'gold' ? '${karat}K' : karat;
    return '$karatLabel ${metalLabel(metal)}';
  }

  static WidgetStrings forLanguage(String? languageCode) {
    switch (languageCode) {
      case 'ar':
        return const WidgetStrings(
          gold: 'ذهب',
          silver: 'فضة',
          unitTemplate: '{currency} / جرام',
        );
      case 'ur':
        return const WidgetStrings(
          gold: 'سونا',
          silver: 'چاندی',
          unitTemplate: '{currency} / گرام',
        );
      default:
        return const WidgetStrings(
          gold: 'Gold',
          silver: 'Silver',
          unitTemplate: '{currency} / gram',
        );
    }
  }
}
