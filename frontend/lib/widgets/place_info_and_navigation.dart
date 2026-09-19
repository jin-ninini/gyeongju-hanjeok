import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_navi/kakao_flutter_sdk_navi.dart';

class InfoConfidenceBadge extends StatelessWidget {
  const InfoConfidenceBadge({
    super.key,
    required this.confidence,
    this.label,
  });

  final String? confidence;
  final String? label;

  String get _label {
    if (label != null && label!.trim().isNotEmpty) {
      return label!;
    }

    switch (confidence) {
      case 'high':
        return '공식 정보';
      case 'medium':
        return '공식·보조 정보';
      case 'low':
        return '참고 정보';
      default:
        return '확인 필요';
    }
  }

  IconData get _icon {
    switch (confidence) {
      case 'high':
        return Icons.verified_rounded;
      case 'medium':
        return Icons.fact_check_outlined;
      case 'low':
        return Icons.info_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String get _tooltip {
    switch (confidence) {
      case 'high':
        return '한국관광공사 또는 공식 홈페이지에서 확인한 정보입니다.';
      case 'medium':
        return '공식 정보와 검색 보조 자료를 함께 사용한 정보입니다.';
      case 'low':
        return '복수의 비공식 자료에서 일치한 참고 정보입니다. 방문 전 재확인을 권장합니다.';
      default:
        return '확인 가능한 근거가 부족한 정보입니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: _tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KakaoNavigationService {
  const KakaoNavigationService._();

  /// 자동차: 사용자의 현재 위치에서 목적지까지 Kakao Navi로 안내합니다.
  static Future<void> startDrivingNavigation({
    required String destinationName,
    required double latitude,
    required double longitude,
  }) async {
    final installed =
        await NaviApi.instance.isKakaoNaviInstalled();

    if (!installed) {
      await launchBrowser(
        Uri.parse(NaviApi.webNaviInstall),
      );
      return;
    }

    await NaviApi.instance.navigate(
      destination: Location(
        name: destinationName,
        x: longitude.toString(),
        y: latitude.toString(),
      ),
      option: NaviOption(
        coordType: CoordType.wgs84,
      ),
    );
  }

  /// 도보/대중교통: 백엔드 Kakao Map REST API가 반환한 landingURL을 엽니다.
  static Future<void> openKakaoMapRoute(
    String navigationUrl,
  ) async {
    final uri = Uri.tryParse(navigationUrl);

    if (uri == null) {
      throw const FormatException(
        '올바르지 않은 카카오맵 길찾기 URL입니다.',
      );
    }

    await launchBrowser(uri);
  }
}

class KakaoNavigationButton extends StatefulWidget {
  const KakaoNavigationButton({
    super.key,
    required this.destinationName,
    required this.latitude,
    required this.longitude,
    required this.transport,
    this.navigationUrl,
  });

  final String destinationName;
  final double latitude;
  final double longitude;
  final String transport;
  final String? navigationUrl;

  @override
  State<KakaoNavigationButton> createState() =>
      _KakaoNavigationButtonState();
}

class _KakaoNavigationButtonState
    extends State<KakaoNavigationButton> {
  bool _loading = false;

  Future<void> _start() async {
    if (_loading) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      if (widget.transport == 'driving') {
        await KakaoNavigationService.startDrivingNavigation(
          destinationName: widget.destinationName,
          latitude: widget.latitude,
          longitude: widget.longitude,
        );
        return;
      }

      final url = widget.navigationUrl;

      if (url == null || url.trim().isEmpty) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '카카오맵 길찾기 정보를 불러오지 못했습니다.',
            ),
          ),
        );
        return;
      }

      await KakaoNavigationService.openKakaoMapRoute(
        url,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '길안내를 시작하지 못했습니다: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : _start,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Icon(
                Icons.navigation_rounded,
              ),
        label: Text(
          _loading
              ? '길안내 준비 중...'
              : '길안내 시작',
        ),
      ),
    );
  }
}
