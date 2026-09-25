<?php
session_start();
require_once __DIR__ . "/../includes/csrf.php";
csrf_verify();
include "../../config/db_connection.php";
require_once __DIR__ . "/../includes/functions.php";

if (!isset($_SESSION['user_id']) || $_SESSION['role'] != 'barangay') {
    header("Location: ../../public/login.php");
    exit;
}

$V_user_id = (int)$_SESSION['user_id'];
$V_barangay_id = (int)$_SESSION['barangay_id'];
$V_barangay_name = $_SESSION['barangay_name'] ?? '';
$V_report_id = (int)($_POST['report_id'] ?? 0);

if ($V_report_id <= 0) {
    header("Location: ../../public/incident-reports.php");
    exit;
}

// Confirm the report belongs to this barangay and is still editable (Pending).
$OwnStmt = mysqli_prepare($connection, "SELECT status, evacuation_center_id FROM incident_reports WHERE id = ? AND barangay_id = ? LIMIT 1");
mysqli_stmt_bind_param($OwnStmt, "ii", $V_report_id, $V_barangay_id);
mysqli_stmt_execute($OwnStmt);
$OwnResult = mysqli_stmt_get_result($OwnStmt);
$V_existing = mysqli_fetch_assoc($OwnResult);

if (!$V_existing) {
    header("Location: ../../public/incident-reports.php");
    exit;
}
if ($V_existing['status'] != 'Pending') {
    header("Location: ../../public/incident-reports.php?locked=1");
    exit;
}

$V_existing_center_id = (int)($V_existing['evacuation_center_id'] ?? 0);

$V_disaster_type = trim($_POST['disaster_type'] ?? '');
$V_exact_location = trim($_POST['exact_location'] ?? '');
$V_incident_date = trim($_POST['incident_date'] ?? '');
$V_incident_hour = (int)($_POST['incident_hour'] ?? 0);
$V_incident_minute = (int)($_POST['incident_minute'] ?? 0);
$V_incident_ampm = strtoupper(trim($_POST['incident_ampm'] ?? ''));
$V_incident_datetime = '';
$V_incident_datetime_db = null;

if ($V_incident_date != '' && $V_incident_hour >= 1 && $V_incident_hour <= 12 && $V_incident_minute >= 0 && $V_incident_minute <= 59 && ($V_incident_ampm == 'AM' || $V_incident_ampm == 'PM')) {
    $V_hour_24 = $V_incident_hour;

    if ($V_incident_ampm == 'PM' && $V_hour_24 != 12) {
        $V_hour_24 += 12;
    }

    if ($V_incident_ampm == 'AM' && $V_hour_24 == 12) {
        $V_hour_24 = 0;
    }

    $V_incident_datetime_raw = $V_incident_date . ' ' . str_pad($V_hour_24, 2, '0', STR_PAD_LEFT) . ':' . str_pad($V_incident_minute, 2, '0', STR_PAD_LEFT) . ':00';
    $V_incident_timestamp = strtotime($V_incident_datetime_raw);

    if ($V_incident_timestamp !== false) {
        $V_incident_datetime = date('M d, Y h:i A', $V_incident_timestamp);
        $V_incident_datetime_db = date('Y-m-d H:i:s', $V_incident_timestamp);
    }
}

$V_description = trim($_POST['description'] ?? '');
$V_evacuation_needed = $_POST['evacuation_needed'] ?? 'No';

// Road / Bridge Accessibility
$V_road_status = $_POST['road_status'] ?? 'Passable';
$V_road_status = in_array($V_road_status, ['Passable', 'Partially Passable', 'Obstructed'], true) ? $V_road_status : 'Passable';
$V_road_causes = $_POST['road_blockage_causes'] ?? [];
$V_road_causes_text = '';

if (is_array($V_road_causes) && count($V_road_causes) > 0) {
    $V_clean_causes = [];
    foreach ($V_road_causes as $V_cause) {
        $V_cause = trim($V_cause);
        if ($V_cause != '') {
            $V_clean_causes[] = $V_cause;
        }
    }
    if (count($V_clean_causes) > 0) {
        $V_road_causes_text = implode(', ', $V_clean_causes);
    }
}

if ($V_road_status === 'Passable') {
    $V_road_causes_text = '';
}

$V_road_location = trim($_POST['road_location'] ?? '');
$V_evacuation_center_id = $_POST['evacuation_center_id'] ?? '';
$V_affected_people = (int)($_POST['affected_people'] ?? 0);
$V_injured = (int)($_POST['injured'] ?? 0);
$V_dead = (int)($_POST['dead'] ?? 0);
$V_missing = (int)($_POST['missing'] ?? 0);
$V_assistance = $_POST['assistance_needed'] ?? [];
$V_latitude = trim($_POST['N_latitude'] ?? '');
$V_longitude = trim($_POST['N_longitude'] ?? '');

$V_latitude_final = null;
$V_longitude_final = null;

if ($V_latitude != '' && is_numeric($V_latitude)) {
    $V_latitude_final = (float)$V_latitude;
}

if ($V_longitude != '' && is_numeric($V_longitude)) {
    $V_longitude_final = (float)$V_longitude;
}

// Server-side hardening: reject invalid numbers instead of silently coercing to 0.
foreach (['affected_people' => 'Affected people', 'injured' => 'Injured', 'dead' => 'Dead', 'missing' => 'Missing', 'evac_households' => 'Households', 'evac_adults' => 'Adults', 'evac_children' => 'Children', 'evac_members' => 'Family members'] as $V_field => $V_label) {
    if (isset($_POST[$V_field]) && (!is_numeric($_POST[$V_field]) || (float)$_POST[$V_field] < 0)) {
        header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&error=number");
        exit;
    }
}
if ($V_latitude !== '' && (!is_numeric($V_latitude) || (float)$V_latitude < -90 || (float)$V_latitude > 90)) {
    header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&error=number");
    exit;
}
if ($V_longitude !== '' && (!is_numeric($V_longitude) || (float)$V_longitude < -180 || (float)$V_longitude > 180)) {
    header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&error=number");
    exit;
}
// Evacuation center reference must be empty or a valid center id.
if ($V_evacuation_center_id !== '' && !is_numeric($V_evacuation_center_id)) {
    header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&error=number");
    exit;
}

if ($V_disaster_type == '' || $V_description == '' || $V_incident_datetime == '') {
    header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&error=1");
    exit;
}

if ($V_affected_people < 0) $V_affected_people = 0;
if ($V_injured < 0) $V_injured = 0;
if ($V_dead < 0) $V_dead = 0;
if ($V_missing < 0) $V_missing = 0;

// Soft flag: does the saved pin fall outside the reporting barangay's boundary?
$V_pin_outside = incident_pin_outside_flag($connection, $V_barangay_id, $V_barangay_name, $V_latitude_final, $V_longitude_final);
if ($V_pin_outside) {
    error_log("pin check: edit of report #{$V_report_id} for {$V_barangay_name} saved with pin OUTSIDE boundary (lat={$V_latitude_final}, lng={$V_longitude_final})");
}

$V_evacuation_center_id_final = null;

if ($V_evacuation_needed == 'Yes' && $V_evacuation_center_id != '') {
    $V_center_id = (int)$V_evacuation_center_id;

    $CheckCenterQuery = "SELECT id FROM evacuation_centers
                         WHERE id = ?
                         AND barangay = ?
                         AND status IN ('Available', 'Open')
                         LIMIT 1";
    $check_stmt = mysqli_prepare($connection, $CheckCenterQuery);
    mysqli_stmt_bind_param($check_stmt, "is", $V_center_id, $V_barangay_name);
    mysqli_stmt_execute($check_stmt);
    $CheckCenterResult = mysqli_stmt_get_result($check_stmt);

    if ($CheckCenterResult && mysqli_num_rows($CheckCenterResult) > 0) {
        $V_evacuation_center_id_final = $V_center_id;
    } elseif ($V_center_id === $V_existing_center_id) {
        // Keep the center that was already on the report even if it is no
        // longer in the Available/Open list.
        $V_evacuation_center_id_final = $V_center_id;
    }
} else {
    $V_evacuation_needed = 'No';
}

$V_evac_households = max(0, (int)($_POST['evac_households'] ?? 0));
$V_evac_adults = max(0, (int)($_POST['evac_adults'] ?? 0));
$V_evac_children = max(0, (int)($_POST['evac_children'] ?? 0));
$V_evac_members = max(0, (int)($_POST['evac_members'] ?? 0));

$V_assistance_text = '';
if (is_array($V_assistance) && count($V_assistance) > 0) {
    $V_clean_assistance = [];
    foreach ($V_assistance as $V_need) {
        $V_need = trim($V_need);
        if ($V_need != '') {
            $V_clean_assistance[] = $V_need;
        }
    }
    if (count($V_clean_assistance) > 0) {
        $V_assistance_text = implode(', ', $V_clean_assistance);
    }
}

mysqli_begin_transaction($connection);

try {
    $UpdateQuery = "UPDATE incident_reports SET
                        disaster_type = ?,
                        evacuation_needed = ?,
                        evacuation_center_id = ?,
                        evac_households = ?,
                        evac_adults = ?,
                        evac_children = ?,
                        evac_members = ?,
                        incident_datetime = ?,
                        exact_location = ?,
                        road_status = ?,
                        road_blockage_causes = ?,
                        road_location = ?,
                        description = ?,
                        assistance_needed = ?,
                        latitude = ?,
                        longitude = ?,
                        affected_people = ?,
                        injured = ?,
                        dead = ?,
                        missing = ?,
                        pin_outside_area = ?
                    WHERE id = ? AND barangay_id = ? AND status = 'Pending'";

    $update_stmt = mysqli_prepare($connection, $UpdateQuery);
    mysqli_stmt_bind_param(
        $update_stmt,
        "ssiiiiisssssssddiiiiiii",
        $V_disaster_type,
        $V_evacuation_needed,
        $V_evacuation_center_id_final,
        $V_evac_households,
        $V_evac_adults,
        $V_evac_children,
        $V_evac_members,
        $V_incident_datetime_db,
        $V_exact_location,
        $V_road_status,
        $V_road_causes_text,
        $V_road_location,
        $V_description,
        $V_assistance_text,
        $V_latitude_final,
        $V_longitude_final,
        $V_affected_people,
        $V_injured,
        $V_dead,
        $V_missing,
        $V_pin_outside,
        $V_report_id,
        $V_barangay_id
    );

    if (!mysqli_stmt_execute($update_stmt)) {
        throw new Exception(mysqli_error($connection));
    }

    $LogQuery = "INSERT INTO incident_status_logs
                 (incident_report_id, old_status, new_status, remarks, updated_by)
                 VALUES (?, 'Pending', 'Pending', 'Report edited by barangay.', ?)";
    $log_stmt = mysqli_prepare($connection, $LogQuery);
    mysqli_stmt_bind_param($log_stmt, "ii", $V_report_id, $V_user_id);
    mysqli_stmt_execute($log_stmt);

    function save_incident_files($connection, $V_incident_id, $V_user_id, $V_input_name, $V_file_type) {
        $V_errors = [];

        if (!isset($_FILES[$V_input_name])) {
            return $V_errors;
        }

        $V_allowed_photo = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
        $V_allowed_video = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
        $V_max_photo = UPLOAD_MAX_PHOTO_MB * 1024 * 1024;
        $V_max_video = UPLOAD_MAX_VIDEO_MB * 1024 * 1024;
        $V_max_count = ($V_file_type == 'photo') ? UPLOAD_MAX_PHOTOS : UPLOAD_MAX_VIDEOS;

        $V_folder = __DIR__ . "/../../public/uploads/incidents/report_" . $V_incident_id . "/";
        $V_db_folder = "uploads/incidents/report_" . $V_incident_id . "/";

        if (!is_dir($V_folder)) {
            mkdir($V_folder, 0755, true);
        }

        $V_total_files = count($_FILES[$V_input_name]['name']);
        $V_saved = 0;

        for ($i = 0; $i < $V_total_files; $i++) {
            $V_file_err = $_FILES[$V_input_name]['error'][$i];
            $V_file_name = $_FILES[$V_input_name]['name'][$i] ?? '';

            // No file chosen for this slot — not an error.
            if ($V_file_err == UPLOAD_ERR_NO_FILE || $V_file_name === '') {
                continue;
            }

            if ($V_file_err != 0) {
                $V_errors[] = basename($V_file_name) . ": Upload error.";
                continue;
            }

            $V_original_name = $_FILES[$V_input_name]['name'][$i];
            $V_tmp_name = $_FILES[$V_input_name]['tmp_name'][$i];
            $V_file_size = (int)$_FILES[$V_input_name]['size'][$i];
            $V_extension = strtolower(pathinfo($V_original_name, PATHINFO_EXTENSION));

            if ($V_saved >= $V_max_count) {
                $V_errors[] = basename($V_original_name) . ": " . ($V_file_type == 'photo' ? 'Maximum ' . UPLOAD_MAX_PHOTOS . ' photos' : 'Maximum ' . UPLOAD_MAX_VIDEOS . ' videos') . " per report.";
                continue;
            }

            $V_max_size = ($V_file_type == 'photo') ? $V_max_photo : $V_max_video;
            if ($V_file_size > $V_max_size) {
                $V_errors[] = basename($V_original_name) . ": File too large (max " . ($V_file_type == 'photo' ? UPLOAD_MAX_PHOTO_MB : UPLOAD_MAX_VIDEO_MB) . " MB).";
                continue;
            }

            if ($V_file_type == 'photo' && !in_array($V_extension, $V_allowed_photo)) {
                $V_errors[] = basename($V_original_name) . ": Photo type not allowed.";
                continue;
            }

            if ($V_file_type == 'video' && !in_array($V_extension, $V_allowed_video)) {
                $V_errors[] = basename($V_original_name) . ": Video type not allowed.";
                continue;
            }

            $V_clean_name = preg_replace('/[^A-Za-z0-9_\.-]/', '_', pathinfo($V_original_name, PATHINFO_FILENAME));
            $V_new_name = $V_file_type . '_' . date('YmdHis') . '_' . $i . '_' . $V_clean_name . '.' . $V_extension;
            $V_target_path = $V_folder . $V_new_name;
            $V_db_path = $V_db_folder . $V_new_name;

            if (move_uploaded_file($V_tmp_name, $V_target_path)) {
                $AttachmentQuery = "INSERT INTO incident_attachments
                                    (incident_report_id, uploaded_by, file_name, file_path, file_type, file_size)
                                    VALUES (?, ?, ?, ?, ?, ?)";
                $attachment_stmt = mysqli_prepare($connection, $AttachmentQuery);
                mysqli_stmt_bind_param($attachment_stmt, "iisssi", $V_incident_id, $V_user_id, $V_original_name, $V_db_path, $V_file_type, $V_file_size);
                mysqli_stmt_execute($attachment_stmt);
                $V_saved++;
            }
        }

        return $V_errors;
    }

    $V_upload_errors = [];
    $V_upload_errors = array_merge($V_upload_errors, save_incident_files($connection, $V_report_id, $V_user_id, 'photos', 'photo'));
    $V_upload_errors = array_merge($V_upload_errors, save_incident_files($connection, $V_report_id, $V_user_id, 'videos', 'video'));

    mysqli_commit($connection);

    if (!empty($V_upload_errors)) {
        $_SESSION['upload_errors'] = $V_upload_errors;
        header("Location: ../../public/edit-incident-report.php?id=" . $V_report_id . "&upload_warn=1");
    } else {
        header("Location: ../../public/incident-reports.php?updated=1");
    }
    exit;
} catch (Exception $e) {
    mysqli_rollback($connection);
    error_log("Update report error: " . $e->getMessage());
    echo "Something went wrong. Please try again.";
}
?>
