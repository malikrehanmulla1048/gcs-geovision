import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── LIVE DOT (blinking red indicator) ────────────────────────────────────
class LiveDot extends StatefulWidget {
  final Color color;
  const LiveDot({super.key, this.color = GeoColors.danger});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: .2).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: Container(
      width: 7, height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

// ── LIVE BADGE ─────────────────────────────────────────────────────────
class LiveBadge extends StatelessWidget {
  final String label;
  const LiveBadge({super.key, this.label = 'LIVE'});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: GeoColors.dangerGhost,
      borderRadius: BorderRadius.circular(GeoRadius.full),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const LiveDot(),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w700, color: GeoColors.danger,
      )),
    ]),
  );
}

// ── SECTION CARD ──────────────────────────────────────────────────────
class SectionCard extends StatelessWidget {
  final String title;
  final String? count;
  final bool redCount;
  final String? linkLabel;
  final VoidCallback? onLink;
  final Widget child;
  final ThemeNotifier theme;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    required this.theme,
    this.count,
    this.redCount = false,
    this.linkLabel,
    this.onLink,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text(title, style: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w700, color: theme.textPrimary,
          )),
          if (count != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: redCount ? GeoColors.dangerGhost : theme.bgBadge,
                borderRadius: BorderRadius.circular(GeoRadius.full),
              ),
              child: Text(count!, style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: redCount ? GeoColors.danger : theme.textSecondary,
              )),
            ),
          ],
          const Spacer(),
          if (linkLabel != null)
            GestureDetector(
              onTap: onLink,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: GeoColors.primaryGhost),
                  borderRadius: BorderRadius.circular(GeoRadius.sm),
                ),
                child: Text(linkLabel!, style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: GeoColors.primary,
                )),
              ),
            ),
        ]),
      ),
      Divider(height: 1, color: theme.border),
      Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    ]),
  );
}

// ── STAT CARD ─────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final String? trend;
  final bool trendUp;
  final Color? iconBg;
  final Color? iconColor;
  final ThemeNotifier theme;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.theme,
    this.trend,
    this.trendUp = true,
    this.iconBg,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: iconBg ?? theme.bgBadge,
            borderRadius: BorderRadius.circular(GeoRadius.sm),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 13))),
        ),
        if (trend != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: trendUp ? GeoColors.successGhost : GeoColors.dangerGhost,
              borderRadius: BorderRadius.circular(GeoRadius.full),
            ),
            child: Text(trend!, style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: trendUp ? GeoColors.success : GeoColors.danger,
            )),
          ),
      ]),
      const SizedBox(height: 16),
      Text(value, style: GoogleFonts.inter(
        fontSize: 34, fontWeight: FontWeight.w800,
        letterSpacing: -1, height: 1, color: theme.textPrimary,
      )),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: theme.textSecondary,
      )),
    ]),
  );
}

// ── HEALTH PROGRESS CARD ──────────────────────────────────────────────
class HealthCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final double progress; // 0-1
  final Color barColor;
  final String status; // 'online' | 'offline' | 'degraded'
  final ThemeNotifier theme;

  const HealthCard({
    super.key,
    required this.label, required this.value, required this.sub,
    required this.progress, required this.barColor, required this.status,
    required this.theme,
  });

  Color get dotColor => switch (status) {
    'online'   => GeoColors.success,
    'offline'  => GeoColors.danger,
    'degraded' => GeoColors.warning,
    _ => GeoColors.success,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.bgCard,
      border: Border.all(color: theme.border),
      borderRadius: BorderRadius.circular(GeoRadius.lg),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: theme.textSecondary,
        )),
        Container(width: 10, height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dotColor.withOpacity(.5), blurRadius: 6)],
          )),
      ]),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(GeoRadius.full),
        child: LinearProgressIndicator(
          value: progress, minHeight: 6,
          backgroundColor: theme.bgBadge,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
      const SizedBox(height: 10),
      Text(value, style: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w800, color: theme.textPrimary,
      )),
      Text(sub, style: GoogleFonts.inter(
        fontSize: 11, color: theme.textTertiary,
      )),
    ]),
  );
}

// ── AVATAR CIRCLE ─────────────────────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String initials;
  final List<Color> gradient;
  final double size;
  final double fontSize;

  const AvatarCircle({
    super.key,
    required this.initials,
    required this.gradient,
    this.size = 36,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Text(initials, style: GoogleFonts.inter(
      fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white,
    ))),
  );
}

// ── STATUS BADGE ──────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const StatusBadge({super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(GeoRadius.full),
    ),
    child: Text(label, style: GoogleFonts.inter(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: fg, letterSpacing: .5,
    )),
  );
}

// ── TOAST ─────────────────────────────────────────────────────────────
class GeoToast {
  static void show(BuildContext context, String message, {String type = 'info'}) {
    final color = switch (type) {
      'success' => GeoColors.success,
      'error'   => GeoColors.danger,
      _ => const Color(0xFF333333),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white,
      )),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GeoRadius.md)),
      duration: const Duration(milliseconds: 3200),
    ));
  }
}

// ── GEO BUTTON ────────────────────────────────────────────────────────
class GeoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outline;
  final bool danger;
  final double? width;

  const GeoButton({
    super.key, required this.label, this.onPressed,
    this.loading = false, this.outline = false, this.danger = false, this.width,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? GeoColors.danger : GeoColors.primary;
    return SizedBox(
      width: width ?? double.infinity,
      child: outline
          ? OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GeoRadius.md)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _child(color),
            )
          : ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GeoRadius.md)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _child(Colors.white),
            ),
    );
  }

  Widget _child(Color textColor) => loading
      ? const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : Text(label, style: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w800, color: textColor,
        ));
}
