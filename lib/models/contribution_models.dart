// Models for the contribution round (mchango).
//
// A contributor *is* their pledge: the kamati adds them, they promise an
// amount, and payments recorded against them draw that promise down.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// One payment booked against a promise.
class ContributionPayment {
  final int id;
  final double amount;
  final String currency;
  final String method;
  final String? reference;
  final DateTime? paidAt;
  final String? notes;

  ContributionPayment({
    required this.id,
    required this.amount,
    required this.currency,
    required this.method,
    this.reference,
    this.paidAt,
    this.notes,
  });

  factory ContributionPayment.fromJson(Map<String, dynamic> json) {
    return ContributionPayment(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      currency: json['currency']?.toString() ?? 'TZS',
      method: json['method']?.toString() ?? 'cash',
      reference: json['reference']?.toString(),
      paidAt: _toDate(json['paid_at']),
      notes: json['notes']?.toString(),
    );
  }
}

/// A person on the contribution list.
class Contributor {
  final int id;
  final String slug;
  final String name;
  final String phoneNumber;
  final String? group;
  final double? amount;
  final double paidAmount;
  final double balance;
  final int progress;
  final String currency;
  final String status;
  final bool isOnWhatsapp;
  final DateTime? cardSentAt;
  final DateTime? lastReminderAt;
  final int? promotedInviteeId;
  final String? notes;
  final List<ContributionPayment> payments;

  Contributor({
    required this.id,
    required this.slug,
    required this.name,
    required this.phoneNumber,
    required this.paidAmount,
    required this.balance,
    required this.progress,
    required this.currency,
    required this.status,
    required this.isOnWhatsapp,
    required this.payments,
    this.group,
    this.amount,
    this.cardSentAt,
    this.lastReminderAt,
    this.promotedInviteeId,
    this.notes,
  });

  factory Contributor.fromJson(Map<String, dynamic> json) {
    final raw = json['contributions'];

    return Contributor(
      id: _toInt(json['id']),
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      group: json['group']?.toString(),
      amount: json['amount'] == null ? null : _toDouble(json['amount']),
      paidAmount: _toDouble(json['paid_amount']),
      balance: _toDouble(json['balance']),
      progress: _toInt(json['progress']),
      currency: json['currency']?.toString() ?? 'TZS',
      status: json['status']?.toString() ?? 'pending',
      isOnWhatsapp: json['is_on_whatsapp'] == true || json['is_on_whatsapp'] == 1,
      cardSentAt: _toDate(json['card_sent_at']),
      lastReminderAt: _toDate(json['last_reminder_at']),
      promotedInviteeId: json['promoted_invitee_id'] == null ? null : _toInt(json['promoted_invitee_id']),
      notes: json['notes']?.toString(),
      payments: raw is List
          ? raw.map((e) => ContributionPayment.fromJson(Map<String, dynamic>.from(e))).toList()
          : <ContributionPayment>[],
    );
  }

  /// Same contributor with the card marked as just sent, so the detail screen
  /// can reflect a send without another round trip.
  Contributor copyWithCardSentNow() => Contributor(
        id: id,
        slug: slug,
        name: name,
        phoneNumber: phoneNumber,
        group: group,
        amount: amount,
        paidAmount: paidAmount,
        balance: balance,
        progress: progress,
        currency: currency,
        status: status,
        isOnWhatsapp: isOnWhatsapp,
        cardSentAt: DateTime.now(),
        lastReminderAt: lastReminderAt,
        promotedInviteeId: promotedInviteeId,
        notes: notes,
        payments: payments,
      );

  bool get hasPromised => (amount ?? 0) > 0;
  bool get isSettled => hasPromised && balance <= 0;
  bool get cardSent => cardSentAt != null;

  /// Wording the kamati uses, not the database value.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Not promised';
      case 'pledged':
        return 'Promised';
      case 'partial':
        return 'Part paid';
      case 'paid':
        return 'Fully paid';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }
}

/// Headline numbers for the round.
class ContributionStats {
  final int contributors;
  final int cardsSent;
  final double target;
  final double promised;
  final double collected;
  final double outstanding;
  final int? targetProgress;
  final int promiseProgress;
  final String currency;
  final Map<String, int> counts;

  ContributionStats({
    required this.contributors,
    required this.cardsSent,
    required this.target,
    required this.promised,
    required this.collected,
    required this.outstanding,
    required this.promiseProgress,
    required this.currency,
    required this.counts,
    this.targetProgress,
  });

  factory ContributionStats.fromJson(Map<String, dynamic> json) {
    final counts = <String, int>{};
    final raw = json['counts'];

    if (raw is Map) {
      raw.forEach((k, v) => counts[k.toString()] = _toInt(v));
    }

    return ContributionStats(
      contributors: _toInt(json['contributors']),
      cardsSent: _toInt(json['cards_sent']),
      target: _toDouble(json['target']),
      promised: _toDouble(json['promised']),
      collected: _toDouble(json['collected']),
      outstanding: _toDouble(json['outstanding']),
      targetProgress: json['target_progress'] == null ? null : _toInt(json['target_progress']),
      promiseProgress: _toInt(json['promise_progress']),
      currency: json['currency']?.toString() ?? 'TZS',
      counts: counts,
    );
  }

  static ContributionStats empty() => ContributionStats(
        contributors: 0,
        cardsSent: 0,
        target: 0,
        promised: 0,
        collected: 0,
        outstanding: 0,
        promiseProgress: 0,
        currency: 'TZS',
        counts: const {},
      );
}

/// One collection number printed on the card and the contribute page.
class PaymentMethod {
  String label;
  String number;
  String name;

  PaymentMethod({this.label = '', this.number = '', this.name = ''});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        label: json['label']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'label': label, 'number': number, 'name': name};
}

/// A kamati contact (mwenyekiti, katibu, mweka hazina…).
class CommitteeContact {
  String role;
  String name;
  String phone;

  CommitteeContact({this.role = '', this.name = '', this.phone = ''});

  factory CommitteeContact.fromJson(Map<String, dynamic> json) => CommitteeContact(
        role: json['role']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'role': role, 'name': name, 'phone': phone};
}

/// Everything the settings screen edits, plus the message bodies.
class ContributionSettings {
  String mode;
  String status;
  double? target;
  String? deadline;
  String currency;
  double? minAmount;
  String appealText;
  String kikaoDate;
  String kikaoTime;
  String kikaoVenue;
  List<PaymentMethod> paymentMethods;
  List<CommitteeContact> committeeContacts;

  String smsMessage;
  String whatsappMessage;
  String reminderMessage;
  String whatsappTemplateName;
  String whatsappBodyParamName;
  bool whatsappHasBodyParam;

  final bool hasCardDesign;
  final String generalLink;
  final Map<String, String> paymentMethodOptions;

  ContributionSettings({
    required this.mode,
    required this.status,
    required this.currency,
    required this.appealText,
    required this.kikaoDate,
    required this.kikaoTime,
    required this.kikaoVenue,
    required this.paymentMethods,
    required this.committeeContacts,
    required this.smsMessage,
    required this.whatsappMessage,
    required this.reminderMessage,
    required this.whatsappTemplateName,
    required this.whatsappBodyParamName,
    required this.whatsappHasBodyParam,
    required this.hasCardDesign,
    required this.generalLink,
    required this.paymentMethodOptions,
    this.target,
    this.deadline,
    this.minAmount,
  });

  factory ContributionSettings.fromJson(Map<String, dynamic> json) {
    final s = Map<String, dynamic>.from(json['settings'] ?? {});
    final m = Map<String, dynamic>.from(json['messages'] ?? {});

    List<T> listOf<T>(dynamic raw, T Function(Map<String, dynamic>) build) {
      if (raw is! List) return <T>[];
      return raw.map((e) => build(Map<String, dynamic>.from(e))).toList();
    }

    final options = <String, String>{};
    final rawOptions = json['payment_method_options'];
    if (rawOptions is Map) {
      rawOptions.forEach((k, v) => options[k.toString()] = v.toString());
    }

    return ContributionSettings(
      mode: json['contribution_mode']?.toString() ?? 'direct',
      status: json['contribution_status']?.toString() ?? 'draft',
      target: json['contribution_target'] == null ? null : _toDouble(json['contribution_target']),
      deadline: json['contribution_deadline']?.toString(),
      currency: s['currency']?.toString() ?? 'TZS',
      minAmount: s['min_amount'] == null ? null : _toDouble(s['min_amount']),
      appealText: s['appeal_text']?.toString() ?? '',
      kikaoDate: s['kikao_date']?.toString() ?? '',
      kikaoTime: s['kikao_time']?.toString() ?? '',
      kikaoVenue: s['kikao_venue']?.toString() ?? '',
      paymentMethods: listOf(s['payment_methods'], PaymentMethod.fromJson),
      committeeContacts: listOf(s['committee_contacts'], CommitteeContact.fromJson),
      smsMessage: m['message']?.toString() ?? '',
      whatsappMessage: m['whatsapp_message']?.toString() ?? '',
      reminderMessage: m['reminder_message']?.toString() ?? '',
      whatsappTemplateName: m['whatsapp_template_name']?.toString() ?? '',
      whatsappBodyParamName: m['whatsapp_body_param_name']?.toString() ?? '',
      whatsappHasBodyParam: m['whatsapp_has_body_param'] != false,
      hasCardDesign: json['has_card_design'] == true,
      generalLink: json['general_link']?.toString() ?? '',
      paymentMethodOptions: options.isEmpty ? const {'mpesa': 'M-Pesa', 'cash': 'Cash'} : options,
    );
  }

  bool get isKikao => mode == 'kikao';
}

/// One line the server read out of the typed list, with its verdict.
class ParsedLine {
  final int line;
  final String? name;
  final String? phoneNumber;
  final String? group;
  final double? amount;
  final String importStatus;
  final String? reason;

  ParsedLine({
    required this.line,
    required this.importStatus,
    this.name,
    this.phoneNumber,
    this.group,
    this.amount,
    this.reason,
  });

  factory ParsedLine.fromJson(Map<String, dynamic> json) => ParsedLine(
        line: _toInt(json['line']),
        name: json['name']?.toString(),
        phoneNumber: json['phone_number']?.toString(),
        group: json['group']?.toString(),
        amount: json['amount'] == null ? null : _toDouble(json['amount']),
        importStatus: json['import_status']?.toString() ?? 'unusable',
        reason: json['reason']?.toString(),
      );

  bool get isReady => importStatus == 'new';
}
