<?php
// Review Reports has been merged into All Incident Reports.
// This page now redirects to keep any old links/bookmarks working.
include "../app/auth/check_session.php";
header("Location: incident-reports.php");
exit;
