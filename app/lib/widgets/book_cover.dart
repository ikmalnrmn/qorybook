import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/book.dart';
import '../services/labels.dart';
import '../theme.dart';

/// Sampul buku dengan cadangan berwarna bila gambar gagal dimuat.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.radius = 16, this.decodeWidth = 360});

  final Book book;
  final double radius;
  final int decodeWidth;

  /// Dimatikan di widget test yang tidak punya jaringan.
  @visibleForTesting
  static bool networkImages = true;

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(book: book);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (book.cover.isEmpty || !networkImages)
              fallback
            else
              CachedNetworkImage(
                imageUrl: book.coverUrl,
                httpHeaders: const {'User-Agent': AppConfig.userAgent},
                fit: BoxFit.cover,
                memCacheWidth: decodeWidth,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, _) => Container(color: themeColor(book.title).withValues(alpha: 0.18)),
                errorWidget: (_, _, _) => fallback,
              ),
            if (book.format != BookFormat.pdf || book.kind == 'komik')
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(kindEmoji(book.kind), style: const TextStyle(fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final color = themeColor(book.title);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.25)!],
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, c) {
          // Ukuran ikut lebar sampul: dari kartu kecil di rak sampai detail.
          final small = c.maxWidth < 110;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                book.themes.isNotEmpty ? themeEmoji(book.themes.first) : kindEmoji(book.kind),
                style: TextStyle(fontSize: (c.maxWidth * 0.28).clamp(18.0, 48.0)),
              ),
              SizedBox(height: small ? 4 : 8),
              Flexible(
                child: Text(
                  book.title,
                  textAlign: TextAlign.center,
                  maxLines: small ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: (small ? Theme.of(context).textTheme.labelSmall : Theme.of(context).textTheme.titleSmall)
                      ?.copyWith(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Bilah progres membulat.
class RoundedProgress extends StatelessWidget {
  const RoundedProgress({super.key, required this.value, this.color = QColors.primary, this.height = 6});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
  }
}
