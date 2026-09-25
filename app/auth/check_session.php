<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Prevent browser from caching protected pages.
// Without this, clicking Back after logout shows a cached page.
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: Thu, 01 Jan 1970 00:00:00 GMT");

if (!isset($_SESSION['user_id'])) {
    header("Location: login.php");
    exit;
}
?>
<script>
// Force reload when browser serves from back-forward cache after logout.
window.addEventListener('pageshow', function(e) {
    if (e.persisted) { location.reload(); }
});
</script>
