class SmsTemplateModel {
  final int id;
  final int eventId;
  final String message;
  final String? whatsappMessage;
  final String? downloadCardMessage;

  const SmsTemplateModel({
    required this.id,
    required this.eventId,
    required this.message,
    this.whatsappMessage,
    this.downloadCardMessage,
  });

  factory SmsTemplateModel.fromJson(Map<String, dynamic> json) {
    return SmsTemplateModel(
      id: json['id'] as int,
      eventId: json['event_id'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      whatsappMessage: json['whatsapp_message'] as String?,
      downloadCardMessage: json['download_card_message'] as String?,
    );
  }
}
