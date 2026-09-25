<?php
function h($V_value) {
    return htmlspecialchars((string)$V_value, ENT_QUOTES, 'UTF-8');
}

function role_name($V_role, $V_sub_role = '') {
    if ($V_role == 'superadmin') {
        return 'Super Admin';
    } elseif ($V_role == 'barangay') {
        $map = ['captain' => 'Chairman', 'secretary' => 'Secretary', 'tanod' => 'BHERT'];
        return $map[$V_sub_role] ?? 'Barangay Account';
    } elseif ($V_role == 'pcf') {
        $pcf_map = [
            'mdr_admin' => 'MDR Admin',
            'mdr_kalibo' => 'MDR-Kalibo',
            'mdr_ibajay' => 'MDR-Ibajay',
            'mayor_kalibo' => 'Mayor',
            'mayor_ibajay' => 'Mayor',
        ];
        return $pcf_map[$V_sub_role] ?? 'Municipal';
    } elseif ($V_role == 'pho') {
        if ($V_sub_role == 'pdrrmo') {
            return 'PDRRMO';
        } elseif ($V_sub_role == 'governor') {
            return 'Governor';
        }
        return 'Provincial Admin';
    } else {
        return 'User';
    }
}

// Evacuation center status badge color (single shared mapping).
function center_status_badge_class($V_status) {
    if ($V_status == 'Open') {
        return 'badge-soft-success';
    } elseif ($V_status == 'Available') {
        return 'badge-soft-info';
    } elseif ($V_status == 'Full') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'Closed') {
        return 'badge-soft-danger';
    } elseif ($V_status == 'Needs Supplies') {
        return 'badge-soft-orange';
    } else {
        return 'badge-soft-secondary';
    }
}

// Road / Bridge Accessibility badge color.
function road_status_class($V_status) {
    if ($V_status == 'Passable') {
        return 'badge-soft-success';
    } elseif ($V_status == 'Partially Passable') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'Obstructed') {
        return 'badge-soft-danger';
    } else {
        return 'badge-soft-secondary';
    }
}

function status_class($V_status) {
    if ($V_status == 'Low') {
        return 'badge-soft-success';
    } elseif ($V_status == 'Moderate') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'High') {
        return 'badge-soft-orange';
    } elseif ($V_status == 'Critical') {
        return 'badge-soft-danger';
    } elseif ($V_status == 'Pending') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'Reviewed') {
        return 'badge-soft-info';
    } elseif ($V_status == 'Forwarded to PCF') {
        return 'badge-soft-info';
    } elseif ($V_status == 'Under MDR Review') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'Under Review') {
        return 'badge-soft-info';
    } elseif ($V_status == 'Verified') {
        return 'badge-soft-primary';
    } elseif ($V_status == 'Referred to PHO') {
        return 'badge-soft-danger';
    } elseif ($V_status == 'Under PHO Review') {
        return 'badge-soft-warning';
    } elseif ($V_status == 'Ongoing Response' || $V_status == 'Responding') {
        return 'badge-soft-orange';
    } elseif ($V_status == 'Resolved') {
        return 'badge-soft-success';
    } elseif ($V_status == 'Returned' || $V_status == 'Dismissed') {
        return 'badge-soft-secondary';
    } else {
        return 'badge-soft-secondary';
    }
}

// Philippine DRRM color palette for disaster types.
function disaster_type_color($V_type) {
    $map = [
        'Typhoon'                                  => ['icon' => '#1565C0', 'bg' => '#E3F2FD', 'border' => '#1565C0'],
        'Flood'                                    => ['icon' => '#0277BD', 'bg' => '#E1F5FE', 'border' => '#0277BD'],
        'Storm Surge'                              => ['icon' => '#00838F', 'bg' => '#E0F7FA', 'border' => '#00838F'],
        'Earthquake'                               => ['icon' => '#795548', 'bg' => '#EFEBE9', 'border' => '#5D4037'],
        'Landslide'                                => ['icon' => '#6D4C41', 'bg' => '#EFEBE9', 'border' => '#4E342E'],
        'Fire'                                     => ['icon' => '#D32F2F', 'bg' => '#FFEBEE', 'border' => '#B71C1C'],
        'Drought / El Niño'                        => ['icon' => '#EF6C00', 'bg' => '#FFF3E0', 'border' => '#E65100'],
        'Disease Outbreak'                         => ['icon' => '#7B1FA2', 'bg' => '#F3E5F5', 'border' => '#6A1B9A'],
        'Accident / Mass Casualty Incident'        => ['icon' => '#AD1457', 'bg' => '#FCE4EC', 'border' => '#880E4F'],
        'Others'                                   => ['icon' => '#616161', 'bg' => '#F5F5F5', 'border' => '#424242'],
    ];
    return $map[$V_type] ?? ['icon' => '#616161', 'bg' => '#F5F5F5', 'border' => '#424242'];
}

// Render a colored dot span for a disaster type.
function disaster_type_dot($V_type, $V_size = 8) {
    $c = disaster_type_color($V_type);
    return '<span style="display:inline-block;width:' . $V_size . 'px;height:' . $V_size . 'px;border-radius:50%;background-color:' . h($c['icon']) . ';margin-right:6px;vertical-align:middle;"></span>';
}

// Render a colored badge for a disaster type (dot + text).
function disaster_type_badge($V_type) {
    $c = disaster_type_color($V_type);
    $abbreviations = [
        'Accident / Mass Casualty Incident' => 'Accident / MCI',
    ];
    $display = $abbreviations[$V_type] ?? $V_type;
    return '<span style="display:inline-flex;align-items:center;padding:2px 8px 2px 6px;border-radius:12px;border:1px solid ' . h($c['border']) . ';background:' . h($c['bg']) . ';font-size:12px;white-space:nowrap;" title="' . h($V_type) . '">'
         . '<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background-color:' . h($c['icon']) . ';margin-right:5px;"></span>'
         . h($display)
         . '</span>';
}

/*
 * Role scope (Obilak v1.1)
 * ------------------------
 * Barangay   : submit + view OWN reports only.
 * Municipal   : review ALL reports, change status, publish alerts, manage hotlines (add/edit/delete).
 *              View-only on evacuation centers.
 * Provincial  : view REFERRED reports only (read-only). View-only on hotlines and evac centers.
 * Superadmin : full CRUD on both hotlines and evacuation centers. Manage users.
 */

// Only Municipal can change a report's status. Provincial is read-only; Superadmin only observes.
// Mayor observers (role pcf, sub_role mayor_*) are also read-only.
function can_manage_status($V_role) {
    if (is_readonly_session()) return false;
    return ($V_role == 'pcf');
}

// Only Municipal reviews and acts on incoming reports.
function can_review_reports($V_role) {
    if (is_readonly_session()) return false;
    return ($V_role == 'pcf');
}

// Provincial works the referred-reports view; Superadmin may view it read-only.
function can_view_health_reports($V_role) {
    return ($V_role == 'pho' || $V_role == 'superadmin');
}

// Superadmin and Municipal can add, edit, and delete hotlines.
function can_manage_hotlines($V_role) {
    if (is_readonly_session()) return false;
    return ($V_role == 'superadmin' || $V_role == 'pcf' || $V_role == 'pho');
}

// Superadmin, Provincial Office, and Municipal (PCF/MDR) can add, edit, and delete evacuation centers.
// Barangay Chairmen (captain) can manage ONLY their own barangay's centers — they know where residents are safest.
function can_manage_evacuation_centers($V_role, $V_sub_role = '') {
    if (is_readonly_session()) return false;
    if ($V_role == 'barangay') {
        return ($V_sub_role === 'captain' || $V_sub_role === 'secretary');
    }
    return ($V_role == 'superadmin' || $V_role == 'pho' || $V_role == 'pcf');
}

// Who sees the "Needs & Assistance" board (what a center needs + who donated what to where):
// Provincial Office (all sub-roles), Municipal PCF/MDR (all sub-roles), and Superadmin.
// Read-only observers may VIEW but not pledge; Barangay chairmen use their own center-needs page instead.
function can_view_assistance($V_role) {
    return ($V_role == 'superadmin' || $V_role == 'pho' || $V_role == 'pcf');
}

// The single source of truth for "this evac center is backed by a credible incident".
// Uses the SAME allowlist that powers the verified-reports map/dashboard
// (dashboard.php, get_reports.php, map.php): a need only inherits credibility
// from an incident that has actually been escalated for action. New statuses
// default to NOT credited (fails safe), and Pending/Reviewed/Returned/Dismissed
// never count. Returns the most recent credited incident, or null.
function credited_incident_statuses() {
    return ['Forwarded to PCF', 'Under MDR Review', 'Verified', 'Responding', 'Referred to PHO', 'Under PHO Review', 'Resolved'];
}

// The single source of truth for which center statuses are considered operational
// and therefore eligible for the Needs & Assistance board and the dashboard
// assistance panels ("occupants" profiles + zero-pledge banner included).
// 'Closed' is deliberately excluded — a closed center should not demand pledges.
// Mirrors the enum on the schema, minus 'Closed'. New statuses default to NOT
// visible on the board (fails safe). Build the SQL fragment at the call site with
// "IN ('" . implode("','", center_status_allowlist()) . "')".
function center_status_allowlist() {
    return ['Open', 'Full', 'Needs Supplies', 'Available'];
}

function credited_incident_for_center($V_conn, $V_ec_id) {
    $V_sql = "SELECT id, disaster_type, incident_datetime, exact_location, status
              FROM incident_reports
              WHERE evacuation_center_id = ?
                AND status IN ('" . implode("','", credited_incident_statuses()) . "')
              ORDER BY COALESCE(incident_datetime, created_at) DESC
              LIMIT 1";
    $V_stmt = mysqli_prepare($V_conn, $V_sql);
    if (!$V_stmt) return null;
    mysqli_stmt_bind_param($V_stmt, "i", $V_ec_id);
    mysqli_stmt_execute($V_stmt);
    $V_res = mysqli_stmt_get_result($V_stmt);
    $V_incident = mysqli_fetch_assoc($V_res) ?: null;
    mysqli_free_result($V_res);
    mysqli_stmt_free_result($V_stmt);
    return $V_incident;
}

// Read-only reference headcount derived from credited incident reports linked to
// this center. NEVER writes to evac_center_profile — it exists only for the
// banner/prefill prompts. total_evacuees is adults + children (evac_members is
// unreliable in real data), families maps to evac_households, children maps to
// evac_children. Returns zeros + report_count 0 when nothing is linked/credited.
function computed_headcount_for_center($V_conn, $V_ec_id) {
    $V_sql = "SELECT
                COUNT(*) AS report_count,
                COALESCE(SUM(evac_households), 0) AS households,
                COALESCE(SUM(evac_adults), 0) AS adults,
                COALESCE(SUM(evac_children), 0) AS children
              FROM incident_reports
              WHERE evacuation_center_id = ?
                AND status IN ('" . implode("','", credited_incident_statuses()) . "')";
    $V_stmt = mysqli_prepare($V_conn, $V_sql);
    if (!$V_stmt) return ['report_count' => 0, 'households' => 0, 'adults' => 0, 'children' => 0, 'total_evacuees' => 0];
    mysqli_stmt_bind_param($V_stmt, "i", $V_ec_id);
    mysqli_stmt_execute($V_stmt);
    $V_res = mysqli_stmt_get_result($V_stmt);
    $V_row = mysqli_fetch_assoc($V_res) ?: [];
    mysqli_free_result($V_res);
    mysqli_stmt_free_result($V_stmt);
    $V_adults = (int)($V_row['adults'] ?? 0);
    $V_children = (int)($V_row['children'] ?? 0);
    return [
        'report_count' => (int)($V_row['report_count'] ?? 0),
        'households' => (int)($V_row['households'] ?? 0),
        'adults' => $V_adults,
        'children' => $V_children,
        'total_evacuees' => $V_adults + $V_children,
    ];
}

// Province-wide evidence summary for the Governor (read-only decision support).
// Aggregates ALL non-dismissed incidents for the month/year across the whole
// province (ignores the global municipality filter and referral status), plus
// evacuation-center status and occupancy. Shared by api/get_dashboard_summary.php
// (Governor branch) and the web public/health-reports.php Governor card.
function governor_province_evidence($V_conn, $V_month, $V_year, $V_municipality = '') {
    $V_month = (int)$V_month;
    $V_year  = (int)$V_year;

    // Incident date expression (uses incident_datetime when the column exists).
    $V_col_check = mysqli_query($V_conn, "SHOW COLUMNS FROM incident_reports LIKE 'incident_datetime'");
    $V_has_dt = $V_col_check && mysqli_num_rows($V_col_check) > 0;
    $V_date_expr = $V_has_dt
        ? "COALESCE(incident_reports.incident_datetime, incident_reports.created_at)"
        : "incident_reports.created_at";

    $V_where  = "MONTH($V_date_expr) = ? AND YEAR($V_date_expr) = ? AND LOWER(COALESCE(incident_reports.status, '')) NOT LIKE '%dismiss%'";
    $V_types  = 'ii';
    $V_params = [$V_month, $V_year];

    $V_municipality = trim((string)$V_municipality);

    // Municipality-scoped variant (Mayor evidence): filter incidents to one
    // municipality and aggregate per barangay instead of per municipality.
    // Empty (default) keeps the original province-wide Governor behavior.
    $V_from_join  = '';
    $V_where_all  = $V_where;
    $V_types_all  = $V_types;
    $V_params_all = $V_params;
    if ($V_municipality !== '') {
        $V_from_join  = " INNER JOIN barangays ON incident_reports.barangay_id = barangays.id";
        $V_where_all .= " AND barangays.municipality = ?";
        $V_types_all .= 's';
        $V_params_all[] = $V_municipality;
    }

    // Active incident count + province-wide human impact.
    $V_total_reports = 0;
    $V_impact = ['affected' => 0, 'injured' => 0, 'dead' => 0, 'missing' => 0];
    $V_impact_sql = "SELECT
            COUNT(*) AS total,
            COALESCE(SUM(incident_reports.affected_people), 0) AS affected,
            COALESCE(SUM(incident_reports.injured), 0)         AS injured,
            COALESCE(SUM(incident_reports.dead), 0)            AS dead,
            COALESCE(SUM(incident_reports.missing), 0)         AS missing
        FROM incident_reports$V_from_join
        WHERE $V_where_all";
    $V_stmt = mysqli_prepare($V_conn, $V_impact_sql);
    if ($V_stmt) {
        mysqli_stmt_bind_param($V_stmt, $V_types_all, ...$V_params_all);
        mysqli_stmt_execute($V_stmt);
        $V_res = mysqli_stmt_get_result($V_stmt);
        $V_row = mysqli_fetch_assoc($V_res);
        $V_total_reports = (int)($V_row['total'] ?? 0);
        $V_impact = [
            'affected' => (int)($V_row['affected'] ?? 0),
            'injured'  => (int)($V_row['injured'] ?? 0),
            'dead'     => (int)($V_row['dead'] ?? 0),
            'missing'  => (int)($V_row['missing'] ?? 0),
        ];
        mysqli_free_result($V_res);
    }

    // Disaster-type breakdown (labels normalized to the canonical list).
    $V_norm_type = function ($V_raw) {
        $V_lower = strtolower(trim((string)$V_raw));
        if ($V_lower === '' || $V_lower === 'other' || $V_lower === 'others') return 'Others';
        if ($V_lower === 'typhoon') return 'Typhoon';
        if ($V_lower === 'flood') return 'Flood';
        if ($V_lower === 'storm surge') return 'Storm Surge';
        if ($V_lower === 'earthquake') return 'Earthquake';
        if ($V_lower === 'landslide') return 'Landslide';
        if ($V_lower === 'fire') return 'Fire';
        if (str_contains($V_lower, 'drought') || str_contains($V_lower, 'el nino') || str_contains($V_lower, 'el niño') || str_contains($V_lower, 'el niho')) return 'Drought / El Niño';
        if ($V_lower === 'disease outbreak') return 'Disease Outbreak';
        if (str_contains($V_lower, 'accident') || str_contains($V_lower, 'mass casualty')) return 'Accident / Mass Casualty Incident';
        return 'Others';
    };
    $V_disaster_map = [];
    $V_ds_sql = "SELECT incident_reports.disaster_type, COUNT(*) AS c
                 FROM incident_reports$V_from_join
                 WHERE $V_where_all
                 GROUP BY incident_reports.disaster_type";
    $V_stmt = mysqli_prepare($V_conn, $V_ds_sql);
    if ($V_stmt) {
        mysqli_stmt_bind_param($V_stmt, $V_types_all, ...$V_params_all);
        mysqli_stmt_execute($V_stmt);
        $V_res = mysqli_stmt_get_result($V_stmt);
        while ($V_row = mysqli_fetch_assoc($V_res)) {
            $V_label = $V_norm_type($V_row['disaster_type'] ?? 'Others');
            $V_disaster_map[$V_label] = ($V_disaster_map[$V_label] ?? 0) + (int)($V_row['c'] ?? 0);
        }
        mysqli_free_result($V_res);
    }
    $V_disaster_order = ['Typhoon', 'Flood', 'Storm Surge', 'Earthquake', 'Landslide', 'Fire', 'Drought / El Niño', 'Disease Outbreak', 'Accident / Mass Casualty Incident'];
    $V_disaster_list = [];
    $V_others = 0;
    foreach ($V_disaster_order as $V_label) {
        $V_disaster_list[$V_label] = $V_disaster_map[$V_label] ?? 0;
        unset($V_disaster_map[$V_label]);
    }
    foreach ($V_disaster_map as $V_label => $V_count) {
        $V_others += $V_count;
    }
    $V_disaster_list['Others'] = $V_others;

    // Breakdown by scope: per-municipality (Governor, province-wide) or
    // per-barangay (Mayor, municipality-scoped), with a simple urgency tier.
    $V_municipality_list = [];
    $V_barangay_list = [];
    if ($V_municipality === '') {
        $V_mun_sql = "SELECT barangays.municipality AS municipality,
                             COUNT(*) AS incident_count,
                             COALESCE(SUM(incident_reports.affected_people), 0) AS affected
                      FROM incident_reports
                      INNER JOIN barangays ON incident_reports.barangay_id = barangays.id
                      WHERE $V_where
                      GROUP BY barangays.municipality
                      ORDER BY incident_count DESC";
        $V_stmt = mysqli_prepare($V_conn, $V_mun_sql);
        if ($V_stmt) {
            mysqli_stmt_bind_param($V_stmt, $V_types, ...$V_params);
            mysqli_stmt_execute($V_stmt);
            $V_res = mysqli_stmt_get_result($V_stmt);
            while ($V_row = mysqli_fetch_assoc($V_res)) {
                $V_count = (int)($V_row['incident_count'] ?? 0);
                $V_affected = (int)($V_row['affected'] ?? 0);
                if ($V_count >= 10 || $V_affected >= 100)     { $V_urgency = 'high'; }
                elseif ($V_count >= 3 || $V_affected >= 30)   { $V_urgency = 'elevated'; }
                else                                          { $V_urgency = 'normal'; }
                $V_municipality_list[] = [
                    'municipality'   => $V_row['municipality'] ?? '',
                    'incident_count' => $V_count,
                    'affected'       => $V_affected,
                    'urgency'        => $V_urgency,
                ];
            }
            mysqli_free_result($V_res);
        }
    } else {
        $V_brgy_sql = "SELECT barangays.id AS barangay_id, barangays.name AS barangay,
                              COUNT(*) AS incident_count,
                              COALESCE(SUM(incident_reports.affected_people), 0) AS affected
                       FROM incident_reports$V_from_join
                       WHERE $V_where_all
                       GROUP BY barangays.id, barangays.name
                       ORDER BY incident_count DESC";
        $V_stmt = mysqli_prepare($V_conn, $V_brgy_sql);
        if ($V_stmt) {
            mysqli_stmt_bind_param($V_stmt, $V_types_all, ...$V_params_all);
            mysqli_stmt_execute($V_stmt);
            $V_res = mysqli_stmt_get_result($V_stmt);
            while ($V_row = mysqli_fetch_assoc($V_res)) {
                $V_count = (int)($V_row['incident_count'] ?? 0);
                $V_affected = (int)($V_row['affected'] ?? 0);
                if ($V_count >= 10 || $V_affected >= 100)     { $V_urgency = 'high'; }
                elseif ($V_count >= 3 || $V_affected >= 30)   { $V_urgency = 'elevated'; }
                else                                          { $V_urgency = 'normal'; }
                $V_barangay_list[] = [
                    'barangay_id'    => (int)($V_row['barangay_id'] ?? 0),
                    'barangay'       => $V_row['barangay'] ?? '',
                    'incident_count' => $V_count,
                    'affected'       => $V_affected,
                    'urgency'        => $V_urgency,
                ];
            }
            mysqli_free_result($V_res);
        }
    }

    // Evacuation center counts by status (province-wide).
    $V_evac_status = ['Open' => 0, 'Full' => 0, 'Available' => 0, 'Closed' => 0, 'Needs Supplies' => 0];
    $V_evac_total = 0;
    $V_ev_sql = "SELECT status, COUNT(*) AS c FROM evacuation_centers";
    $V_ev_types = '';
    $V_ev_params = [];
    if ($V_municipality !== '') {
        $V_ev_sql .= " WHERE municipality = ?";
        $V_ev_types = 's';
        $V_ev_params = [$V_municipality];
    }
    $V_ev_sql .= " GROUP BY status";
    $V_ev_stmt = mysqli_prepare($V_conn, $V_ev_sql);
    if ($V_ev_stmt) {
        if ($V_ev_types !== '') mysqli_stmt_bind_param($V_ev_stmt, $V_ev_types, ...$V_ev_params);
        mysqli_stmt_execute($V_ev_stmt);
        $V_res = mysqli_stmt_get_result($V_ev_stmt);
        while ($V_row = mysqli_fetch_assoc($V_res)) {
            $V_status = $V_row['status'] ?? '';
            $V_count  = (int)($V_row['c'] ?? 0);
            $V_evac_total += $V_count;
            if (array_key_exists($V_status, $V_evac_status)) $V_evac_status[$V_status] += $V_count;
        }
        mysqli_free_result($V_res);
    }

    // Over-capacity shelters (>80% occupancy) per municipality.
    $V_oc_list = [];
    $V_allow = array_map(function ($V_s) use ($V_conn) { return mysqli_real_escape_string($V_conn, $V_s); }, center_status_allowlist());
    $V_in = "'" . implode("','", $V_allow) . "'";
    $V_oc_sql = "SELECT municipality,
                         COUNT(*) AS center_count,
                         COALESCE(SUM(capacity), 0) AS capacity,
                         COALESCE(SUM(current_evacuees), 0) AS occupants,
                         SUM(CASE WHEN capacity > 0 AND current_evacuees > capacity * 0.8 THEN 1 ELSE 0 END) AS at_risk_count
                  FROM evacuation_centers
                  WHERE status IN ($V_in)";
    if ($V_municipality !== '') {
        $V_oc_sql .= " AND municipality = ?";
        $V_oc_types = 's';
        $V_oc_params = [$V_municipality];
    } else {
        $V_oc_types = '';
        $V_oc_params = [];
    }
    $V_oc_sql .= " GROUP BY municipality ORDER BY occupants DESC";
    $V_stmt = mysqli_prepare($V_conn, $V_oc_sql);
    if ($V_stmt) {
        if ($V_oc_types !== '') mysqli_stmt_bind_param($V_stmt, $V_oc_types, ...$V_oc_params);
        mysqli_stmt_execute($V_stmt);
        $V_res = mysqli_stmt_get_result($V_stmt);
        while ($V_row = mysqli_fetch_assoc($V_res)) {
            $V_cap = (int)($V_row['capacity'] ?? 0);
            $V_occ = (int)($V_row['occupants'] ?? 0);
            $V_oc_list[] = [
                'municipality'   => $V_row['municipality'] ?? '',
                'center_count'   => (int)($V_row['center_count'] ?? 0),
                'capacity'       => $V_cap,
                'occupants'      => $V_occ,
                'at_risk_count'  => (int)($V_row['at_risk_count'] ?? 0),
                'occupancy_pct'  => $V_cap > 0 ? (int)round($V_occ / $V_cap * 100) : 0,
            ];
        }
        mysqli_free_result($V_res);
    }

    return [
        'month'                => $V_month,
        'year'                 => $V_year,
        'total_reports'        => $V_total_reports,
        'impact'               => $V_impact,
        'disaster_summary'     => $V_disaster_list,
        'municipality_summary' => $V_municipality_list,
        'barangay_summary'     => $V_barangay_list,
        'evac_status_summary'  => $V_evac_status,
        'evac_total'           => $V_evac_total,
        'evac_over_capacity'   => $V_oc_list,
    ];
}

// Display-layer label for an incident status. The stored enum value
// 'Forwarded to PCF' is kept as-is for filtering/logic, but as a label it
// actually means "forwarded to whichever municipal/MDR office covers this
// center", so we render the concrete MDR based on the center's municipality.
function incident_status_label($V_status, $V_municipality = '') {
    if ($V_status === 'Forwarded to PCF') {
        if ($V_municipality === 'Kalibo') return 'Forwarded to MDR-Kalibo';
        if ($V_municipality === 'Ibajay')  return 'Forwarded to MDR-Ibajay';
        return 'Forwarded to Municipal (MDR)';
    }
    if ($V_status === 'Under MDR Review') {
        return 'Under Municipal (MDR) Review';
    }
    if ($V_status === 'Under PHO Review') {
        return 'Under Provincial (PDR) Review';
    }
    return $V_status;
}

// Who can actually donate/pledge assistance on that board. Mayors and the Governor may now
// donate/pledge (they stay read-only everywhere else). Chairmen don't appear on the board at all.
function can_pledge_assistance($V_role, $V_sub_role = '') {
    return can_view_assistance($V_role);
}

// Remaining unmet quantity for a declared need, counting ALL committed supply
// (Pledged + Sent + Delivered). Intentionally stricter than the board's "Still
// Needed" display, which only counts Sent/Delivered: guards against stacking
// pledges so total committed supply would exceed what the center asked for.
// Returns 0 when the need does not exist or is already fully committed.
function pledge_remaining_for_need($connection, $V_need_id) {
    $V_need_id = (int)$V_need_id;
    if ($V_need_id <= 0) return 0;
    $NeedStmt = mysqli_prepare($connection, "SELECT qty_needed FROM evac_center_needs WHERE id = ? LIMIT 1");
    mysqli_stmt_bind_param($NeedStmt, "i", $V_need_id);
    mysqli_stmt_execute($NeedStmt);
    $need = mysqli_fetch_assoc(mysqli_stmt_get_result($NeedStmt));
    mysqli_stmt_free_result($NeedStmt);
    if (!$need) return 0;
    $CommitStmt = mysqli_prepare($connection, "SELECT COALESCE(SUM(CASE WHEN received_at IS NOT NULL THEN qty_received ELSE qty END), 0) AS committed FROM evac_assistance
                                               WHERE need_id = ? AND status IN ('Pledged','Sent','Delivered')");
    mysqli_stmt_bind_param($CommitStmt, "i", $V_need_id);
    mysqli_stmt_execute($CommitStmt);
    $committed = (int)mysqli_fetch_assoc(mysqli_stmt_get_result($CommitStmt))['committed'];
    mysqli_stmt_free_result($CommitStmt);
    return max(0, (int)$need['qty_needed'] - $committed);
}

// Municipal and Provincial can publish alerts. Superadmin can only view them.
function can_publish_alerts($V_role) {
    if (is_readonly_session()) return false;
    return ($V_role == 'pcf' || $V_role == 'pho');
}

// True when the current session user is a read-only observer (mayor sub-role).
function is_readonly_session() {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    return is_readonly_role($_SESSION['role'] ?? '', $_SESSION['sub_role'] ?? '');
}

function render_incident_attachments($connection, $V_report_id) {
    $V_report_id = (int)$V_report_id;

    $V_attachment_query = "SELECT * FROM incident_attachments 
                           WHERE incident_report_id = ? 
                           ORDER BY created_at ASC";
    $stmt = mysqli_prepare($connection, $V_attachment_query);
    mysqli_stmt_bind_param($stmt, "i", $V_report_id);
    mysqli_stmt_execute($stmt);
    $V_attachment_result = mysqli_stmt_get_result($stmt);

    echo '<strong>Attachments</strong>';

    if ($V_attachment_result && mysqli_num_rows($V_attachment_result) > 0) {
        echo '<div class="attachment-display-container mt-2 d-flex flex-wrap align-items-center">';
        
        while ($file = mysqli_fetch_assoc($V_attachment_result)) {
            $V_file_type = strtolower($file['file_type']);
            $V_file_path = $file['file_path'];
            $V_file_name = $file['file_name'];
            $V_extension = strtolower(pathinfo($V_file_name, PATHINFO_EXTENSION));
            
            $V_image_exts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
            $V_video_exts = ['mp4', 'webm', 'ogg', 'mov', 'avi', 'mkv'];
            
            if ($V_file_type == 'photo' || in_array($V_extension, $V_image_exts)) {
                echo '<a href="' . h($V_file_path) . '" target="_blank">';
                echo '    <img src="' . h($V_file_path) . '" class="incident-photo-thumb" alt="' . h($V_file_name) . '" title="' . h($V_file_name) . '">';
                echo '</a>';
            } elseif ($V_file_type == 'video' || in_array($V_extension, $V_video_exts)) {
                echo '<div class="incident-video-preview m-1 text-center">';
                echo '    <video src="' . h($V_file_path) . '" class="border rounded" style="width: 140px; height: 100px; object-fit: cover;" muted preload="metadata"></video>';
                echo '    <br>';
                echo '    <a href="' . h($V_file_path) . '" target="_blank" class="small text-decoration-none">🎥 View Video</a>';
                echo '</div>';
            } else {
                echo '<a class="btn btn-sm btn-outline-secondary m-1 attachment-item d-inline-flex align-items-center" target="_blank" href="' . h($V_file_path) . '">';
                echo '    <span class="me-1">📎</span> ' . h($V_file_name);
                echo '</a>';
            }
        }
        
        echo '</div>';
    } else {
        echo '<div class="text-muted mt-2">No attachments</div>';
    }
}

function render_incident_status_logs($connection, $V_report_id) {
    $V_report_id = (int)$V_report_id;

    $LogQuery = "SELECT incident_status_logs.*, users.name AS updated_by_name
                 FROM incident_status_logs
                 INNER JOIN users ON incident_status_logs.updated_by = users.id
                 WHERE incident_status_logs.incident_report_id = ?
                 ORDER BY incident_status_logs.created_at ASC";
    $stmt = mysqli_prepare($connection, $LogQuery);
    mysqli_stmt_bind_param($stmt, "i", $V_report_id);
    mysqli_stmt_execute($stmt);
    $LogResult = mysqli_stmt_get_result($stmt);

    echo '<strong>Status Timeline</strong>';

    if ($LogResult && mysqli_num_rows($LogResult) > 0) {
        echo '<div class="timeline-box mt-2">';
        while ($log = mysqli_fetch_assoc($LogResult)) {
            echo '<div class="timeline-item">';
            echo '<div><strong>' . h($log['new_status']) . '</strong></div>';
            echo '<div class="small text-muted">';
            if ($log['old_status'] != '') {
                echo h($log['old_status']) . ' → ';
            }
            echo h($log['new_status']);
            echo ' · by ' . h($log['updated_by_name']);
            echo ' · ' . date('M d, Y h:i A', strtotime($log['created_at']));
            echo '</div>';
            if ($log['remarks'] != '') {
                echo '<div class="small">' . h($log['remarks']) . '</div>';
            }
            echo '</div>';
        }
        echo '</div>';
    } else {
        echo '<div class="text-muted mt-2">No status timeline yet.</div>';
    }
}



function render_incident_location_map($row, $V_modal_id) {
    $V_latitude = $row['latitude'] ?? '';
    $V_longitude = $row['longitude'] ?? '';
    $V_barangay_name = $row['barangay_name'] ?? '';
    $V_municipality = $row['barangay_municipality'] ?? '';

    if ($V_latitude === '' || $V_longitude === '' || $V_latitude === null || $V_longitude === null) {
        echo '<strong>Map Location</strong>';
        echo '<div class="text-muted mt-2 mb-3">No map location saved for this report.</div>';
        return;
    }

    $V_map_id = 'incidentLocationMap_' . (int)$row['id'] . '_' . preg_replace('/[^A-Za-z0-9_]/', '', $V_modal_id);
    $V_latitude_js = (float)$V_latitude;
    $V_longitude_js = (float)$V_longitude;
    $V_barangay_js = json_encode($V_barangay_name);
    $V_map_id_js = json_encode($V_map_id);
    $V_modal_id_js = json_encode($V_modal_id);
    ?>
    <strong>Map Location</strong>
    <div id="<?php echo h($V_map_id); ?>" style="height: 280px; border: 1px solid #ddd; border-radius: 8px; margin-top: 8px; margin-bottom: 12px;"></div>
    <div class="small mb-3">
        <a href="https://www.google.com/maps?q=<?php echo $V_latitude_js; ?>,<?php echo $V_longitude_js; ?>" target="_blank" rel="noopener" style="color: #2563eb; text-decoration: none;">
            📍 <?php echo h($V_latitude); ?>, <?php echo h($V_longitude); ?> <span style="text-decoration: underline;">Open in Maps</span>
        </a>
    </div>

    <script>
    (function() {
        window.incidentModalMaps = window.incidentModalMaps || {};

        var mapId = <?php echo $V_map_id_js; ?>;
        var modalId = <?php echo $V_modal_id_js; ?>;
        var barangayName = <?php echo $V_barangay_js; ?>;
        var municipality = <?php echo json_encode($V_municipality); ?>;
        var incidentLat = <?php echo json_encode($V_latitude_js); ?>;
        var incidentLng = <?php echo json_encode($V_longitude_js); ?>;

        function initializeIncidentMap() {
            if (window.incidentModalMaps[mapId]) {
                setTimeout(function() {
                    window.incidentModalMaps[mapId].invalidateSize();
                }, 200);
                return;
            }

            if (typeof L === 'undefined') {
                return;
            }

            var map = L.map(mapId).setView([incidentLat, incidentLng], 16);
            window.incidentModalMaps[mapId] = map;

            L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '&copy; OpenStreetMap contributors'
            }).addTo(map);

            var boundaryAsset = (String(municipality || '').toLowerCase() === 'ibajay')
                ? 'asset/data/ibajay_puroks.geojson'
                : 'asset/data/kalibo_barangays.geojson';

            fetch(boundaryAsset)
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Boundary not found.');
                    }
                    return response.json();
                })
                .then(function(data) {
                    var selectedStyle = {
                        color: '#DC3545',
                        weight: 3,
                        fillColor: '#DC3545',
                        fillOpacity: 0.30
                    };

                    var defaultStyle = {
                        color: '#555555',
                        weight: 1,
                        fillColor: '#ffffff',
                        fillOpacity: 0.05
                    };

                    var hoverStyle = {
                        color: '#DC3545',
                        weight: 2,
                        fillColor: '#DC3545',
                        fillOpacity: 0.15
                    };

                    var selectedLayer = null;

                    var boundaryName = function(feature) {
                        var p = feature && feature.properties ? feature.properties : {};
                        return p.name || p.adm4_en || p.NAME_3 || '';
                    };

                    var isReportFeature = function(feature) {
                        var p = feature && feature.properties ? feature.properties : {};
                        return boundaryName(feature) === barangayName && p.level !== 'municipality';
                    };

                    var geojsonLayer = L.geoJSON(data, {
                        style: function(feature) {
                            if (isReportFeature(feature)) {
                                return selectedStyle;
                            }
                            return defaultStyle;
                        },
                        onEachFeature: function(feature, layer) {
                            var name = boundaryName(feature);
                            if (isReportFeature(feature)) {
                                selectedLayer = layer;
                            }
                            layer.bindTooltip(name, { sticky: true });
                            layer.on({
                                mouseover: function() {
                                    if (isReportFeature(feature)) {
                                        layer.setStyle({
                                            color: '#DC3545',
                                            weight: 3,
                                            fillColor: '#DC3545',
                                            fillOpacity: 0.45
                                        });
                                    } else {
                                        layer.setStyle(hoverStyle);
                                    }
                                },
                                mouseout: function() {
                                    if (isReportFeature(feature)) {
                                        layer.setStyle(selectedStyle);
                                    } else {
                                        geojsonLayer.resetStyle(layer);
                                    }
                                }
                            });
                        }
                    }).addTo(map);

                    L.marker([incidentLat, incidentLng]).addTo(map)
                        .bindPopup('Incident Location<br>' + barangayName)
                        .openPopup();

                    L.circle([incidentLat, incidentLng], {
                        radius: 100,
                        color: '#DC2626',
                        weight: 2,
                        fillColor: '#DC2626',
                        fillOpacity: 0.12
                    }).addTo(map);

                    if (selectedLayer) {
                        map.fitBounds(selectedLayer.getBounds(), { padding: [20, 20] });
                    }

                    setTimeout(function() {
                        map.invalidateSize();
                    }, 200);
                })
                .catch(function() {
                    L.marker([incidentLat, incidentLng]).addTo(map)
                        .bindPopup('Incident Location')
                        .openPopup();

                    L.circle([incidentLat, incidentLng], {
                        radius: 100,
                        color: '#DC2626',
                        weight: 2,
                        fillColor: '#DC2626',
                        fillOpacity: 0.12
                    }).addTo(map);
                });
        }

        document.addEventListener('DOMContentLoaded', function() {
            var modal = document.getElementById(modalId);
            if (modal) {
                modal.addEventListener('shown.bs.modal', initializeIncidentMap);
            }
        });
    })();
    </script>
    <?php
}

function get_incident_detail_modal($connection, $row, $V_modal_id) {
    ob_start();
    ?>
    <div class="modal fade" id="<?php echo h($V_modal_id); ?>" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-scrollable">
            <div class="modal-content">
                <div class="modal-header">
                    <div>
                        <h5 class="modal-title">Incident Report #<?php echo (int)$row['id']; ?></h5>
                        <small class="text-muted">
                            <?php echo ($_SESSION['role'] === 'barangay' ? h($row['creator_name'] ?? 'Unknown') : h($row['barangay_name'] ?? '')); ?> · <?php echo h($row['disaster_type'] ?? ''); ?> · <?php echo h(status_display($row['status'] ?? '')); ?>
                        </small>
                    </div>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="row g-3 mb-3">
                        <div class="col-md-3"><strong>Date</strong><br><?php echo date('M d, Y h:i A', strtotime($row['created_at'])); ?></div>
                        <div class="col-md-3"><strong><?php echo ($_SESSION['role'] === 'barangay') ? 'Reported By' : 'Barangay'; ?></strong><br><?php echo h($_SESSION['role'] === 'barangay' ? ($row['creator_name'] ?? 'Unknown') : ($row['barangay_name'] ?? '')); ?></div>
                        <div class="col-md-3"><strong>Disaster</strong><br><?php echo h($row['disaster_type'] ?? ''); ?></div>
                        <div class="col-md-3"><strong>Status</strong><br><span class="soft-badge <?php echo status_class($row['status']); ?>"><?php echo h(status_display($row['status'])); ?></span></div>
                    </div>

                    <?php if (!empty($row['pin_outside_area'] ?? 0)) { ?>
                    <div class="alert alert-warning py-2 px-3 mb-3">
                        <strong>Pin Outside Area</strong> — The reported location is outside the
                        <?php echo h($row['barangay_name'] ?? 'barangay'); ?> boundary and was flagged for review.
                    </div>
                    <?php } ?>

                    <div class="row g-3 mb-3">
                        <div class="col-md-3"><strong>Affected</strong><br><?php echo (int)($row['affected_people'] ?? 0); ?></div>
                        <div class="col-md-3"><strong>Injured</strong><br><?php echo (int)($row['injured'] ?? 0); ?></div>
                        <div class="col-md-3"><strong>Dead</strong><br><?php echo (int)($row['dead'] ?? 0); ?></div>
                        <div class="col-md-3"><strong>Missing</strong><br><?php echo (int)($row['missing'] ?? 0); ?></div>
                    </div>

                    <div class="mb-3">
                        <strong>Evacuation</strong><br>
                        <?php echo h($row['evacuation_needed'] ?? ''); ?>
                        <?php if (!empty($row['center_name'])) { ?>
                            · <?php echo h($row['center_name']); ?>
                        <?php } ?>
                    </div>

                    <?php
                    $ev_hh = (int)($row['evac_households'] ?? 0);
                    $ev_ad = (int)($row['evac_adults'] ?? 0);
                    $ev_ch = (int)($row['evac_children'] ?? 0);
                    $ev_fm = (int)($row['evac_members'] ?? 0);
                    if ($ev_hh > 0 || $ev_ad > 0 || $ev_ch > 0 || $ev_fm > 0) {
                    ?>
                    <div class="mb-3">
                        <strong>Evacuation Headcount</strong><br>
                        <div class="row g-2 mt-1">
                            <div class="col-auto"><span class="badge bg-secondary"><?php echo $ev_hh; ?> Households</span></div>
                            <div class="col-auto"><span class="badge bg-info"><?php echo $ev_ad; ?> Adults</span></div>
                            <div class="col-auto"><span class="badge bg-warning text-dark"><?php echo $ev_ch; ?> Children</span></div>
                            <div class="col-auto"><span class="badge bg-primary"><?php echo $ev_fm; ?> Family Members</span></div>
                        </div>
                    </div>
                    <?php } ?>

                    <?php if (!empty($row['incident_datetime'])) { ?>
                    <div class="mb-3">
                        <strong>Incident Date and Time</strong><br>
                        <?php echo h(date('M d, Y h:i A', strtotime($row['incident_datetime']))); ?>
                    </div>
                    <?php } ?>

                    <?php if (!empty($row['exact_location'])) { ?>
                    <div class="mb-3">
                        <strong>Exact Location</strong><br>
                        <?php echo h($row['exact_location']); ?>
                    </div>
                    <?php } ?>

                    <?php
                    $V_row_road_status = $row['road_status'] ?? 'Passable';
                    $V_row_road_causes = trim($row['road_blockage_causes'] ?? '');
                    $V_row_road_location = trim($row['road_location'] ?? '');
                    if ($V_row_road_status != 'Passable' || $V_row_road_causes != '' || $V_row_road_location != '') {
                    ?>
                    <div class="mb-3">
                        <strong>Road / Bridge Accessibility</strong><br>
                        <span class="soft-badge <?php echo road_status_class($V_row_road_status); ?>"><?php echo h($V_row_road_status); ?></span>
                        <?php if ($V_row_road_causes != '') { ?>
                            <div class="mt-2"><strong>Causes:</strong> <?php echo h($V_row_road_causes); ?></div>
                        <?php } ?>
                        <?php if ($V_row_road_location != '') { ?>
                            <div class="mt-1"><strong>Road / Bridge:</strong> <?php echo h($V_row_road_location); ?></div>
                        <?php } ?>
                    </div>
                    <?php } ?>

                    <?php if (!empty($row['assistance_needed'])) { ?>
                    <div class="mb-3">
                        <strong>Assistance Needed</strong><br>
                        <?php echo h($row['assistance_needed']); ?>
                    </div>
                    <?php } ?>

                    <strong>Description</strong>
                    <pre class="description-box mt-2 mb-3"><?php echo h($row['description'] ?? ''); ?></pre>

                    <?php render_incident_location_map($row, $V_modal_id); ?>

                    <div class="row g-3">
                        <div class="col-md-6">
                            <?php render_incident_attachments($connection, (int)$row['id']); ?>
                        </div>
                        <div class="col-md-6">
                            <?php render_incident_status_logs($connection, (int)$row['id']); ?>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Close</button>
                </div>
            </div>
        </div>
    </div>
    <?php
    return ob_get_clean();
}

function print_status_button($V_report_id, $V_status, $V_label, $V_class, $V_return_page, $V_remarks = '') {
    ?>
    <form action="../app/reports/update-status.php" method="post" class="d-inline action-form">
            <?php echo csrf_field(); ?>
        <input type="hidden" name="report_id" value="<?php echo (int)$V_report_id; ?>">
        <input type="hidden" name="status" value="<?php echo h($V_status); ?>">
        <input type="hidden" name="return_page" value="<?php echo h($V_return_page); ?>">
        <input type="hidden" name="remarks" value="<?php echo h($V_remarks); ?>">
        <button type="submit" class="btn btn-sm <?php echo h($V_class); ?> action-btn"><?php echo h($V_label); ?></button>
    </form>
    <?php
}

// Superadmin, barangay Chairman/Secretary, PCF MDR Admin, and PHO Admin can manage user accounts.
function can_manage_users($V_role, $V_sub_role = '') {
    if ($V_role === 'superadmin') return true;
    if ($V_role === 'barangay' && in_array($V_sub_role, ['captain', 'secretary'])) return true;
    if ($V_role === 'pcf' && $V_sub_role === 'mdr_admin') return true;
    if ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null)) return true;
    return false;
}

// Human-readable sub-role label.
function sub_role_name($V_sub_role) {
    $map = ['captain' => 'Chairman', 'secretary' => 'Secretary', 'tanod' => 'BHERT',
            'mdr_admin' => 'MDR Admin', 'mdr_kalibo' => 'MDR-Kalibo', 'mdr_ibajay' => 'MDR-Ibajay',
            'pdrrmo' => 'PDRRMO', 'governor' => 'Governor',
            'mayor_kalibo' => 'Mayor', 'mayor_ibajay' => 'Mayor'];
    return $map[$V_sub_role] ?? '-';
}

// Human-readable status label (display-only rename).
function status_display($V_status) {
    $map = [
        'Forwarded to PCF' => 'Forward to MDR',
        'Referred to PHO'  => '→ PRVCL',
        'Forwarded to PHO' => '→ PRVCL',
        // Display-only: PDRRMO-friendly wording on the actual status value
        // ('Under PHO Review' is still used byte-for-byte for logic).
        'Under PHO Review' => 'Under Provincial (PDR) Review',
    ];
    return $map[$V_status] ?? $V_status;
}

// can_manage_users flag value for a given sub-role.
// Default (empty) sub-roles — like the PHO Admin account — are admins.
// MDR-Kalibo / MDR-Ibajay / PDRRMO are operational, never admins.
function sub_role_manage_flag($V_sub_role) {
    if (in_array($V_sub_role, ['captain', 'secretary', 'mdr_admin'], true)) return 1;
    if ($V_sub_role === '' || $V_sub_role === null) return 1;
    return 0;
}

// Default PHO Admin: role 'pho' with no sub-role. Manages PDRRMO accounts.
function is_pho_manager($V_role, $V_sub_role = '') {
    return ($V_role === 'pho' && ($V_sub_role === '' || $V_sub_role === null));
}

// Read-only observer sub-roles: town mayors (PCF) and the Aklan Governor (PHO)
// only VIEW data — never write.
function is_readonly_role($V_role, $V_sub_role = '') {
    return ($V_role === 'pcf' && in_array($V_sub_role, ['mayor_kalibo', 'mayor_ibajay'], true))
        || ($V_role === 'pho' && $V_sub_role === 'governor');
}

// Returns the forced municipality for an MDR sub-role, or null.
function mdr_municipality($V_role, $V_sub_role = '') {
    if ($V_role !== 'pcf') return null;
    $map = ['mdr_kalibo' => 'Kalibo', 'mdr_ibajay' => 'Ibajay'];
    return $map[$V_sub_role] ?? null;
}

// Returns the forced municipality for a mayor observer sub-role, or null.
function mayor_municipality($V_role, $V_sub_role = '') {
    if ($V_role !== 'pcf') return null;
    $map = ['mayor_kalibo' => 'Kalibo', 'mayor_ibajay' => 'Ibajay'];
    return $map[$V_sub_role] ?? null;
}

// Returns the effective municipality filter for the current session user.
// For MDR sub-roles, always returns the forced municipality (ignores user filter).
// For other admin roles, returns the user-chosen filter (or null for "All").
function get_effective_municipality($V_role, $V_sub_role = '') {
    $forced = mdr_municipality($V_role, $V_sub_role);
    if ($forced !== null) return $forced;
    $mayor = mayor_municipality($V_role, $V_sub_role);
    if ($mayor !== null) return $mayor;
    return get_filter_municipality();
}

// Active/Inactive account badge color (fixes the old all-green badge).
function user_status_class($V_status) {
    return ($V_status == 'Active') ? 'badge-soft-success' : 'badge-soft-secondary';
}

// Write one line to the user activity (audit) log.
function log_user_action($connection, $actor_id, $actor_name, $action, $target_user_id, $target_username, $details = '') {
    $sql = "INSERT INTO user_activity_logs (actor_id, actor_name, action, target_user_id, target_username, details, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW())";
    $stmt = mysqli_prepare($connection, $sql);
    if (!$stmt) return false;
    mysqli_stmt_bind_param($stmt, "ississ", $actor_id, $actor_name, $action, $target_user_id, $target_username, $details);
    return mysqli_stmt_execute($stmt);
}

// Count active superadmins other than $exclude_id (used to block last-admin lockout).
function count_active_superadmins($connection, $exclude_id = 0) {
    $stmt = mysqli_prepare($connection, "SELECT COUNT(*) AS c FROM users WHERE role = 'superadmin' AND status = 'Active' AND id <> ?");
    mysqli_stmt_bind_param($stmt, "i", $exclude_id);
    mysqli_stmt_execute($stmt);
    $row = mysqli_fetch_assoc(mysqli_stmt_get_result($stmt));
    return (int)($row['c'] ?? 0);
}

/*
 * Global Municipality Filter (Obilak v1.2)
 * -----------------------------------------
 * Admin roles (pcf, pho, superadmin) can filter all data by municipality.
 * Barangay roles are unaffected — they are already scoped by barangay_id.
 */

// Returns true for roles that should see the municipality filter.
function is_admin_role($V_role) {
    return in_array($V_role, ['pcf', 'pho', 'superadmin']);
}

// Returns the current filter municipality from session, or null for "All Municipalities".
function get_filter_municipality() {
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    $val = $_SESSION['filter_municipality'] ?? null;
    if ($val === '' || $val === 'all') {
        return null;
    }
    return $val;
}

// Returns an array of distinct municipality names from the barangays table.
function get_municipality_list($connection) {
    $result = mysqli_query($connection, "SELECT DISTINCT municipality FROM barangays WHERE municipality IS NOT NULL AND municipality != '' ORDER BY municipality ASC");
    $list = [];
    if ($result) {
        while ($row = mysqli_fetch_assoc($result)) {
            $list[] = $row['municipality'];
        }
    }
    return $list;
}

// Apply municipality filter to a WHERE clause for admin roles.
// Returns the modified WHERE string. $V_params and $V_types are passed by reference.
function apply_municipality_filter($V_role, $V_where, &$V_params, &$V_types) {
    $filter_muni = get_filter_municipality();
    if ($filter_muni && is_admin_role($V_role)) {
        $V_where .= " AND barangays.municipality = ?";
        $V_params[] = $filter_muni;
        $V_types .= 's';
    }
    return $V_where;
}

/*
 * Pin-vs-boundary cross-check (pin_outside_area, Obilak v1.3)
 * ------------------------------------------------------------
 * Incident reports save a map pin (latitude/longitude), but the reporting
 * barangay is decided by the logged-in account (barangay_id), NOT by the
 * pin. These helpers verify whether the pin actually falls inside the
 * barangay's boundary polygon so a mismatch can be surfaced instead of
 * silently letting the pin claim a location it is not in. This is a soft
 * flag, never a blocker: a real emergency near a shared border must never
 * be rejected because of a fuzzy boundary or a slightly-off GPS fix.
 *
 * Polygon sources (already served to the map):
 *   Kalibo -> public/asset/data/kalibo_barangays.geojson (name key adm4_en)
 *   Ibajay -> public/asset/data/ibajay_puroks.geojson    (name key name, skip level=municipality)
 *
 * Coordinates are stored [lng, lat]. Returns true when the pin is OUTSIDE,
 * false when it is inside, and null when the barangay's polygon could not
 * be matched (see pin_outside_barangay: that case is logged loudly so a
 * name-mismatch bug is immediately visible, and it never flags the report).
 */

// Point-in-polygon (ray casting) for one closed ring of [lng, lat] vertices.
function point_in_pin_ring($V_lat, $V_lng, $V_ring) {
    $V_inside = false;
    $V_ring_len = count($V_ring);
    for ($V_i = 0, $V_j = $V_ring_len - 1; $V_i < $V_ring_len; $V_j = $V_i++) {
        $V_lng_i = (float)$V_ring[$V_i][0];
        $V_lat_i = (float)$V_ring[$V_i][1];
        $V_lng_j = (float)$V_ring[$V_j][0];
        $V_lat_j = (float)$V_ring[$V_j][1];

        if ((($V_lat_i > $V_lat) != ($V_lat_j > $V_lat))
            && ($V_lng < ($V_lng_j - $V_lng_i) * ($V_lat - $V_lat_i) / ($V_lat_j - $V_lat_i) + $V_lng_i)) {
            $V_inside = !$V_inside;
        }
    }
    return $V_inside;
}

// True when the pin is inside the geometry's outer rings.
// Polygon      -> the single ring set's outer ring.
// MultiPolygon -> any of its ring sets' outer rings.
function point_in_rings($V_lat, $V_lng, $V_geometry) {
    if (!is_array($V_geometry) || !isset($V_geometry['type']) || !isset($V_geometry['coordinates'])) {
        return false;
    }

    if ($V_geometry['type'] === 'Polygon') {
        $V_coords = $V_geometry['coordinates'];
        if (isset($V_coords[0]) && is_array($V_coords[0]) && count($V_coords[0]) >= 3) {
            return point_in_pin_ring($V_lat, $V_lng, $V_coords[0]);
        }
        return false;
    }

    if ($V_geometry['type'] === 'MultiPolygon') {
        foreach ($V_geometry['coordinates'] as $V_ring_set) {
            if (isset($V_ring_set[0]) && is_array($V_ring_set[0]) && count($V_ring_set[0]) >= 3
                && point_in_pin_ring($V_lat, $V_lng, $V_ring_set[0])) {
                return true;
            }
        }
        return false;
    }

    return false;
}

// Ring test with a boundary-jitter tolerance of 0.0001 degrees (~11 m at
// Aklan's latitude; 1 degree of latitude ≈ 111 km). A pin sitting a few
// metres outside a shared edge (GPS noise, fuzzy borders) re-tests at small
// offsets and counts as inside, so legitimate near-border reports are not
// flagged, while a genuinely wrong location still is.
function point_in_rings_tolerance($V_lat, $V_lng, $V_geometry) {
    if (point_in_rings($V_lat, $V_lng, $V_geometry)) {
        return true;
    }
    $V_tolerance = 0.0001;
    foreach ([
        [$V_lat + $V_tolerance, $V_lng],
        [$V_lat - $V_tolerance, $V_lng],
        [$V_lat, $V_lng + $V_tolerance],
        [$V_lat, $V_lng - $V_tolerance]
    ] as $V_pt) {
        if (point_in_rings($V_pt[0], $V_pt[1], $V_geometry)) {
            return true;
        }
    }
    return false;
}

// Load the barangay-scaled boundary features for a municipality. Both assets
// are FeatureCollections; a per-line fallback also handles JSONL variants.
// Excludes municipality-level outlines (e.g. Ibajay's own polygon), because
// those must never match a barangay.
function barangay_boundary_features($V_municipality) {
    $V_name_key = ($V_municipality === 'Ibajay') ? 'name' : 'adm4_en';
    $V_path = __DIR__ . '/../../public/asset/data/'
        . (($V_municipality === 'Ibajay') ? 'ibajay_puroks.geojson' : 'kalibo_barangays.geojson');

    if (!file_exists($V_path)) {
        error_log("pin check: boundary file missing for municipality='{$V_municipality}' at {$V_path}");
        return [];
    }

    $V_raw = file_get_contents($V_path);
    $V_features = [];

    $V_decoded = json_decode(trim($V_raw), true);
    if (is_array($V_decoded) && ($V_decoded['type'] ?? '') === 'FeatureCollection') {
        $V_features = $V_decoded['features'] ?? [];
    } else {
        // JSONL fallback: one feature object per line (strip any trailing commas).
        foreach (explode("\n", $V_raw) as $V_line) {
            $V_line = trim($V_line);
            if ($V_line === '' || $V_line[0] !== '{') continue;
            if (substr($V_line, -1) === ',') $V_line = rtrim($V_line, ',');
            $V_feature = json_decode($V_line, true);
            if (is_array($V_feature)) $V_features[] = $V_feature;
        }
    }

    $V_result = [];
    foreach ($V_features as $V_feature) {
        $V_props = $V_feature['properties'] ?? [];
        if (!is_array($V_props)) $V_props = [];
        if (($V_props['level'] ?? '') === 'municipality') continue;
        $V_name = trim((string)($V_props[$V_name_key] ?? ''));
        if ($V_name === '') continue;
        $V_result[] = ['name' => $V_name, 'geometry' => $V_feature['geometry'] ?? null];
    }
    return $V_result;
}

// True when the pin is OUTSIDE the given barangay's boundary, false when
// inside, and null when the barangay's polygon could not be matched. When a
// name fails to match, the exact barangay name + municipality + the expected
// name key are logged so a spelling/data mismatch is immediately visible
// instead of silently never flagging that barangay's reports.
function pin_outside_barangay($V_lat, $V_lng, $V_municipality, $V_barangay_name) {
    $V_lat = (float)$V_lat;
    $V_lng = (float)$V_lng;
    $V_lookup_name = strtolower(trim((string)$V_barangay_name));

    foreach (barangay_boundary_features($V_municipality) as $V_feature) {
        if (strtolower($V_feature['name']) === $V_lookup_name) {
            if (!is_array($V_feature['geometry'])) {
                error_log("pin check: {$V_municipality}/{$V_barangay_name} feature found but has no geometry — skipping check");
                return null;
            }
            return !point_in_rings_tolerance($V_lat, $V_lng, $V_feature['geometry']);
        }
    }

    $V_key = ($V_municipality === 'Ibajay') ? 'name' : 'adm4_en';
    error_log("pin check: NO boundary polygon matched barangay name '{$V_barangay_name}' for municipality {$V_municipality} (expected name key: {$V_key})");
    return null;
}

// Convenience wrapper used by the report handlers: resolves the municipality
// from the barangay id, runs pin_outside_barangay, and normalizes the result
// to a stored 0/1 flag (null -> 0, "don't flag on a data gap").
function incident_pin_outside_flag($V_conn, $V_barangay_id, $V_barangay_name, $V_lat, $V_lng) {
    if ($V_lat === null || $V_lng === null || $V_lat === '' || $V_lng === '') {
        return 0;
    }
    $V_stmt = mysqli_prepare($V_conn, "SELECT municipality, name FROM barangays WHERE id = ? LIMIT 1");
    if (!$V_stmt) return 0;
    mysqli_stmt_bind_param($V_stmt, "i", $V_barangay_id);
    mysqli_stmt_execute($V_stmt);
    $V_res = mysqli_stmt_get_result($V_stmt);
    $V_row = mysqli_fetch_assoc($V_res);
    if (!$V_row || trim((string)($V_row['municipality'] ?? '')) === '') {
        return 0;
    }
    if ($V_barangay_name === '' || $V_barangay_name === null) {
        $V_barangay_name = $V_row['name'] ?? '';
    }
    $V_outside = pin_outside_barangay($V_lat, $V_lng, $V_row['municipality'], $V_barangay_name);
    if ($V_outside === null) {
        return 0;
    }
    return $V_outside ? 1 : 0;
}

?>
