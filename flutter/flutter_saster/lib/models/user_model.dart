class UserModel {
  final int id;
  final String name;
  final String username;
  final String role;
  final int? barangayId;
  final String? barangayName;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.barangayId,
    this.barangayName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      barangayId: json['barangay_id'] == null
          ? null
          : int.tryParse(json['barangay_id'].toString()),
      barangayName: json['barangay_name']?.toString(),
    );
  }
}
