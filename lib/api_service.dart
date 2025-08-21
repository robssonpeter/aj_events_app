// api_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

    final url = Uri.parse('https://events.ajiriwa.net/api/$inviteeId/send-invitation');

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

}
