import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../models/contribution_models.dart';

/// API calls for the contribution round.
///
/// Kept separate from [ApiService] so the contribution feature can be read and
/// changed on its own — that file is already large and covers a different
/// concern.
class ContributionsApi {
  static const _storage = FlutterSecureStorage();

  static Future<Dio> _dio() async {
    final token = await _storage.read(key: 'auth_token');

    return Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      // Sending cards uploads an image to WhatsApp per contributor, so the
      // bulk calls need a longer leash than a normal request.
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
    ));
  }

  /// An empty PHP associative array encodes as `[]`, so a response that should
  /// be an object can arrive as a list. Fall back to empty instead of throwing.
  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  /// Surface the server's own wording — it explains *why* something failed
  /// (no template, no SMS body, outside the 24h window) far better than we can.
  static String _error(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'No connection. Check your internet and try again.';
    }

    return fallback;
  }

  /// The whole screen in one call — list, stats, settings and known groups.
  /// Mobile round-trips are expensive, so this deliberately over-fetches.
  static Future<ContributionsPage> fetch(
    int eventId, {
    String? status,
    String? group,
    String? search,
    int page = 1,
  }) async {
    final dio = await _dio();

    try {
      final res = await dio.get('/events/$eventId/contributions', queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (group != null && group.isNotEmpty) 'group': group,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'per_page': 100,
      });

      return ContributionsPage.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not load the contribution list'));
    }
  }

  static Future<ContributionStats> stats(int eventId) async {
    final dio = await _dio();

    try {
      final res = await dio.get('/events/$eventId/contributions/stats');
      return ContributionStats.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not load the totals'));
    }
  }

  static Future<Contributor> add(
    int eventId, {
    required String name,
    required String phoneNumber,
    String? group,
    double? amount,
    bool? isOnWhatsapp,
    String? notes,
  }) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors', data: {
        'name': name,
        'phone_number': phoneNumber,
        if (group != null && group.isNotEmpty) 'group': group,
        if (amount != null) 'amount': amount,
        if (isOnWhatsapp != null) 'is_on_whatsapp': isOnWhatsapp,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      return Contributor.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not add this contributor'));
    }
  }

  /// Read a typed list without saving, so the phone can show what the server
  /// understood before anything is written.
  static Future<List<ParsedLine>> parseLines(int eventId, String text) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors/parse', data: {'text': text});
      final rows = (res.data['rows'] as List?) ?? [];

      return rows.map((e) => ParsedLine.fromJson(_map(e))).toList();
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not read that list'));
    }
  }

  static Future<String> addMany(int eventId, String text) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors/bulk', data: {'text': text});
      return res.data['message']?.toString() ?? 'Contributors added.';
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not add those contributors'));
    }
  }

  static Future<Contributor> update(
    int pledgeId, {
    String? name,
    String? phoneNumber,
    String? group,
    double? amount,
    String? status,
    String? notes,
  }) async {
    final dio = await _dio();

    try {
      final res = await dio.put('/contributors/$pledgeId', data: {
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'group': (group == null || group.isEmpty) ? null : group,
        'amount': amount,
        if (status != null) 'status': status,
        'notes': (notes == null || notes.isEmpty) ? null : notes,
      });

      return Contributor.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not save the changes'));
    }
  }

  static Future<void> remove(int pledgeId) async {
    final dio = await _dio();

    try {
      await dio.delete('/contributors/$pledgeId');
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not remove this contributor'));
    }
  }

  /// Card image URL, the link its QR points at, and a ready-made share caption.
  static Future<CardShare> card(int pledgeId) async {
    final dio = await _dio();

    try {
      final res = await dio.get('/contributors/$pledgeId/card');
      return CardShare.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not load the card'));
    }
  }

  static Future<String> sendCard(int pledgeId) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/contributors/$pledgeId/send-card');
      return res.data['message']?.toString() ?? 'Card sent.';
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not send the card'));
    }
  }

  static Future<String> sendCards(int eventId, List<int> pledgeIds) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors/bulk-send-cards',
          data: {'pledge_ids': pledgeIds});

      return res.data['message']?.toString() ?? 'Cards queued for sending.';
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not send the cards'));
    }
  }

  static Future<String> sendReminders(int eventId, List<int> pledgeIds) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors/send-reminders',
          data: {'pledge_ids': pledgeIds});

      return res.data['message']?.toString() ?? 'Reminders sent.';
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not send the reminders'));
    }
  }

  static Future<Contributor> recordPayment(
    int pledgeId, {
    required double amount,
    required String method,
    String? reference,
    String? paidAt,
    String? notes,
  }) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/contributors/$pledgeId/payments', data: {
        'amount': amount,
        'method': method,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (paidAt != null) 'paid_at': paidAt,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      return Contributor.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not record the payment'));
    }
  }

  static Future<Contributor> deletePayment(int contributionId) async {
    final dio = await _dio();

    try {
      final res = await dio.delete('/contribution-payments/$contributionId');
      return Contributor.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not remove the payment'));
    }
  }

  static Future<ContributionSettings> settings(int eventId) async {
    final dio = await _dio();

    try {
      final res = await dio.get('/events/$eventId/contribution-settings');
      return ContributionSettings.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not load the settings'));
    }
  }

  static Future<ContributionSettings> saveSettings(int eventId, ContributionSettings s) async {
    final dio = await _dio();

    try {
      final res = await dio.put('/events/$eventId/contribution-settings', data: {
        'contribution_mode': s.mode,
        'contribution_status': s.status,
        'contribution_target': s.target,
        'contribution_deadline': s.deadline,
        'settings': {
          'currency': s.currency,
          'min_amount': s.minAmount,
          'appeal_text': s.appealText,
          'kikao_date': s.kikaoDate,
          'kikao_time': s.kikaoTime,
          'kikao_venue': s.kikaoVenue,
          // Drop blank rows so an empty repeater field never reaches the card.
          'payment_methods':
              s.paymentMethods.where((m) => m.number.trim().isNotEmpty).map((m) => m.toJson()).toList(),
          'committee_contacts':
              s.committeeContacts.where((c) => c.phone.trim().isNotEmpty).map((c) => c.toJson()).toList(),
        },
      });

      return ContributionSettings.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not save the settings'));
    }
  }

  static Future<void> saveMessages(int eventId, ContributionSettings s) async {
    final dio = await _dio();

    try {
      await dio.put('/events/$eventId/contribution-messages', data: {
        'message': s.smsMessage,
        'whatsapp_message': s.whatsappMessage,
        'reminder_message': s.reminderMessage,
        'whatsapp_template_name': s.whatsappTemplateName,
        'whatsapp_body_param_name': s.whatsappBodyParamName,
        'whatsapp_has_body_param': s.whatsappHasBodyParam,
      });
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not save the messages'));
    }
  }

  static Future<String> promote(
    int eventId,
    List<int> pledgeIds, {
    int defaultGuests = 1,
    bool closeRound = false,
  }) async {
    final dio = await _dio();

    try {
      final res = await dio.post('/events/$eventId/contributors/promote', data: {
        'pledge_ids': pledgeIds,
        'default_guests': defaultGuests,
        'close_round': closeRound,
      });

      return res.data['message']?.toString() ?? 'Added to the guest list.';
    } on DioException catch (e) {
      throw Exception(_error(e, 'Could not add them to the guest list'));
    }
  }
}

/// One page of the contribution list, with everything the screen needs.
class ContributionsPage {
  final List<Contributor> contributors;
  final ContributionStats stats;
  final ContributionSettings? settings;
  final List<String> groups;
  final bool canSend;
  final int currentPage;
  final int lastPage;
  final int total;

  ContributionsPage({
    required this.contributors,
    required this.stats,
    required this.groups,
    required this.canSend,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.settings,
  });

  factory ContributionsPage.fromJson(Map<String, dynamic> json) {
    final list = (json['contributors'] as List?) ?? [];
    final meta = Map<String, dynamic>.from(json['meta'] ?? {});

    return ContributionsPage(
      contributors: list.map((e) => Contributor.fromJson(Map<String, dynamic>.from(e))).toList(),
      stats: ContributionStats.fromJson(Map<String, dynamic>.from(json['stats'] ?? {})),
      settings: json['settings'] == null
          ? null
          : ContributionSettings.fromJson(Map<String, dynamic>.from(json['settings'])),
      groups: ((json['groups'] as List?) ?? []).map((e) => e.toString()).toList(),
      canSend: json['can_send'] == true,
      currentPage: int.tryParse('${meta['current_page'] ?? 1}') ?? 1,
      lastPage: int.tryParse('${meta['last_page'] ?? 1}') ?? 1,
      total: int.tryParse('${meta['total'] ?? list.length}') ?? list.length,
    );
  }

  bool get hasMore => currentPage < lastPage;
}

class CardShare {
  final String cardUrl;
  final String contributeUrl;
  final String shareText;

  CardShare({required this.cardUrl, required this.contributeUrl, required this.shareText});

  factory CardShare.fromJson(Map<String, dynamic> json) => CardShare(
        cardUrl: json['card_url']?.toString() ?? '',
        contributeUrl: json['contribute_url']?.toString() ?? '',
        shareText: json['share_text']?.toString() ?? '',
      );
}
