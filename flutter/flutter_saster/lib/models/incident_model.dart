class IncidentModel {
  final int id;
  final int userId;
  final int barangayId;
  final String barangayName;
  final String disasterType;
  final String evacuationNeeded;
  final int? evacuationCenterId;
  final String? evacuationCenterName;
  final String description;
  final String? latitude;
  final String? longitude;
  final int affectedPeople;
  final int injured;
  final int dead;
  final int missing;
  final String status;
  final String roadStatus;
  final String roadBlockageCauses;
  final String roadLocation;
  final int referredToPho;
  final int attachmentCount;
  final String? incidentDatetime;
  final String createdAt;

  IncidentModel({
    required this.id,
    required this.userId,
    required this.barangayId,
    required this.barangayName,
    required this.disasterType,
    required this.evacuationNeeded,
    this.evacuationCenterId,
    this.evacuationCenterName,
    required this.description,
    this.latitude,
    this.longitude,
    required this.affectedPeople,
    required this.injured,
    required this.dead,
    required this.missing,
    required this.status,
    this.roadStatus = 'Passable',
    this.roadBlockageCauses = '',
    this.roadLocation = '',
    required this.referredToPho,
    required this.attachmentCount,
    this.incidentDatetime,
    required this.createdAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      barangayId: int.tryParse(json['barangay_id'].toString()) ?? 0,
      barangayName: json['barangay_name']?.toString() ?? '',
      disasterType: json['disaster_type']?.toString() ?? '',
      evacuationNeeded: json['evacuation_needed']?.toString() ?? 'No',
      evacuationCenterId: json['evacuation_center_id'] == null
          ? null
          : int.tryParse(json['evacuation_center_id'].toString()),
      evacuationCenterName: json['evacuation_center_name']?.toString(),
      description: json['description']?.toString() ?? '',
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      affectedPeople: int.tryParse(json['affected_people'].toString()) ?? 0,
      injured: int.tryParse(json['injured'].toString()) ?? 0,
      dead: int.tryParse(json['dead'].toString()) ?? 0,
      missing: int.tryParse(json['missing'].toString()) ?? 0,
      status: json['status']?.toString() ?? '',
      roadStatus: json['road_status']?.toString() ?? 'Passable',
      roadBlockageCauses: json['road_blockage_causes']?.toString() ?? '',
      roadLocation: json['road_location']?.toString() ?? '',
      referredToPho: int.tryParse(json['referred_to_pho'].toString()) ?? 0,
      attachmentCount: int.tryParse(json['attachment_count']?.toString() ?? '0') ?? 0,
      incidentDatetime: json['incident_datetime']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
