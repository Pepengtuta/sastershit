class AlertModel {
  final int id;
  final String title;
  final String alertType;
  final String severity;
  final String message;
  final String? instructions;
  final String status;
  final String? startDatetime;
  final String? endDatetime;
  final String createdAt;

  AlertModel({
    required this.id,
    required this.title,
    required this.alertType,
    required this.severity,
    required this.message,
    this.instructions,
    required this.status,
    this.startDatetime,
    this.endDatetime,
    required this.createdAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      alertType: json['alert_type']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      status: json['status']?.toString() ?? '',
      startDatetime: json['start_datetime']?.toString(),
      endDatetime: json['end_datetime']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
