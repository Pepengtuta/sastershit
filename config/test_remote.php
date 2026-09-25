<?php
$conn = @mysqli_connect('sql211.infinityfree.com', 'if0_42196608', 'naKCqHgUHtSe', 'if0_42196608_capstone');
if (!$conn) {
    echo "CONNECT_FAIL: " . mysqli_connect_error();
    exit(1);
}
echo "CONNECTED" . PHP_EOL;

// Show tables
$r = mysqli_query($conn, "SHOW TABLES");
$tables = [];
while ($row = mysqli_fetch_row($r)) { $tables[] = $row[0]; }
echo "TABLES (" . count($tables) . "): " . implode(", ", $tables) . PHP_EOL;

// Check if sub_role column exists
$r2 = mysqli_query($conn, "SHOW COLUMNS FROM users LIKE 'sub_role'");
$has_sub_role = mysqli_num_rows($r2) > 0;
echo "HAS sub_role: " . ($has_sub_role ? "YES" : "NO") . PHP_EOL;

// Check if evac_households column exists
$r3 = mysqli_query($conn, "SHOW COLUMNS FROM incident_reports LIKE 'evac_households'");
$has_evac = mysqli_num_rows($r3) > 0;
echo "HAS evac_households: " . ($has_evac ? "YES" : "NO") . PHP_EOL;

mysqli_close($conn);
?>
