import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/place.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
          ),
          child: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          '경주한적',
          style: TextStyle(
            color: AppColors.forest,
            fontWeight: FontWeight.w900,
            fontSize: compact ? 19 : 21,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                color: AppColors.forestLight,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class QuietBadge extends StatelessWidget {
  const QuietBadge({required this.score, this.compact = false, super.key});

  final int score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // PlaceCard에는 quietScore(한적도)가 들어오므로,
    // 사용자에게는 실제 혼잡도 = 100 - 한적도로 표시합니다.
    final congestion = (100 - score).clamp(0, 100).toInt();
    final color = congestion <= 20
        ? AppColors.success
        : congestion <= 35
            ? AppColors.warning
            : AppColors.danger;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x16000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '혼잡도 $congestion%',
            style: TextStyle(
              color: AppColors.forest,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class PlaceImage extends StatelessWidget {
  const PlaceImage({
    required this.place,
    this.fit = BoxFit.cover,
    this.hero = true,
    super.key,
  });

  final Place place;
  final BoxFit fit;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (place.imageUrl.isNotEmpty) {
      image = Image.network(
        place.imageUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallback(showLoader: true);
        },
      );
    } else if (place.imageAsset.isNotEmpty) {
      image = Image.asset(
        place.imageAsset,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else {
      image = _fallback();
    }

    if (!hero) return image;
    return Hero(tag: 'place-image-${place.id}', child: image);
  }

  Widget _fallback({bool showLoader = false}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB7CEC3), Color(0xFF476F60)],
        ),
      ),
      child: Center(
        child: showLoader
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Icon(Icons.landscape_outlined, color: Colors.white, size: 46),
      ),
    );
  }
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({
    required this.place,
    required this.isSaved,
    required this.onTap,
    required this.onSaved,
    this.width = 254,
    super.key,
  });

  final Place place;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSaved;
  final double width;

  String _operatingHoursLabel(Place place) {
    final short = place.operatingHoursLabel.trim();
    if (short.isNotEmpty) return short;

    final raw = place.operatingHours.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.isEmpty) return '운영시간 확인';
    if (raw.contains('24시간') || raw.contains('상시')) return '상시 개방';

    final match = RegExp(
      r'([01]?\d|2[0-3])[:시]\s*([0-5]?\d)?\s*(?:~|[-–]|부터)\s*([01]?\d|2[0-3])[:시]\s*([0-5]?\d)?',
    ).firstMatch(raw);
    if (match != null) {
      final sh = int.tryParse(match.group(1) ?? '') ?? 0;
      final sm = int.tryParse(match.group(2) ?? '') ?? 0;
      final eh = int.tryParse(match.group(3) ?? '') ?? 0;
      final em = int.tryParse(match.group(4) ?? '') ?? 0;
      return '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}~${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
    }

    return raw.length > 18 ? '${raw.substring(0, 18)}…' : raw;
  }

  bool _hasRelatedContent(Place place) {
    return place.homepage.trim().isNotEmpty || place.contentLinks.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            decoration: softCardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 154,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlaceImage(place: place),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x4D172C25)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: QuietBadge(score: place.quietScore),
                        ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: IconButton.filledTonal(
                            onPressed: onSaved,
                            style: IconButton.styleFrom(
                              backgroundColor: isSaved
                                  ? AppColors.gold
                                  : Colors.black.withValues(alpha: 0.24),
                              foregroundColor: Colors.white,
                            ),
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          place.hasLocalDistance
                              ? '${place.tourismCategory} · ${place.distanceKm.toStringAsFixed(1)}km'
                              : place.tourismCategory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (place.communityReportCount > 0) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              const Icon(Icons.groups_outlined, size: 13, color: AppColors.forest),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  place.communityCongestionScore == null
                                      ? '최근 현장 제보 ${place.communityReportCount}건'
                                      : '현장 제보 ${place.communityReportCount}건 · 체감 ${place.communityCongestionScore!.round()}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.forest,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_hasRelatedContent(place)) ...[
                          const SizedBox(height: 8),
                          _PlaceContentAvailability(place: place),
                        ],
                        const SizedBox(height: 13),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Color(0x2258A17D), blurRadius: 0, spreadRadius: 5),
                                ],
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                place.quietLabel,
                                style: const TextStyle(
                                  color: AppColors.forest,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_outlined,
                                  size: 14,
                                  color: AppColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _operatingHoursLabel(place),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceContentAvailability extends StatelessWidget {
  const _PlaceContentAvailability({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final links = place.contentLinks;
    final hasWebsite = place.homepage.trim().isNotEmpty || links.any((link) {
      final type = link.type.toLowerCase();
      return type.contains('official') || type.contains('website') || type == 'web';
    });
    final linkedBlogCount = links.where((link) {
      final type = link.type.toLowerCase();
      final url = link.url.toLowerCase();
      return type.contains('blog') || url.contains('blog.naver.com');
    }).length;
    final linkedVideoCount = links.where((link) {
      final type = link.type.toLowerCase();
      final url = link.url.toLowerCase();
      return type.contains('youtube') || type.contains('video') || url.contains('youtube.com') || url.contains('youtu.be');
    }).length;
    final blogCount =
        place.blogCount > linkedBlogCount ? place.blogCount : linkedBlogCount;
    final videoCount =
        place.videoCount > linkedVideoCount ? place.videoCount : linkedVideoCount;

    final items = <Widget>[
      if (hasWebsite)
        const _MiniSourceLabel(icon: Icons.language_outlined, label: '웹사이트'),
      if (blogCount > 0)
        _MiniSourceLabel(icon: Icons.article_outlined, label: '블로그 $blogCount'),
      if (videoCount > 0)
        _MiniSourceLabel(icon: Icons.play_circle_outline, label: '영상 $videoCount'),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 5, children: items);
  }
}

class _MiniSourceLabel extends StatelessWidget {
  const _MiniSourceLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.forest, size: 31),
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(description, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
