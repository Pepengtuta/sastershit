class ApiResponseModel {
  final bool success;
  final String message;
  final dynamic data;

  ApiResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponseModel.fromJson(Map<String, dynamic> json) {
    return ApiResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'],
    );
  }
}
