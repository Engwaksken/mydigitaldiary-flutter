import 'api_client.dart';

class SocialMediaPlannerService {
  const SocialMediaPlannerService();

  bool _isMissingRoute(Object error) =>
      error is ApiException &&
      error.statusCode == 404 &&
      error.message.toLowerCase().contains('route');

  Never _socialApiMissing(String endpoint) {
    throw ApiException(
      404,
      'Social Media API is not enabled on Laravel yet: $endpoint',
    );
  }

  Future<List<Map<String, dynamic>>> posts() async {
    final response = await ApiClient.instance.get(
      'social-media-planner',
      cacheable: false,
    );
    dynamic raw = response;
    if (raw is Map && raw['data'] is List) raw = raw['data'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, String> _postFields({
    required String title,
    required String caption,
    required String hashtags,
    required List<String> platforms,
    DateTime? scheduledAt,
    required String postingMode,
    String? linkUrl,
    bool removeMedia = false,
  }) {
    final fields = <String, String>{
      'title': title.trim(),
      'caption': caption.trim(),
      'hashtags': hashtags.trim(),
      'approval_status': 'approved',
      'posting_mode': postingMode,
      'link_url': linkUrl?.trim() ?? '',
      'remove_media': removeMedia ? '1' : '0',
      if (scheduledAt != null)
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    };

    for (var index = 0; index < platforms.length; index++) {
      fields['platforms[$index]'] = platforms[index];
    }

    return fields;
  }

  Future<Map<String, dynamic>> create({
    required String title,
    required String caption,
    required String hashtags,
    required List<String> platforms,
    DateTime? scheduledAt,
    String postingMode = 'manual',
    String? linkUrl,
    List<int>? attachmentBytes,
    String? attachmentName,
    String? attachmentContentType,
  }) async {
    final response = await ApiClient.instance.multipart(
      'social-media-planner',
      fields: _postFields(
        title: title,
        caption: caption,
        hashtags: hashtags,
        platforms: platforms,
        scheduledAt: scheduledAt,
        postingMode: postingMode,
        linkUrl: linkUrl,
      ),
      fileFieldName: attachmentBytes == null ? null : 'attachment',
      fileBytes: attachmentBytes,
      fileName: attachmentName,
      contentType: attachmentContentType,
    );
    return _map(response);
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String title,
    required String caption,
    required String hashtags,
    required List<String> platforms,
    DateTime? scheduledAt,
    String postingMode = 'manual',
    String? linkUrl,
    bool removeMedia = false,
    List<int>? attachmentBytes,
    String? attachmentName,
    String? attachmentContentType,
  }) async {
    // A dedicated POST update alias is used for multipart uploads. On many PHP
    // hosts uploaded files in a raw PUT multipart request are not populated in
    // $_FILES, even though JSON PUT requests work normally.
    final response = await ApiClient.instance.multipart(
      'social-media-planner/$id',
      fields: _postFields(
        title: title,
        caption: caption,
        hashtags: hashtags,
        platforms: platforms,
        scheduledAt: scheduledAt,
        postingMode: postingMode,
        linkUrl: linkUrl,
        removeMedia: removeMedia,
      ),
      fileFieldName: attachmentBytes == null ? null : 'attachment',
      fileBytes: attachmentBytes,
      fileName: attachmentName,
      contentType: attachmentContentType,
    );
    return _map(response);
  }

  Future<Map<String, dynamic>> postNow(int id) async {
    final response = await ApiClient.instance.post(
      'social-media-planner/$id/post-now',
      const <String, dynamic>{},
    );
    return _map(response);
  }

  Future<Map<String, dynamic>> markPublished(int id) async {
    final response = await ApiClient.instance.patch(
      'social-media-planner/$id/mark-published',
      const <String, dynamic>{},
    );
    return _map(response);
  }

  Future<void> delete(int id) =>
      ApiClient.instance.delete('social-media-planner/$id');

  Future<void> bulkDelete(List<int> ids) async {
    if (ids.isEmpty) return;
    await ApiClient.instance.post(
      'social-media-planner/bulk-delete',
      <String, dynamic>{'ids': ids},
    );
  }

  Future<Map<String, dynamic>> analytics(int postId) async {
    final response = await ApiClient.instance.get(
      'social-media-planner/$postId/analytics',
      cacheable: false,
    );
    return _map(response);
  }

  Future<Map<String, dynamic>> syncPostAnalytics(int postId) async {
    final response = await ApiClient.instance.post(
      'social-media-planner/$postId/analytics/sync',
      const <String, dynamic>{},
    );
    return _map(response);
  }

  Future<void> updateAnalytics({
    required int postId,
    required String platform,
    int views = 0,
    int reach = 0,
    int impressions = 0,
    int likes = 0,
    int comments = 0,
    int shares = 0,
    int saves = 0,
    int clicks = 0,
    int replies = 0,
    String? externalPostId,
  }) async {
    await ApiClient.instance.put(
      'social-media-planner/$postId/analytics',
      <String, dynamic>{
        'platform': platform,
        'views': views,
        'reach': reach,
        'impressions': impressions,
        'likes': likes,
        'comments': comments,
        'shares': shares,
        'saves': saves,
        'clicks': clicks,
        'replies': replies,
        'external_post_id': externalPostId ?? '',
      },
    );
  }

  Future<Map<String, dynamic>> syncAnalytics() async {
    final response = await ApiClient.instance.post(
      'social-media-planner/reports/sync',
      const <String, dynamic>{},
    );
    return _map(response);
  }

  Future<Map<String, dynamic>> report({
    String period = 'month',
    String? platform,
    String? status,
  }) async {
    final query = <String>[
      'period=${Uri.encodeQueryComponent(period)}',
      if (platform != null && platform.isNotEmpty)
        'platform=${Uri.encodeQueryComponent(platform)}',
      if (status != null && status.isNotEmpty)
        'status=${Uri.encodeQueryComponent(status)}',
    ].join('&');

    final response = await ApiClient.instance.get(
      'social-media-planner/reports?$query',
      cacheable: false,
    );
    return _map(response);
  }

  Future<List<Map<String, dynamic>>> readyToShare() async {
    final response = await ApiClient.instance.get(
      'social-media-planner/ready-to-share',
      cacheable: false,
    );
    dynamic raw = response;
    if (raw is Map && raw['data'] is List) raw = raw['data'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> profileAccounts() async {
    try {
      final response = await ApiClient.instance.get(
        'profile/social-media',
        cacheable: false,
      );
      return _map(response);
    } catch (error) {
      if (_isMissingRoute(error)) {
        _socialApiMissing('GET /api/profile/social-media');
      }
      rethrow;
    }
  }

  Future<void> saveWhatsApp({
    String? number,
    String? channelName,
    String? channelUrl,
  }) async {
    try {
      await ApiClient.instance.put(
        'profile/social-media/whatsapp',
        <String, dynamic>{
          'whatsapp_number': number?.trim() ?? '',
          'whatsapp_channel_name': channelName?.trim() ?? '',
          'whatsapp_channel_url': channelUrl?.trim() ?? '',
        },
      );
    } catch (error) {
      if (_isMissingRoute(error)) {
        _socialApiMissing('PUT /api/profile/social-media/whatsapp');
      }
      rethrow;
    }
  }

  Future<void> addAccount({
    required String platform,
    required String accountName,
    String? username,
    String? externalAccountId,
    String? providerAccountRef,
  }) async {
    await ApiClient.instance.post(
      'profile/social-media/accounts',
      <String, dynamic>{
        'platform': platform,
        'account_name': accountName.trim(),
        'username': username?.trim() ?? '',
        'external_account_id': externalAccountId?.trim() ?? '',
        'provider_account_ref': providerAccountRef?.trim() ?? '',
      },
    );
  }

  Future<Map<String, dynamic>> updateAutomaticPublishing({
    required int accountId,
    required bool enabled,
    String? externalAccountId,
    String? providerAccountRef,
  }) async {
    final response = await ApiClient.instance.put(
      'profile/social-media/accounts/$accountId/automatic-publishing',
      <String, dynamic>{
        'enabled': enabled,
        'external_account_id': externalAccountId?.trim() ?? '',
        'provider_account_ref': providerAccountRef?.trim() ?? '',
      },
    );

    return _map(response);
  }

  Future<void> removeAccount(int id) =>
      ApiClient.instance.delete('profile/social-media/accounts/$id');

  Future<Map<String, dynamic>> adminOverview() async {
    try {
      final response = await ApiClient.instance.get(
        'admin/social-media',
        cacheable: false,
      );
      return _map(response);
    } catch (error) {
      if (_isMissingRoute(error)) {
        _socialApiMissing('GET /api/admin/social-media');
      }
      rethrow;
    }
  }

  Future<void> adminUpdateUserWhatsApp({
    required int userId,
    String? number,
    String? channelName,
    String? channelUrl,
  }) async {
    await ApiClient.instance.put(
      'admin/social-media/users/$userId/whatsapp',
      <String, dynamic>{
        'whatsapp_number': number?.trim() ?? '',
        'whatsapp_channel_name': channelName?.trim() ?? '',
        'whatsapp_channel_url': channelUrl?.trim() ?? '',
      },
    );
  }

  Future<void> adminRemoveAccount({
    required int userId,
    required int accountId,
  }) async {
    await ApiClient.instance.delete(
      'admin/social-media/users/$userId/accounts/$accountId',
    );
  }

  Map<String, dynamic> _map(dynamic response) {
    if (response is Map && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }
    if (response is Map) return Map<String, dynamic>.from(response);
    return <String, dynamic>{};
  }
}
