import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'config/app_config.dart';

class ApiService {
  static final _storage = const FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<Dio> _dio() async {
    final token = await _getToken();
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    return dio;
  }

  // ─── Events ────────────────────────────────────────────────────────────────

  static Future<List> fetchEvents() async {
    final dio = await _dio();
    try {
      final response = await dio.get('/events');
      return response.data as List;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load events'));
    }
  }

  static Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required String date,
    required String time,
    required String location,
    required int capacity,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post('/events', data: {
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
        'capacity': capacity,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to create event'));
    }
  }

  // ─── Invitees ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchFilteredInviteesPaginated({
    required int eventId,
    required int page,
    String? searchQuery,
    bool? whatsappStatus,
    bool? invitationSent,
    String? attendanceStatus,
    bool? cardRedeemed,
    bool? seenStatus,
  }) async {
    final dio = await _dio();
    final queryParams = <String, String>{'page': page.toString()};

    if (searchQuery != null && searchQuery.isNotEmpty) queryParams['search'] = searchQuery;
    if (whatsappStatus != null) queryParams['whatsapp_status'] = whatsappStatus ? '1' : '0';
    if (invitationSent != null) queryParams['invitation_sent'] = invitationSent ? '1' : '0';
    if (attendanceStatus != null) queryParams['attendance_status'] = attendanceStatus;
    if (cardRedeemed != null) queryParams['is_redeemed'] = cardRedeemed ? '1' : '0';
    if (seenStatus != null) queryParams['is_seen'] = seenStatus ? '1' : '0';

    try {
      final response = await dio.get(
        '/events/$eventId/invitees',
        queryParameters: queryParams,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Error fetching invitees'));
    }
  }

  static Future<Map<String, dynamic>> fetchInviteesPaginated({
    required int eventId,
    required int page,
  }) async {
    return fetchFilteredInviteesPaginated(eventId: eventId, page: page);
  }

  static Future<List> searchInvitees(int eventId, String name) async {
    final dio = await _dio();
    try {
      final response = await dio.get(
        '/search/invitees/$eventId',
        queryParameters: {'name': name},
      );
      return response.data as List;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Error searching invitees'));
    }
  }

  static Future<Map<String, dynamic>> addInvitee({
    required int eventId,
    required String name,
    required String phoneNumber,
    required int numberOfInvitees,
    required bool isOnWhatsapp,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post('/events/$eventId/invitees', data: {
        'name': name,
        'phone_number': phoneNumber,
        'number_of_invitees': numberOfInvitees,
        'is_on_whatsapp': isOnWhatsapp,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to add invitee'));
    }
  }

  static Future<Map<String, dynamic>> updateInvitee({
    required int inviteeId,
    required String name,
    required String phoneNumber,
    required int numberOfInvitees,
    required bool isOnWhatsapp,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.put('/invitees/$inviteeId', data: {
        'name': name,
        'phone_number': phoneNumber,
        'number_of_invitees': numberOfInvitees,
        'is_on_whatsapp': isOnWhatsapp,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to update invitee'));
    }
  }

  static Future<void> deleteInvitee({required int inviteeId}) async {
    final dio = await _dio();
    try {
      await dio.delete('/invitees/$inviteeId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to delete invitee'));
    }
  }

  static Future<Map<String, dynamic>> importInviteesFromExcel({
    required int eventId,
    required File file,
  }) async {
    final dio = await _dio();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/import',
        data: formData,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to import invitees'));
    }
  }

  // ─── Invitations ────────────────────────────────────────────────────────────

  static Future<void> sendInvitation({required int inviteeId}) async {
    final dio = await _dio();
    try {
      await dio.post('/invitees/$inviteeId/send-invitation');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to send invitation'));
    }
  }

  static Future<void> bulkSendInvitations({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final dio = await _dio();
    try {
      await dio.post('/invitees/bulk-send-invitation', data: {
        'event_id': eventId,
        'invitee_ids': inviteeIds,
      });
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to send bulk invitations'));
    }
  }

  static Future<Map<String, dynamic>> markWhatsappInvitationSent({
    required int eventId,
    required int inviteeId,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/$inviteeId/mark-whatsapp-sent',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to mark WhatsApp invitation as sent'));
    }
  }

  // ─── Download Card ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendDownloadCardMessage({
    required int eventId,
    required int inviteeId,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/$inviteeId/send-download-card',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to send download card message'));
    }
  }

  static Future<Map<String, dynamic>> sendBulkDownloadCardMessages({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/bulk-send-download-card',
        data: {'invitee_ids': inviteeIds},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to send bulk download card messages'));
    }
  }

  // ─── Seen Status ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> markInviteeSeen({
    required int eventId,
    required int inviteeId,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/$inviteeId/mark-seen',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to mark invitee as seen'));
    }
  }

  static Future<Map<String, dynamic>> markBulkInviteesSeen({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post(
        '/events/$eventId/invitees/mark-seen-bulk',
        data: {'invitee_ids': inviteeIds},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to mark invitees as seen'));
    }
  }

  // ─── Schedules ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchSchedules(int eventId) async {
    final dio = await _dio();
    try {
      final response = await dio.get('/events/$eventId/schedules');
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load schedules'));
    }
  }

  static Future<Map<String, dynamic>> createSchedule(
    int eventId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _dio();
    try {
      final response = await dio.post('/events/$eventId/schedules', data: data);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to create schedule'));
    }
  }

  static Future<Map<String, dynamic>> updateSchedule(
    int eventId,
    int scheduleId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _dio();
    try {
      final response = await dio.put(
        '/events/$eventId/schedules/$scheduleId',
        data: data,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to update schedule'));
    }
  }

  static Future<void> deleteSchedule(int eventId, int scheduleId) async {
    final dio = await _dio();
    try {
      await dio.delete('/events/$eventId/schedules/$scheduleId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to delete schedule'));
    }
  }

  // ─── Collaborators ──────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getEventCollaborators(int eventId) async {
    final dio = await _dio();
    try {
      final response = await dio.get('/events/$eventId/collaborators');
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load collaborators'));
    }
  }

  static Future<Map<String, dynamic>> addCollaborator({
    required int eventId,
    required String email,
    required bool canDeleteInvitees,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.post('/events/$eventId/collaborators', data: {
        'email': email,
        'can_delete_invitees': canDeleteInvitees,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to add collaborator'));
    }
  }

  static Future<Map<String, dynamic>> updateCollaboratorPermissions({
    required int eventId,
    required int userId,
    required bool canDeleteInvitees,
  }) async {
    final dio = await _dio();
    try {
      final response = await dio.put(
        '/events/$eventId/collaborators/$userId',
        data: {'can_delete_invitees': canDeleteInvitees},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to update collaborator permissions'));
    }
  }

  static Future<void> removeCollaborator({
    required int eventId,
    required int userId,
  }) async {
    final dio = await _dio();
    try {
      await dio.delete('/events/$eventId/collaborators/$userId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to remove collaborator'));
    }
  }

  static Future<List<Map<String, dynamic>>> getCollaborativeEvents() async {
    final dio = await _dio();
    try {
      final response = await dio.get('/collaborative-events');
      return List<Map<String, dynamic>>.from(response.data as List);
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load collaborative events'));
    }
  }

  static Future<Map<String, dynamic>> getCollaborativeEventDetails(int eventId) async {
    final dio = await _dio();
    try {
      final response = await dio.get('/collaborative-events/$eventId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load collaborative event details'));
    }
  }

  static Future<Map<String, dynamic>> checkCollaboratorStatus(int eventId) async {
    final dio = await _dio();
    try {
      final response = await dio.get('/events/$eventId/collaborator-status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to check collaborator status'));
    }
  }

  // ─── SMS Templates ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchTemplates(int eventId) async {
    final dio = await _dio();
    try {
      final response = await dio.get('/events/$eventId/sms-template');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to load templates'));
    }
  }

  static Future<Map<String, dynamic>> saveTemplate({
    required int eventId,
    required String type,
    required String content,
  }) async {
    final dio = await _dio();
    final body = <String, dynamic>{'message': content};
    if (type == 'whatsapp') body['whatsapp_message'] = content;
    if (type == 'download_card') body['download_card_message'] = content;

    try {
      final response = await dio.post('/events/$eventId/sms-template', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to save template'));
    }
  }

  static Future<Map<String, dynamic>> updateTemplate({
    required int templateId,
    required String content,
    required String type,
  }) async {
    final dio = await _dio();
    final body = <String, dynamic>{'message': type == 'sms' ? content : ''};
    if (type == 'whatsapp') body['whatsapp_message'] = content;
    if (type == 'download_card') body['download_card_message'] = content;

    try {
      final response = await dio.put('/templates/$templateId', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to update template'));
    }
  }

  static Future<void> deleteTemplate(int templateId) async {
    final dio = await _dio();
    try {
      await dio.delete('/templates/$templateId');
    } on DioException catch (e) {
      throw Exception(_errorMessage(e, 'Failed to delete template'));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  static String _errorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'] as String;
    }
    return fallback;
  }
}
