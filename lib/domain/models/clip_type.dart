/// The kind of payload a clip holds. Stored by index via a Drift enum column,
/// so order must stay stable across releases (append-only).
enum ClipType {
  text,
  url,
  richText,
  image;

  /// Best-effort classification of a raw captured string.
  static ClipType classify(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return ClipType.text;
    final uri = Uri.tryParse(trimmed);
    final looksLikeUrl = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        !trimmed.contains(RegExp(r'\s'));
    return looksLikeUrl ? ClipType.url : ClipType.text;
  }
}
