// api_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl = 'https://events.ajiriwa.net/api';
  static final _storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  static Future<List> fetchEvents() async {
    final token = await _getToken();
    final url = Uri.parse(''
        '${baseUrl}/events');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load events');
    }
  }

  static Future<List> searchInvitees(int eventId, String name) async {
    final response = await http.get(Uri.parse('$baseUrl/search/invitees/$eventId?name=$name'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error searching invitees');
    }
  }

  static Future<Map<String, dynamic>> fetchInviteesPaginated({
    required int eventId,
    required int page,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees?page=$page');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error fetching invitees: ${response.body}');
    }
  }

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
    final token = await _getToken();

    // Build query parameters
    final queryParams = <String, String>{
      'page': page.toString(),
    };

    // Add filter parameters if they are provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }

    if (whatsappStatus != null) {
      queryParams['whatsapp_status'] = whatsappStatus ? '1' : '0';
    }

    if (invitationSent != null) {
      queryParams['invitation_sent'] = invitationSent ? '1' : '0';
    }

    if (attendanceStatus != null) {
      queryParams['attendance_status'] = attendanceStatus;
    }

    if (cardRedeemed != null) {
      queryParams['is_redeemed'] = cardRedeemed ? '1' : '0';
    }

    if (seenStatus != null) {
      queryParams['is_seen'] = seenStatus ? '1' : '0';
    }

    final url = Uri.parse('$baseUrl/events/$eventId/invitees').replace(queryParameters: queryParams);

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error fetching filtered invitees: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> addInvitee({
    required int eventId,
    required String name,
    required String phoneNumber,
    required int numberOfInvitees,
    required bool isOnWhatsapp,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'phone_number': phoneNumber,
        'number_of_invitees': numberOfInvitees,
        'is_on_whatsapp': isOnWhatsapp,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to add invitee');
    }
  }


  static Future<void> sendInvitation({required int inviteeId}) async {
    final token = await _getToken(); // Replace with your method of retrieving auth token

    final url = Uri.parse('https://events.ajiriwa.net/api/invitees/$inviteeId/send-invitation');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send invitation: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> markWhatsappInvitationSent({required int eventId, required int inviteeId}) async {
    final token = await _getToken();

    final url = Uri.parse('$baseUrl/events/$eventId/invitees/$inviteeId/mark-whatsapp-sent');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to mark WhatsApp invitation as sent: ${response.body}');
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
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
        'capacity': capacity,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      print(json.encode({
        'title': title,
        'description': description,
        'date': date,
        'time': time,
        'location': location,
        'capacity': capacity,
      }));
      throw Exception('Failed to create event: ${response.body}');
    }
  }

  static Future<void> deleteInvitee({required int inviteeId}) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/invitees/$inviteeId');

    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete invitee');
    }
  }


  static Future<Map<String, dynamic>> updateInvitee({
    required int inviteeId,
    required String name,
    required String phoneNumber,
    required int numberOfInvitees,
    required bool isOnWhatsapp,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/invitees/$inviteeId');

    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'name': name,
        'phone_number': phoneNumber,
        'number_of_invitees': numberOfInvitees,
        'is_on_whatsapp': isOnWhatsapp,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to update invitee');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSchedules(int eventId) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/events/$eventId/schedules'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load schedules');
    }
  }

  static Future<Map<String, dynamic>> createSchedule(int eventId, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/schedules'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create schedule');
    }
  }

  static Future<Map<String, dynamic>> updateSchedule(int eventId, int scheduleId, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/events/$eventId/schedules/$scheduleId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update schedule');
    }
  }

  static Future<void> deleteSchedule(int eventId, int scheduleId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/events/$eventId/schedules/$scheduleId'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete schedule');
    }
  }

  // Collaborator API methods

  // Get all collaborators for an event
  static Future<List<Map<String, dynamic>>> getEventCollaborators(int eventId) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/collaborators');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load collaborators');
    }
  }

  // Add a collaborator to an event
  static Future<Map<String, dynamic>> addCollaborator({
    required int eventId,
    required String email,
    required bool canDeleteInvitees,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/collaborators');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'email': email,
        'can_delete_invitees': canDeleteInvitees,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to add collaborator');
    }
  }

  // Update collaborator permissions
  static Future<Map<String, dynamic>> updateCollaboratorPermissions({
    required int eventId,
    required int userId,
    required bool canDeleteInvitees,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/collaborators/$userId');

    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'can_delete_invitees': canDeleteInvitees,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to update collaborator permissions');
    }
  }

  // Remove a collaborator from an event
  static Future<void> removeCollaborator({
    required int eventId,
    required int userId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/collaborators/$userId');

    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to remove collaborator');
    }
  }

  // Get all events where the user is a collaborator
  static Future<List<Map<String, dynamic>>> getCollaborativeEvents() async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/collaborative-events');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load collaborative events');
    }
  }

  // Get details of a specific collaborative event
  static Future<Map<String, dynamic>> getCollaborativeEventDetails(int eventId) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/collaborative-events/$eventId');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load collaborative event details');
    }
  }

  // Check if user is a collaborator for an event
  static Future<Map<String, dynamic>> checkCollaboratorStatus(int eventId) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/collaborator-status');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to check collaborator status');
    }
  }

  // Bulk send invitations to multiple invitees
  static Future<void> bulkSendInvitations({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/invitees/bulk-send-invitation');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'event_id': eventId,
        'invitee_ids': inviteeIds,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send bulk invitations: ${response.body}');
    }
  }

  // Import invitees from Excel file
  static Future<Map<String, dynamic>> importInviteesFromExcel({
    required int eventId,
    required File file,
  }) async {
    final token = await _getToken();
    final url = '$baseUrl/events/$eventId/invitees/import';

    // Create FormData
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    // Configure Dio
    final dio = Dio();
    dio.options.headers = {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final response = await dio.post(
        url,
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to import invitees');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Failed to import invitees');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }
  // Fetch message templates for an event
  static Future<Map<String, dynamic>> fetchTemplates(int eventId) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/sms-template');

    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load templates');
    }
  }

  // Save a message template
  static Future<Map<String, dynamic>> saveTemplate({
    required int eventId,
    required String type, // 'whatsapp', 'sms', or 'download_card'
    required String content,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/sms-template');

    // Create request body based on template type
    final Map<String, dynamic> requestBody = {
      'type': type,
      // Always include 'message' field to avoid validation errors
      'message': content,
    };

    // Save content in the appropriate column based on type
    if (type == 'whatsapp') {
      requestBody['whatsapp_message'] = content;
    } else if (type == 'download_card') {
      requestBody['download_card_message'] = content;
    }

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to save template');
    }
  }

  // Update an existing message template
  static Future<Map<String, dynamic>> updateTemplate({
    required int templateId,
    required String content,
    required String type, // 'whatsapp', 'sms', or 'download_card'
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/templates/$templateId');

    // Create request body based on template type
    final Map<String, dynamic> requestBody = {
      'type': type,
      // Always include 'message' field to avoid validation errors
      'message': type == 'sms' ? content : '',
    };

    // Save content in the appropriate column based on type
    if (type == 'whatsapp') {
      requestBody['whatsapp_message'] = content;
    } else if (type == 'download_card') {
      requestBody['download_card_message'] = content;
    }

    final response = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to update template');
    }
  }

  // Delete a message template
  static Future<void> deleteTemplate(int templateId) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/templates/$templateId');

    final response = await http.delete(
      url,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete template');
    }
  }

  // Send download card message to a single invitee
  static Future<Map<String, dynamic>> sendDownloadCardMessage({
    required int eventId,
    required int inviteeId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees/$inviteeId/send-download-card');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send download card message: ${response.body}');
    }
  }

  // Send download card messages in bulk to multiple invitees
  static Future<Map<String, dynamic>> sendBulkDownloadCardMessages({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees/bulk-send-download-card');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'invitee_ids': inviteeIds,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to send bulk download card messages: ${response.body}');
    }
  }

  // Mark an invitee as seen
  static Future<Map<String, dynamic>> markInviteeSeen({
    required int eventId,
    required int inviteeId,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees/$inviteeId/mark-seen');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to mark invitee as seen: ${response.body}');
    }
  }

  // Mark multiple invitees as seen in bulk
  static Future<Map<String, dynamic>> markBulkInviteesSeen({
    required int eventId,
    required List<int> inviteeIds,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/events/$eventId/invitees/mark-seen-bulk');

    final response = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'invitee_ids': inviteeIds,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to mark invitees as seen in bulk: ${response.body}');
    }
  }
}
