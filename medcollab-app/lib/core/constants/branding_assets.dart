/// Packaged brand images. Prefer these over raw asset paths.
abstract final class BrandingAssets {
  /// Vocle wordmark with real transparency (splash / sign-in). Generated
  /// from vocle_full_logo.jpeg by removing its white background, so it sits
  /// on any page colour without a white box (issue 12).
  static const String logo = 'assets/branding/vocle_logo_clear.png';

  /// Compact icon (JPEG) for dense surfaces.
  static const String icon = 'assets/branding/vocle_icon.jpeg';
}
