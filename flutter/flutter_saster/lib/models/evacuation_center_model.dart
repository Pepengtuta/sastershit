class EvacuationCenterModel {
  final int id;
  final String barangay;
  final String centerName;
  final String? centerType;
  final int capacity;
  final int currentEvacuees;
  final String status;
  final String? contactPerson;
  final String? contactNumber;
  final String? latitude;
  final String? longitude;

  EvacuationCenterModel({
    required this.id,
    required this.barangay,
    required this.centerName,
    this.centerType,
    required this.capacity,
    required this.currentEvacuees,
    required this.status,
    this.contactPerson,
    this.contactNumber,
    this.latitude,
    this.longitude,
  });

  factory EvacuationCenterModel.fromJson(Map<String, dynamic> json) {
    return EvacuationCenterModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      barangay: json['barangay']?.toString() ?? '',
      centerName: json['center_name']?.toString() ?? '',
      centerType: json['center_type']?.toString(),
      capacity: int.tryParse(json['capacity'].toString()) ?? 0,
      currentEvacuees: int.tryParse(json['current_evacuees'].toString()) ?? 0,
      status: json['status']?.toString() ?? '',
      contactPerson: json['contact_person']?.toString(),
      contactNumber: json['contact_number']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
    );
  }
}
