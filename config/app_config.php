<?php
// ============================================================
//  DEBUG MODE  -  the ONLY value you change in this whole system
//
//    true  = show the real error everywhere (while developing)
//    false = show a clean "Something went wrong" everywhere (demo / normal)
//
//  When something breaks, set this to true, reload, read the real error,
//  then set it back to false when you are done.
// ============================================================
const DEBUG_MODE = false;

// ============================================================
//  UPLOAD LIMITS
//  Change these when deploying to a host with different PHP limits.
//  InfinityFree free tier = 10 MB max. XAMPP local = 40-50 MB.
// ============================================================
const UPLOAD_MAX_PHOTO_MB = 15;
const UPLOAD_MAX_VIDEO_MB = 50;
const UPLOAD_MAX_PHOTOS   = 5;
const UPLOAD_MAX_VIDEOS   = 2;

// --- Do not edit below this line ----------------------------------

error_reporting(E_ALL);
ini_set('display_errors', DEBUG_MODE ? '1' : '0');
ini_set('log_errors', '1'); // always keep a copy in the server error log

// Returns the real detail when DEBUG_MODE is true, otherwise the clean
// message. The real detail is always written to the error log either way.
function fail_message($clean_message, $technical_detail = '') {
    if ($technical_detail !== '') {
        error_log($technical_detail);
    }
    return (DEBUG_MODE && $technical_detail !== '') ? $technical_detail : $clean_message;
}
?>
