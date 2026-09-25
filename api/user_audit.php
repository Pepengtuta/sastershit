<?php
// Shared helpers for the mobile user-management endpoints.

// Read-only observer sub-roles: town mayors (PCF) and the Aklan Governor (PHO).
if (!function_exists('is_readonly_role_api')) {
    function is_readonly_role_api($role, $sub_role = '') {
        $role = strtolower((string)$role);
        $sub_role = strtolower((string)$sub_role);
        return ($role === 'pcf' && in_array($sub_role, ['mayor_kalibo', 'mayor_ibajay'], true))
            || ($role === 'pho' && $sub_role === 'governor');
    }
}

if (!function_exists('log_user_action')) {
    function log_user_action($connection, $actor_id, $actor_name, $action, $target_user_id, $target_username, $details = '') {
        $sql = "INSERT INTO user_activity_logs (actor_id, actor_name, action, target_user_id, target_username, details, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())";
        $stmt = mysqli_prepare($connection, $sql);
        if (!$stmt) return false;
        mysqli_stmt_bind_param($stmt, "ississ", $actor_id, $actor_name, $action, $target_user_id, $target_username, $details);
        return mysqli_stmt_execute($stmt);
    }
}

// Returns the actor row if it is an ACTIVE superadmin, otherwise null.
if (!function_exists('verify_superadmin')) {
    function verify_superadmin($connection, $acting_user_id) {
        $acting_user_id = (int)$acting_user_id;
        if ($acting_user_id <= 0) return null;
        $stmt = mysqli_prepare($connection, "SELECT id, name, role, status FROM users WHERE id = ? LIMIT 1");
        mysqli_stmt_bind_param($stmt, "i", $acting_user_id);
        mysqli_stmt_execute($stmt);
        $row = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
        if (!$row || strtolower($row['role']) !== 'superadmin' || $row['status'] !== 'Active') return null;
        return $row;
    }
}

if (!function_exists('count_active_superadmins')) {
    function count_active_superadmins($connection, $exclude_id = 0) {
        $exclude_id = (int)$exclude_id;
        $stmt = mysqli_prepare($connection, "SELECT COUNT(*) AS c FROM users WHERE role = 'superadmin' AND status = 'Active' AND id <> ?");
        mysqli_stmt_bind_param($stmt, "i", $exclude_id);
        mysqli_stmt_execute($stmt);
        $row = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
        return (int)($row['c'] ?? 0);
    }
}

// Returns the actor row if authorized to manage users (superadmin OR barangay admin), otherwise null.
if (!function_exists('verify_actor')) {
    function verify_actor($connection, $acting_user_id) {
        $acting_user_id = (int)$acting_user_id;
        if ($acting_user_id <= 0) return null;

        $stmt = mysqli_prepare($connection,
            "SELECT id, name, role, sub_role, can_manage_users, barangay_id, status
             FROM users WHERE id = ? LIMIT 1");
        mysqli_stmt_bind_param($stmt, "i", $acting_user_id);
        mysqli_stmt_execute($stmt);
        $row = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));

        if (!$row || $row['status'] !== 'Active') return null;

        // Superadmin: full access
        if (strtolower($row['role']) === 'superadmin') return $row;

        // Barangay admin: must have can_manage_users = 1
        if (strtolower($row['role']) === 'barangay' && $row['can_manage_users'] == 1) return $row;

        // PCF admin (MDR sub-role): must have can_manage_users = 1
        if (strtolower($row['role']) === 'pcf' && $row['can_manage_users'] == 1) return $row;

        // PHO Admin (default provincial account): must have can_manage_users = 1
        if (strtolower($row['role']) === 'pho' && $row['can_manage_users'] == 1) return $row;

        return null;
    }
}
?>
