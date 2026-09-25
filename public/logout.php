<?php
session_start();
session_unset();
session_destroy();
session_write_close();

header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: Thu, 01 Jan 1970 00:00:00 GMT");
header("Location: login.php");
exit;
?>
