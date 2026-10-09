import 'package:flutter/material.dart';

import '../../logic/insights.dart';
import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        child: Padding(padding: padding, child: child),
      );
}

class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
          ),
          ?trailing,
        ],
      );
}

/// Baterai horizontal besar dengan isi berwarna sesuai persentase.
class BigBattery extends StatelessWidget {
  const BigBattery({super.key, required this.soc, this.charging = false, this.height = 54});
  final int soc;
  final bool charging;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = Insights.socColor(soc);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: height,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line, width: 2),
              color: AppColors.bg,
            ),
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  // Garis bantu 25/50/75
                  for (final f in [0.25, 0.5, 0.75])
                    Positioned(
                      left: c.maxWidth * f,
                      top: 6,
                      bottom: 6,
                      child: Container(width: 1, color: AppColors.line),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: c.maxWidth * soc.clamp(0, 100) / 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14)],
                    ),
                  ),
                  if (charging)
                    const Center(child: Icon(Icons.bolt_rounded, color: Colors.white, size: 30)),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 7,
          height: height * 0.42,
          margin: const EdgeInsets.only(left: 3),
          decoration: const BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.unit, this.color});
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.accent),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: tabular),
                ),
                if (unit != null)
                  TextSpan(text: ' $unit', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class LevelDot extends StatelessWidget {
  const LevelDot(this.level, {super.key, this.size = 10});
  final Level level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: level.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: level.color.withValues(alpha: 0.5), blurRadius: 6)],
        ),
      );
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 14))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFeatures: tabular)),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      );
}
