import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/api_config.dart';
import 'api_service.dart';

class IncidentService {
  static Future<Map<String, dynamic>> createIncident({
    required int userId,
    required int barangayId,
    required String disasterType,
    required String evacuationNeeded,
    int? evacuationCenterId,
    int evacHouseholds = 0,
    int evacAdults = 0,
    int evacChildren = 0,
    int evacMembers = 0,
    required String incidentDatetime,
    required String description,
    double? latitude,
    double? longitude,
    String exactLocation = '',
    String assistanceNeeded = '',
    String roadStatus = 'Passable',
    String roadBlockageCauses = '',
    String roadLocation = '',
    required int affectedPeople,
    required int injured,
    required int dead,
    required int missing,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/create_incident.php',
      body: {
        'user_id': userId,
        'barangay_id': barangayId,
        'disaster_type': disasterType,
        'evacuation_needed': evacuationNeeded,
        'evacuation_center_id': evacuationCenterId,
        'evac_households': evacHouseholds,
        'evac_adults': evacAdults,
        'evac_children': evacChildren,
        'evac_members': evacMembers,
        'incident_datetime': incidentDatetime,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'exact_location': exactLocation,
        'assistance_needed': assistanceNeeded,
        'road_status': roadStatus,
        'road_blockage_causes': roadBlockageCauses,
        'road_location': roadLocation,
        'affected_people': affectedPeople,
        'injured': injured,
        'dead': dead,
        'missing': missing,
      },
    );
  }

  static Future<Map<String, dynamic>> updateIncident({
    required int reportId,
    required int userId,
    required int barangayId,
    required String disasterType,
    required String evacuationNeeded,
    int? evacuationCenterId,
    int evacHouseholds = 0,
    int evacAdults = 0,
    int evacChildren = 0,
    int evacMembers = 0,
    required String incidentDatetime,
    required String description,
    double? latitude,
    double? longitude,
    String exactLocation = '',
    String assistanceNeeded = '',
    String roadStatus = 'Passable',
    String roadBlockageCauses = '',
    String roadLocation = '',
    required int affectedPeople,
    required int injured,
    required int dead,
    required int missing,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_incident.php',
      body: {
        'report_id': reportId,
        'user_id': userId,
        'barangay_id': barangayId,
        'disaster_type': disasterType,
        'evacuation_needed': evacuationNeeded,
        'evacuation_center_id': evacuationCenterId,
        'evac_households': evacHouseholds,
        'evac_adults': evacAdults,
        'evac_children': evacChildren,
        'evac_members': evacMembers,
        'incident_datetime': incidentDatetime,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'exact_location': exactLocation,
        'assistance_needed': assistanceNeeded,
        'road_status': roadStatus,
        'road_blockage_causes': roadBlockageCauses,
        'road_location': roadLocation,
        'affected_people': affectedPeople,
        'injured': injured,
        'dead': dead,
        'missing': missing,
      },
    );
  }

  static Future<Map<String, dynamic>> uploadEvidence({
    required int incidentId,
    required int uploadedBy,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) {
      return {'success': true, 'message': 'No evidence selected.', 'data': []};
    }

    try {
      const allowedImageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
      const allowedVideoExtensions = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
      // Match config/app_config.php — change both together
      const maxPhotoBytes = 15 * 1024 * 1024;
      const maxVideoBytes = 50 * 1024 * 1024;
      const maxPhotos = 5;
      const maxVideos = 2;

      int photoCount = 0;
      int videoCount = 0;

      for (final file in files) {
        final name = file.name;
        final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        final length = await file.length();
        final isImage = allowedImageExtensions.contains(ext);
        final isVideo = allowedVideoExtensions.contains(ext);

        if (!isImage && !isVideo) {
          return {
            'success': false,
            'message': 'File "$name" is not an allowed photo or video type.',
            'data': null,
          };
        }

        if (isImage) {
          photoCount++;
          if (photoCount > maxPhotos) {
            return {
              'success': false,
              'message': 'Maximum $maxPhotos photos per report.',
              'data': null,
            };
          }
          if (length > maxPhotoBytes) {
            return {
              'success': false,
              'message': 'File "$name" is larger than the 15 MB photo limit.',
              'data': null,
            };
          }
        }

        if (isVideo) {
          videoCount++;
          if (videoCount > maxVideos) {
            return {
              'success': false,
              'message': 'Maximum $maxVideos videos per report.',
              'data': null,
            };
          }
          if (length > maxVideoBytes) {
            return {
              'success': false,
              'message': 'File "$name" is larger than the 50 MB video limit.',
              'data': null,
            };
          }
        }
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/upload_incident_evidence.php'),
      );

      // Required when baseUrl points at a free ngrok tunnel, or ngrok returns
      // an HTML warning page instead of the upload response.
      request.headers.addAll(ApiConfig.ngrokHeaders);

      request.fields['incident_report_id'] = incidentId.toString();
      request.fields['uploaded_by'] = uploadedBy.toString();

      for (final file in files) {
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'evidence_files[]',
            bytes,
            filename: file.name,
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Upload server error: ${response.statusCode}',
          'data': null,
        };
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (error) {
      return {
        'success': false,
        'message': 'Upload failed: $error',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getReports({
    required String role,
    int? barangayId,
    int? userId,
    String? municipality,
    int? month,
    int? year,
    String? disasterType,
    bool governorScope = false,
    bool mayorScope = false,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_reports.php',
      body: {
        'role': role,
        'barangay_id': barangayId,
        'user_id': userId,
        if (municipality != null && municipality.isNotEmpty)
          'municipality': municipality,
        'month': ?month,
        'year': ?year,
        if (disasterType != null && disasterType.isNotEmpty)
          'disaster_type': disasterType,
        if (governorScope) 'governor_scope': 1,
        if (mayorScope) 'mayor_scope': 1,
      },
    );
  }

  static Future<Map<String, dynamic>> updateStatus({
    required int reportId,
    required int userId,
    required String status,
    String remarks = '',
    bool referredToPho = false,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_status.php',
      body: {
        'report_id': reportId,
        'user_id': userId,
        'status': status,
        'remarks': remarks,
        'referred_to_pho': referredToPho ? 1 : 0,
      },
    );
  }

  static Future<Map<String, dynamic>> getReportLogs({
    required int reportId,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_report_logs.php',
      body: {
        'report_id': reportId,
      },
    );
  }

  static Future<Map<String, dynamic>> getReportAttachments({
    required int reportId,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_report_attachments.php',
      body: {
        'report_id': reportId,
      },
    );
  }


}
