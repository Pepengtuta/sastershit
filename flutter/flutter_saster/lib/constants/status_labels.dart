/// Display labels for incident report statuses.
///
/// Mirrors the web side's incident_status_label() / status_display() in
/// app/includes/functions.php. Internal status values like 'Forwarded to PCF'
/// and 'Referred to PHO' carry internal jargon (PCF/PHO), so they are shown
/// to users with the fuller human-friendly wording used elsewhere.
String incidentStatusLabel(String status, {String? municipality}) {
  if (status == 'Forwarded to PCF') {
    if (municipality == 'Kalibo') return 'Forwarded to MDR-Kalibo';
    if (municipality == 'Ibajay') return 'Forwarded to MDR-Ibajay';
    return 'Forwarded to Municipal (MDR)';
  }
  if (status == 'Under MDR Review') {
    return 'Under Municipal (MDR) Review';
  }
  if (status == 'Under PHO Review') {
    return 'Under Provincial (PDR) Review';
  }
  if (status == 'Referred to PHO' || status == 'Forwarded to PHO') {
    return 'Referred to Provincial (PHO)';
  }
  return status;
}

/// Display-only text for status filter dropdown options. Keeps the raw status
/// value ('Under PHO Review') as the option value for filtering, but renders
/// PDRRMO-friendly wording where a long label exists.
String statusFilterLabel(String status) {
  if (status == 'Forwarded to PCF') return 'Forward to MDR';
  return status == 'Under PHO Review' ? 'Under Provincial (PDR) Review' : status;
}