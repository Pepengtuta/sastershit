class HotlineModel {
  final int id;
  final String hotlineScope;
  final int? barangayId;
  final String? barangayName;
  final String officeName;
  final String? municipality;
  final String? category;
  final String? telephoneNumbers;
  final String? cellphoneNumbers;
  final String? hotlineNumber;
  final String status;

  HotlineModel({
    required this.id,
    required this.hotlineScope,
    this.barangayId,
    this.barangayName,
    required this.officeName,
    this.municipality,
    this.category,
    this.telephoneNumbers,
    this.cellphoneNumbers,
    this.hotlineNumber,
    required this.status,
  });

  factory HotlineModel.fromJson(Map<String, dynamic> json) {
    return HotlineModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      hotlineScope: json['hotline_scope']?.toString() ?? '',
      barangayId: json['barangay_id'] == null
          ? null
          : int.tryParse(json['barangay_id'].toString()),
      barangayName: json['barangay_name']?.toString(),
      officeName: json['office_name']?.toString() ?? '',
      municipality: json['municipality']?.toString(),
      category: json['category']?.toString(),
      telephoneNumbers: json['telephone_numbers']?.toString(),
      cellphoneNumbers: json['cellphone_numbers']?.toString(),
      hotlineNumber: json['hotline_number']?.toString(),
      status: json['status']?.toString() ?? '',
    );
  }
}
