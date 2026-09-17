import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accent_palette.dart';
import 'app_icons.dart';
import '../../ui/common/app_icon.dart';

/// The app's visual language: a warm off-white page, white cards that float on
/// it with a very soft shadow, generous rounding, and one muted sage accent
/// used only to mark what is selected.
class AppTheme {
  const AppTheme._();

  // --------------------------------------------------------------- accents
  /// The accent the app ships with, used before settings are read and as a
  /// const fallback where no BuildContext is available.
  ///
  /// Everything on screen should prefer `context.accent`, which follows the
  /// accent the user picked in Settings.
  static const Color accent = Color(0xFF2E7A6C);

  /// Light variant, for anything sitting on top of video.
  static const Color accentOnDark = Color(0xFF86C9BB);

  // -------------------------------------------------------------- surfaces
  static const Color lightBackground = Color(0xFFF3F2ED);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEBE9E2);
  static const Color lightOnSurface = Color(0xFF16181A);
  static const Color lightMuted = Color(0xFF7C8085);

  static const Color darkBackground = Color(0xFF101211);
  static const Color darkSurface = Color(0xFF1A1D1B);
  static const Color darkSurfaceHigh = Color(0xFF262A28);
  static const Color darkOnSurface = Color(0xFFF1F0EC);
  static const Color darkMuted = Color(0xFF9A9E9B);

  // ---------------------------------------------------------------- shape
  static const double radiusThumb = 18;
  static const double radiusCard = 24;
  static const double radiusSheet = 30;
  static const double radiusPill = 999;

  static BorderRadius get cardRadius => BorderRadius.circular(radiusCard);
  static BorderRadius get thumbRadius => BorderRadius.circular(radiusThumb);
  static BorderRadius get pillRadius => BorderRadius.circular(radiusPill);

  /// Page side margin, used by every screen so columns line up.
  static const double pageMargin = 16;

  // Spacing scale. Every gap in the app is one of these, so rhythm stays
  // consistent from screen to screen.
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  /// The soft lift that separates a card from the page. Barely visible on its
  /// own, but it is what makes the layout read as floating panels.
  static List<BoxShadow> cardShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x0F101828), blurRadius: 16, offset: Offset(0, 5)),
      BoxShadow(color: Color(0x0A101828), blurRadius: 3, offset: Offset(0, 1)),
    ];
  }

  // ---------------------------------------------------------------- glass
  // Surfaces that sit on top of video: translucent enough to keep the frame
  // visible behind them, opaque enough to read against any scene. They take
  // their colour from the theme, so the player stays part of the same app in
  // both light and dark.

  /// How far the frame behind a glass surface is blurred.
  static const double glassBlur = 24;

  static Color glassFill(ThemeData theme) => theme.brightness == Brightness.dark
      ? theme.colorScheme.surface.withValues(alpha: 0.46)
      : Colors.white.withValues(alpha: 0.52);

  /// The hairline that gives a glass surface its edge.
  static Color glassBorder(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.60);

  static List<BoxShadow> glassShadow(ThemeData theme) =>
      theme.brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1F101828),
            blurRadius: 22,
            offset: Offset(0, 6),
          ),
        ];

  /// Glass for surfaces that sit on the page rather than over video: cards,
  /// pills, the navigation bar.
  ///
  /// It carries the look of glass — a translucent milky fill, a bright hairline
  /// edge, a soft lift — without a live blur. There is nothing busy behind these
  /// to blur, and hundreds of blurred cards would cost every scroll frame.
  static BoxDecoration glassSurface(
    ThemeData theme, {
    BorderRadius? radius,
    bool selected = false,
    bool floating = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    // Over a background picture the glass thins out so the picture reads
    // through it, the way frosted glass does.
    final overPicture = theme.scaffoldBackgroundColor.a == 0;
    final base = isDark
        ? Colors.white.withValues(alpha: floating ? 0.10 : 0.07)
        : Colors.white.withValues(
            alpha: overPicture
                ? (floating ? 0.62 : 0.48)
                : (floating ? 0.80 : 0.66),
          );
    final fill = selected
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
            base,
          )
        : base;

    return BoxDecoration(
      color: fill,
      borderRadius: radius ?? cardRadius,
      border: Border.all(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.40 : 0.28)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.95)),
        width: 1,
      ),
      boxShadow: floating
          ? floatingShadow(theme.brightness)
          : cardShadow(theme.brightness),
    );
  }

  /// The see-through glass of the bars floating at the bottom — navigation and
  /// mini player. Paired with a real blur behind it ([FrostedBar]), so the
  /// list scrolling underneath shows softly through.
  static BoxDecoration frostedBar(ThemeData theme, BorderRadius radius) {
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.55),
      borderRadius: radius,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.90),
      ),
    );
  }

  /// How far the content behind a bottom bar is blurred.
  static const double frostedBlur = 22;

  /// A slightly stronger lift for things that float over content: the
  /// bottom navigation and the mini player.
  static List<BoxShadow> floatingShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x1A101828), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0D101828), blurRadius: 6, offset: Offset(0, 2)),
    ];
  }

  /// [accent] is the user's chosen accent; it defaults to the app's own sage.
  /// [clearPages] makes screens transparent so a background picture set in
  /// Settings shows through them.
  static ThemeData light([
    AccentOption? accentOption,
    bool clearPages = false,
  ]) => _build(
    accentOption: accentOption ?? AccentPalette.options.first,
    clearPages: clearPages,
    brightness: Brightness.light,
    background: lightBackground,
    surface: lightSurface,
    surfaceHigh: lightSurfaceHigh,
    onSurface: lightOnSurface,
    muted: lightMuted,
  );

  static ThemeData dark([
    AccentOption? accentOption,
    bool clearPages = false,
  ]) => _build(
    accentOption: accentOption ?? AccentPalette.options.first,
    clearPages: clearPages,
    brightness: Brightness.dark,
    background: darkBackground,
    surface: darkSurface,
    surfaceHigh: darkSurfaceHigh,
    onSurface: darkOnSurface,
    muted: darkMuted,
  );

  static ThemeData _build({
    required AccentOption accentOption,
    required bool clearPages,
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceHigh,
    required Color onSurface,
    required Color muted,
  }) {
    final isDark = brightness == Brightness.dark;
    final accentColor = isDark ? accentOption.onDark : accentOption.onLight;
    final accentWash = isDark ? accentOption.washDark : accentOption.washLight;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accentOption.onLight,
          brightness: brightness,
        ).copyWith(
          primary: accentColor,
          onPrimary: brightness == Brightness.dark
              ? const Color(0xFF0B1F16)
              : Colors.white,
          primaryContainer: accentWash,
          onPrimaryContainer: accentColor,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: muted,
          surfaceContainerHighest: surfaceHigh,
          outlineVariant: muted.withValues(alpha: 0.16),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: clearPages ? Colors.transparent : background,
      // The real page colour, for screens that must stay solid (the player).
      canvasColor: background,
    );

    // A clear step between screen title, item title and metadata.
    final text = base.textTheme
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            height: 1.1,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            height: 1.15,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            height: 1.32,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            letterSpacing: -0.05,
            height: 1.35,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 12.5,
            letterSpacing: 0,
            height: 1.3,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: clearPages ? Colors.transparent : background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        titleSpacing: pageMargin + 4,
        titleTextStyle: text.headlineMedium?.copyWith(
          fontSize: 26,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurface, size: 23),
        actionsIconTheme: IconThemeData(color: onSurface, size: 23),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      // The Android page transition paints a solid colour behind the incoming
      // page, which flashed the plain background before the picture. Over a
      // picture that colour has to be clear.
      pageTransitionsTheme: clearPages
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
                  fallbackColor: Colors.transparent,
                ),
              },
            )
          : null,
      // Back buttons across the app become the same floating glass circle as
      // the header actions. Arrow icons mirror themselves in Arabic.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => Container(
          width: 42,
          height: 42,
          decoration: glassSurface(
            Theme.of(context),
            radius: BorderRadius.circular(21),
            floating: true,
          ),
          child: const AppIcon(AppIcons.arrow_back_rounded, size: 21),
        ),
        closeButtonIconBuilder: (context) => Container(
          width: 42,
          height: 42,
          decoration: glassSurface(
            Theme.of(context),
            radius: BorderRadius.circular(21),
            floating: true,
          ),
          child: const AppIcon(AppIcons.close_rounded, size: 21),
        ),
      ),
      cardTheme: CardThemeData(
        // Same milky glass as the video cards, so settings and info pages are
        // part of the same family. Flat: a shadow under a translucent card
        // would show through it as a grey smudge.
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        iconColor: muted,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: muted.withValues(alpha: 0.14),
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: onSurface, size: 23),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        // Dims the page as lightly as the bottom sheets do.
        barrierColor: Colors.black.withValues(alpha: 0.28),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
      ),
      // Text fields are glass too: a milky fill with a bright hairline edge.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.72),
        hintStyle: TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: pillRadius,
          borderSide: BorderSide(color: _glassEdge(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: pillRadius,
          borderSide: BorderSide(color: _glassEdge(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: pillRadius,
          borderSide: BorderSide(color: accentColor, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: pillRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: pillRadius),
      ),
      // A soft switch: white thumb on the accent when on, on a translucent
      // glass track when off, with no outline.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : (isDark ? const Color(0xFFD9DBD8) : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accentColor
              : (isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : onSurface.withValues(alpha: 0.12)),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      // Round ticks, the same as the selection marks on the cards.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accentColor
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: muted.withValues(alpha: 0.6), width: 1.6),
        shape: const CircleBorder(),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accentColor : muted,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentColor,
        inactiveTrackColor: muted.withValues(alpha: 0.25),
        thumbColor: accentColor,
        overlayColor: accentColor.withValues(alpha: 0.16),
        trackHeight: 3,
      ),
      // Chips are the same glass pills as the filters on Home.
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.72),
        selectedColor: Color.alphaBlend(
          accentColor.withValues(alpha: isDark ? 0.24 : 0.16),
          isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.72),
        ),
        checkmarkColor: accentColor,
        side: BorderSide(color: _glassEdge(isDark)),
        shape: RoundedRectangleBorder(borderRadius: pillRadius),
        labelStyle: text.labelLarge?.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: pillRadius),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        refreshBackgroundColor: isDark ? surfaceHigh : Colors.white,
      ),
      // Tooltips are small frosted pills.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark
              ? surfaceHigh.withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: pillRadius,
          border: Border.all(color: _glassEdge(isDark)),
          boxShadow: floatingShadow(brightness),
        ),
        textStyle: TextStyle(
          color: onSurface,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      // The notice after an action floats as a milky glass card with the
      // app's text colours, instead of a solid dark bar.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: isDark
            ? Color.alphaBlend(Colors.white.withValues(alpha: 0.10), surface)
            : Colors.white.withValues(alpha: 0.96),
        contentTextStyle: TextStyle(
          color: onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: accentColor,
        closeIconColor: muted,
        insetPadding: const EdgeInsets.fromLTRB(
          pageMargin,
          0,
          pageMargin,
          space12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: _glassEdge(isDark)),
        ),
      ),
    );
  }

  /// The bright hairline around a glass control.
  static Color _glassEdge(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.10)
      : Colors.white.withValues(alpha: 0.95);
}

/// Convenience accessors so widgets stop re-deriving the same colours.
extension AppColors on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// The one accent colour, already correct for the current theme.
  Color get accent => Theme.of(this).colorScheme.primary;

  /// Pastel wash used behind selected pills and navigation items.
  Color get accentWash => Theme.of(this).colorScheme.primaryContainer;

  /// Secondary text and inactive icons.
  Color get muted => Theme.of(this).colorScheme.onSurfaceVariant;

  List<BoxShadow> get cardShadow =>
      AppTheme.cardShadow(Theme.of(this).brightness);

  List<BoxShadow> get floatingShadow =>
      AppTheme.floatingShadow(Theme.of(this).brightness);

  BoxDecoration glassSurface({
    BorderRadius? radius,
    bool selected = false,
    bool floating = false,
  }) => AppTheme.glassSurface(
    Theme.of(this),
    radius: radius,
    selected: selected,
    floating: floating,
  );
}
