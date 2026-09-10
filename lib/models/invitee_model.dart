class InviteeModel {
  final int id;
  final int eventId;
  final String name;
  final String phoneNumber;
  final int numberOfInvitees;
  final String slug;
  final bool isOnWhatsapp;
  final bool isRedeemed;
  final bool isSeen;
  final String? attendanceStatus;
  final String? redemptionStatus;
  final int? totalRedeemedGuests;
  final int? remainingInvitees;
  final List<Map<String, dynamic>> invitations;

  const InviteeModel({
    required this.id,
    required this.eventId,
    required this.name,
    required this.phoneNumber,
    required this.numberOfInvitees,
    required this.slug,
    required this.isOnWhatsapp,
    required this.isRedeemed,
    required this.isSeen,
    this.attendanceStatus,
    this.redemptionStatus,
    this.totalRedeemedGuests,
    this.remainingInvitees,
    this.invitations = const [],
  });

  factory InviteeModel.fromJson(Map<String, dynamic> json) {
    return InviteeModel(
      id: json['id'] as int,
      eventId: json['event_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      numberOfInvitees: json['number_of_invitees'] as int? ?? 1,
      slug: json['slug'] as String? ?? '',
      isOnWhatsapp: json['is_on_whatsapp'] == true || json['is_on_whatsapp'] == 1,
      isRedeemed: json['is_redeemed'] == true || json['is_redeemed'] == 1,
      isSeen: json['is_seen'] == true || json['is_seen'] == 1,
      attendanceStatus: json['attendance_status'] as String?,
      redemptionStatus: json['redemption_status'] as String?,
      totalRedeemedGuests: json['total_redeemed_guests'] as int?,
      remainingInvitees: json['remaining_invitees'] as int?,
      invitations: (json['invitations'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  bool get hasInvitation => invitations.isNotEmpty;

  InviteeModel copyWith({
    bool? isRedeemed,
    bool? isSeen,
    String? attendanceStatus,
    String? redemptionStatus,
    int? totalRedeemedGuests,
    int? remainingInvitees,
    List<Map<String, dynamic>>? invitations,
  }) {
    return InviteeModel(
      id: id,
      eventId: eventId,
      name: name,
      phoneNumber: phoneNumber,
      numberOfInvitees: numberOfInvitees,
      slug: slug,
      isOnWhatsapp: isOnWhatsapp,
      isRedeemed: isRedeemed ?? this.isRedeemed,
      isSeen: isSeen ?? this.isSeen,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      redemptionStatus: redemptionStatus ?? this.redemptionStatus,
      totalRedeemedGuests: totalRedeemedGuests ?? this.totalRedeemedGuests,
      remainingInvitees: remainingInvitees ?? this.remainingInvitees,
      invitations: invitations ?? this.invitations,
    );
  }
}
