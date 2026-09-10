class EventModel {
  final int id;
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String? mapLocation;
  final int? capacity;
  final String? code;
  final int userId;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    this.mapLocation,
    this.capacity,
    this.code,
    required this.userId,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: json['location'] as String? ?? '',
      mapLocation: json['map_location'] as String?,
      capacity: json['capacity'] as int?,
      code: json['code'] as String?,
      userId: json['user_id'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'location': location,
      if (mapLocation != null) 'map_location': mapLocation,
      if (capacity != null) 'capacity': capacity,
      if (code != null) 'code': code,
      'user_id': userId,
    };
  }
}
