PSGC Cloud (what the tool now uses — no auth, read-only)
v1 + v2 endpoints — all read-only GET:
- Regions → code, name
- Provinces → code, name (+ region)
- Cities → code, name, type, district, zip_code
- Municipalities → code, name, type, district, zip_code
- Barangays → code, name, status; v2 adds region, province, city_municipality, zip_code, district
- Chainable hierarchy (v2): regions/{r}/provinces/{p}/cities-municipalities/{m}/barangays/{b} — strict ancestry validation (404 on mismatch)
So in fetch mode alone it already gives you the Philippines' entire official hierarchy: region → province → municipality → barangay with official PSGC codes, plus zip codes, legislative district, and geographic type tags.
What it does NOT offer:
- No write/insert endpoints (read-only reference data)
- No geospatial data — no map polygons, no lat/lng coordinates, no GeoJSON (that's why Obilak loads .geojson files separately)
- No demographic data — no population counts (see official PSA API below)
Official PSA PSGC API (the context_psgc_tool.txt doc — requires a token)
Same read-only endpoints but per PSGC version (Q2_2024, Q4_2023, etc.) plus more metadata:
- income_classification — municipal income class (1st–6th)
- urban_rural — urban/rural classification
- city_class — city classification (Highly Urbanized, etc.)
- regions/provinces/municipalities/barangays append the version
- Sample response includes population_data (e.g. 593,081 for 2015, 609,588 for 2020) and correspondence_code / old_name
Trade-off vs PSGC Cloud: the official one has richer metadata (income class, urban/rural, real population figures) but needs a token (the doc's ?token={your_token} placeholder — no token shown in the file). PSGC Cloud is token-free and sufficient if you only need hierarchy + codes.
Could this help Obilak later?
Possible useful extras, all still just "fetch":
1. Zip codes / districts — auto-populate if you ever add an address field.
2. Official population_data (via PSA token) — could feed capacity/hazard planning dashboards.
3. Income/urban-rural class — useful for triaging response priority across municipalities.
None of these are in the app now; if you want, the natural next step would be a small enhancement to the PSGC tool (e.g., output zip code + district alongside each barangay, since v2 already returns them). Want me to add that, or leave the tool as-is?
▣  Plan · Big Pickle · 35.4s
what does Andagaw
PSGC Code: 0600407001 psgc code means ? is that a zip code ?
+ Thought: 29.4s
No, the PSGC code is not a zip code. They're two completely different things.
PSGC Code (0600407001 = Andagaw)
- Stands for Philippine Standard Geographic Code — the PSA's official identifier for every geographic unit (region → province → municipality/city → barangay).
- It's hierarchical — the digits are built from parent codes:
- 06 = Region VI (Western Visayas)
- 004 = Aklan province
- 07 = Kalibo municipality (0600407000)
- Last digits = barangay: Andagaw = 0600407001, Bachaw Norte = 0600407002, etc. (sequential within each municipality)
- Used for statistics, census, records matching — like a national "ID number" for a place.
Zip code (different field)
- Kalibo's zip code is 5600; Ibajay's is 5605. The API returns it separately as the zip_code field.
- Zip codes are not hierarchical — they're just postal routing numbers, and many barangays share one (all of Kalibo = 5600).
To see the difference in action, fetch https://psgc.cloud/api/v2/cities-municipalities/kalibo — it returns both fields side by side: "code":"0600407000" (PSGC) and "zip_code":"5600".
In the Obilak context: the tool uses the PSGC code just as a unique reference/label; the actual DB barangays.id is its own auto-increment integer, so the codes aren't stored anywhere in the app.