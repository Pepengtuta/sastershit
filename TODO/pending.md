# Pending: PCF & PHO Sub-Role Expansion

## Current State (Flat)
- **PCF** → one account, does everything
- **PHO** → one account, does everything

## Vision (Sub-Role)

### Municipal (PCF)
| DB Value | Display Name | Role |
|----------|-------------|------|
| `pcf` | Municipal | Admin/coordinator — manages all 16 barangays, forwards reports, publishes alerts |
| `pcf_officer` | PCF Officer | Staff — receives referred reports, responds at facility level |

### Provincial (PHO)
| DB Value | Display Name | Role |
|----------|-------------|------|
| `pho` | Provincial | Provincial admin — view-only, referred reports |
| `pho_officer` | PHO Officer | Staff — responds to referred reports, health office operations |

## Hierarchy
```
Barangay:    Chairman → Secretary → BHERT
Municipal:   Municipal (admin) → PCF Officer (staff)
Provincial:  Provincial (admin) → PHO Officer (staff)
```

## Migration Notes
- Current `pcf` accounts become `pcf` (Municipal) — zero conflict
- Current `pho` accounts become `pho` (Provincial) — zero conflict
- New `pcf_officer` and `pho_officer` ENUM values added later
- UI already uses display names (Municipal/Provincial), so rename is seamless
- DB values `pcf`/`pho` stay unchanged until expansion

## Blocks
- DB ENUM migration: `role` column needs `pcf_officer`, `pho_officer` values
- Login flow: new role selection for PCF/PHO sub-roles
- Sidebar: different menu sets per sub-role
- Permissions: admin vs staff action restrictions
- Mobile: new screens for PCF Officer / PHO Officer roles

---

# Pending: Sub-Division Boundaries (Purok / Sitio)

## Problem
Current map (`asset/data/kalibo_barangays.geojson`) has 16 barangay polygons (`adm4` level).
An incident report says "somewhere in Barangay X" — too vague for large barangays like Poblacion Kalibo which has multiple puroks/sitios.

## Vision
- **adm5-level GeoJSON**: purok/sitio polygons nested within each barangay boundary
- **Zoom-triggered display**: barangay outlines at zoom ≤15, purok/sitio outlines appear at zoom ≥16
- **Incident form integration**: dropdown + auto-detect from pin coordinates

## Data Source
- Not obtained yet — plan to request from **Municipal Planning Office (Kalibo LGU)**
- Expected format: `.shp` (shapefile) → convert to GeoJSON
- PSGC hierarchy: adm4 (barangay) → adm5 (purok/sitio)
- Each feature needs: `adm4_en` (parent barangay name), `adm5_en` (purok/sitio name), polygon geometry

## Conversion Pipeline
```
.shp + .dbf + .shx + .prj
        ↓
    QGIS / mapshaper.org
        ↓
    adm5_puroks.geojson (one FeatureCollection, features tagged with parent barangay)
```

## Map Integration (Zoom-Triggered)
```
zoom < 16  →  show barangay outlines only (current behavior)
zoom ≥ 16  →  fade in purok/sitio outlines (lighter stroke, no fill)
```
- Web (Leaflet): `L.geoJSON` layer with `minZoom: 16` or dynamic add/remove on zoom event
- Flutter (flutter_map): `GeoJSONLayer` with zoom check, or two `PolygonLayer` widgets toggled by `MapCamera.zoom`
- Purok polygons should use parent barangay's color family (lighter shade)

## Incident Form Integration (Brainstorm)
Both dropdown + auto-detect with manual override:

### Dropdown Approach
1. BHERT selects barangay first
2. System loads purok/sitio list for that barangay from GeoJSON `adm5_en` values
3. Dropdown shows: `["Purok 1", "Purok 2", "Sitio Centro", ...]`
4. Stored as `subdivision` field on incident report

### Auto-Detect Approach
1. BHERT places pin on map
2. System runs point-in-polygon test against purok/sitio GeoJSON
3. Auto-fills the `subdivision` dropdown
4. BHERT can override if pin placement is imprecise

### DB Changes
- New column: `incident_reports.subdivision VARCHAR(100)` (nullable, for purok/sitio name)
- Display in report details: "Purok 2, Barangay Poblacion"
- No foreign key needed — just the name string

## Files Affected
| Layer | File | Change |
|-------|------|--------|
| Data | `public/asset/data/kalibo_barangays.geojson` | Keep as-is (barangay level) |
| Data | `public/asset/data/adm5_puroks.geojson` | **NEW** — purok/sitio polygons |
| Web Map | `public/map.php` | Add zoom-triggered purok layer |
| Web Create | `public/create-incident-report.php` | Add subdivision dropdown |
| Web Edit | `public/edit-incident-report.php` | Add subdivision dropdown |
| Web Modal | `app/includes/functions.php` | Show subdivision in report detail |
| Web API | `api/create_incident.php` | Accept `subdivision` field |
| Web API | `api/update_incident.php` | Accept `subdivision` field |
| Web API | `api/get_reports.php` | Return `subdivision` field |
| Flutter Create | `lib/screens/barangay/create_incident_screen.dart` | Add subdivision dropdown + auto-detect |
| Flutter Edit | `lib/screens/barangay/edit_incident_screen.dart` | Add subdivision dropdown + auto-detect |
| Flutter Details | `lib/widgets/report_details_sheet.dart` | Show subdivision |
| Flutter Service | `lib/services/incident_service.dart` | Send/receive `subdivision` |
| DB | `incident_reports` table | Add `subdivision VARCHAR(100)` column |

## Blocks
- [ ] Obtain adm5 shapefiles from Municipal Planning Office
- [ ] Convert .shp → GeoJSON (QGIS or mapshaper)
- [ ] Tag each purok/sitio feature with parent `adm4_en`
- [ ] DB migration: `ALTER TABLE incident_reports ADD COLUMN subdivision VARCHAR(100) DEFAULT NULL`
- [ ] Implement zoom-triggered layer on web map
- [ ] Implement zoom-triggered layer on Flutter map
- [ ] Add subdivision dropdown to create/edit forms (web + Flutter)
- [ ] Implement point-in-polygon auto-detect for subdivision
- [ ] Update report detail modals/screens to show subdivision
- [ ] Update APIs to accept/return subdivision field
