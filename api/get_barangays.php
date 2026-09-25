<?php
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
if ($_SERVER["REQUEST_METHOD"] === "OPTIONS") { http_response_code(200); exit; }
require_once "../config/db_connection.php";
function send_response($success, $message, $data = [], $extra = []) { echo json_encode(array_merge(["success"=>$success,"message"=>$message,"data"=>$data], $extra)); exit; }
$input = json_decode(file_get_contents("php://input"), true);
$acting_user_id = (int)($input['acting_user_id'] ?? ($_GET['acting_user_id'] ?? 0));

// MDR / Mayor sub-role municipality scope (server-derived from the acting user,
// never trusted from client params): mdr_kalibo + mayor_kalibo => Kalibo only,
// mdr_ibajay + mayor_ibajay => Ibajay only. Everyone else sees all barangays.
$scope = null;
if ($acting_user_id > 0) {
    $actorStmt = mysqli_prepare($connection, "SELECT role, sub_role FROM users WHERE id = ? AND status = 'Active' LIMIT 1");
    if ($actorStmt) {
        mysqli_stmt_bind_param($actorStmt, "i", $acting_user_id);
        mysqli_stmt_execute($actorStmt);
        $actorRow = mysqli_fetch_assoc(mysqli_stmt_get_result($actorStmt));
        if ($actorRow && $actorRow['role'] === 'pcf') {
            $sub = strtolower(trim($actorRow['sub_role'] ?? ''));
            if (in_array($sub, ['mdr_kalibo', 'mayor_kalibo'], true)) $scope = 'Kalibo';
            elseif (in_array($sub, ['mdr_ibajay', 'mayor_ibajay'], true)) $scope = 'Ibajay';
        }
        mysqli_stmt_close($actorStmt);
    }
}

$barangay_query = "SELECT id, name, municipality, population FROM barangays WHERE status='Active'";
if ($scope) {
    $scope_esc = mysqli_real_escape_string($connection, $scope);
    $barangay_query .= " AND municipality = '$scope_esc'";
}
$barangay_query .= " ORDER BY municipality ASC, name ASC";
$result = mysqli_query($connection, $barangay_query);
if (!$result) send_response(false, fail_message("Failed to load barangays.", mysqli_error($connection)));
$data = [];
while ($row = mysqli_fetch_assoc($result)) $data[] = ["id"=>(int)$row["id"], "name"=>$row["name"], "municipality"=>$row["municipality"], "population"=>(int)$row["population"]];
send_response(true, "Barangays loaded successfully.", $data, ["scope" => $scope]);
?>