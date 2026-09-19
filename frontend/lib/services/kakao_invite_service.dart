import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';

import '../models/friend.dart';
import '../models/shared_route.dart';

class KakaoInviteService {
  Future<void> share({
    required FriendInvite invite,
    required String inviterNickname,
    Rect? sharePositionOrigin,
  }) async {
    final text = '$inviterNickname님이 경주한적에서 같이 여행하자고 초대했어요.\n'
        '앱에서 친구로 연결한 뒤 같은 코스를 함께 확인할 수 있어요.\n'
        '${invite.inviteUrl}';

    final inviteUri = Uri.tryParse(invite.inviteUrl);

    if (inviteUri != null && inviteUri.scheme == 'https') {
      final template = TextTemplate(
        text: '$inviterNickname님이 경주한적에서 같이 여행하자고 초대했어요. '
            '친구로 연결하고 함께 경주 코스를 만들어보세요.',
        link: Link(
          webUrl: inviteUri,
          mobileWebUrl: inviteUri,
        ),
        buttonTitle: '초대 확인하기',
      );

      try {
        final available = await ShareClient.instance.isKakaoTalkSharingAvailable();
        if (available) {
          await ShareClient.instance.shareDefault(template: template);
          return;
        }

        final shareUrl = await WebSharerClient.instance.makeDefaultUrl(
          template: template,
        );
        await launchBrowser(shareUrl);
        return;
      } catch (_) {
        // 개발 중 도메인 미등록/카카오톡 미설치 상황에서는
        // 시스템 공유창으로 내려가 카카오톡을 직접 선택할 수 있게 합니다.
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        title: '경주한적 동행 초대',
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> shareRouteInvite({
    required RouteCompanionInvite invite,
    required String inviterNickname,
    required String routeTitle,
    Rect? sharePositionOrigin,
  }) async {
    final text = '$inviterNickname님이 경주한적 코스에 동행으로 초대했어요.\n'
        '$routeTitle\n'
        '앱에서 초대를 수락하면 같은 코스를 함께 확인하고 수정할 수 있어요.\n'
        '${invite.inviteUrl}';

    final inviteUri = Uri.tryParse(invite.inviteUrl);

    if (inviteUri != null && inviteUri.scheme == 'https') {
      final template = TextTemplate(
        text: '$inviterNickname님이 경주한적의 “$routeTitle” 코스에 동행으로 초대했어요. '
            '초대를 수락하고 같은 코스를 함께 확인해보세요.',
        link: Link(
          webUrl: inviteUri,
          mobileWebUrl: inviteUri,
        ),
        buttonTitle: '동행 초대 확인하기',
      );

      try {
        final available = await ShareClient.instance.isKakaoTalkSharingAvailable();
        if (available) {
          await ShareClient.instance.shareDefault(template: template);
          return;
        }

        final shareUrl = await WebSharerClient.instance.makeDefaultUrl(
          template: template,
        );
        await launchBrowser(shareUrl);
        return;
      } catch (_) {
        // 개발 중에는 시스템 공유창으로 fallback합니다.
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        title: '경주한적 코스 동행 초대',
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

}
