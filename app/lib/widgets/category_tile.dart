import 'package:flutter/material.dart';

/// Ubin kategori berwarna dengan emoji besar.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.compact = false,
  });

  final String emoji;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Color.lerp(color, Colors.black, 0.18)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, dark]),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -6,
                bottom: compact ? -10 : -8,
                child: Text(emoji, style: TextStyle(fontSize: compact ? 44 : 56)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, compact ? 10 : 14, compact ? 44 : 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: (compact ? text.titleSmall : text.titleMedium)?.copyWith(color: Colors.white),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
