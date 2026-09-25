<?php
require_once __DIR__ . "/api_helper.php";

$is_natural_column = column_exists('disaster_types', 'is_natural') ? ', is_natural' : '';
$query = "SELECT id, name, status$is_natural_column FROM disaster_types WHERE status = 'Active' ORDER BY id ASC";
$result = mysqli_query(db(), $query);

if (!$result) {
    send_response(false, fail_message("Failed to load disaster types.", mysqli_error($connection)));
}

$data = [];
while ($row = mysqli_fetch_assoc($result)) {
    $data[] = [
        "id" => (int)$row["id"],
        "name" => $row["name"],
        "status" => $row["status"],
        "is_natural" => $is_natural_column !== '' ? (int)$row["is_natural"] : 1
    ];
}

send_response(true, "Disaster types loaded successfully.", $data);
?>
