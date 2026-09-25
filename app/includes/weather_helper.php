<?php

/**
 * OBILAK weather helper (Open-Meteo).
 *
 * Why this file exists:
 *   Both the web dashboard and the mobile API need the same weather block.
 *   Keeping it here means one place to read, one place to fix.
 *
 * What it does, in plain terms:
 *   1. Figures out WHICH point on the map to ask about (the barangay's own
 *      coordinates, or the town-center average for an "all barangays" view).
 *   2. Asks Open-Meteo for current + a few days of forecast. Open-Meteo is
 *      free, needs no API key, and returns simple JSON.
 *   3. Saves the answer in a small cache file for 30 minutes, so we are not
 *      calling the internet on every single page view.
 *   4. Turns the raw numbers into friendly text, an emoji, and a single
 *      "heads-up" banner (none / watch / warning) for heavy rain or wind.
 */

if (!defined('OBILAK_WEATHER_CACHE_SECONDS')) {
    // How long a saved forecast stays "fresh" before we fetch again.
    define('OBILAK_WEATHER_CACHE_SECONDS', 1800); // 30 minutes
}

/**
 * Pick the map point to ask about, based on who is viewing.
 * Returns [latitude, longitude] or [null, null] if we have no coordinates.
 */
function obilak_weather_coords($connection, $role, $barangayId)
{
    // A specific barangay view -> use that barangay's own coordinates.
    if ($role === 'barangay' && (int)$barangayId > 0) {
        $id = (int)$barangayId;
        $result = mysqli_query(
            $connection,
            "SELECT latitude, longitude FROM barangays WHERE id = $id LIMIT 1"
        );
        if ($result && ($row = mysqli_fetch_assoc($result))) {
            if ($row['latitude'] !== null && $row['longitude'] !== null) {
                return [(float)$row['latitude'], (float)$row['longitude']];
            }
        }
    }

    // Otherwise use the town center: the average of all known barangay points.
    $result = mysqli_query(
        $connection,
        "SELECT AVG(latitude) AS lat, AVG(longitude) AS lon
         FROM barangays
         WHERE latitude IS NOT NULL AND longitude IS NOT NULL"
    );
    if ($result && ($row = mysqli_fetch_assoc($result))) {
        if ($row['lat'] !== null && $row['lon'] !== null) {
            return [(float)$row['lat'], (float)$row['lon']];
        }
    }

    return [null, null];
}

/**
 * Turn a WMO weather code into friendly text + an emoji.
 */
function obilak_weather_describe($code)
{
    $code = (int)$code;
    $map = [
        0 => ['Clear sky', '☀️'],
        1 => ['Mainly clear', '🌤️'],
        2 => ['Partly cloudy', '⛅'],
        3 => ['Overcast', '☁️'],
        45 => ['Fog', '🌫️'],
        48 => ['Fog', '🌫️'],
        51 => ['Light drizzle', '🌦️'],
        53 => ['Drizzle', '🌦️'],
        55 => ['Heavy drizzle', '🌦️'],
        56 => ['Freezing drizzle', '🌧️'],
        57 => ['Freezing drizzle', '🌧️'],
        61 => ['Light rain', '🌦️'],
        63 => ['Rain', '🌧️'],
        65 => ['Heavy rain', '🌧️'],
        66 => ['Freezing rain', '🌧️'],
        67 => ['Freezing rain', '🌧️'],
        71 => ['Light snow', '❄️'],
        73 => ['Snow', '❄️'],
        75 => ['Heavy snow', '❄️'],
        77 => ['Snow grains', '❄️'],
        80 => ['Rain showers', '🌦️'],
        81 => ['Rain showers', '🌧️'],
        82 => ['Violent rain showers', '⛈️'],
        85 => ['Snow showers', '❄️'],
        86 => ['Snow showers', '❄️'],
        95 => ['Thunderstorm', '⛈️'],
        96 => ['Thunderstorm with hail', '⛈️'],
        99 => ['Thunderstorm with hail', '⛈️'],
    ];

    if (isset($map[$code])) {
        return ['text' => $map[$code][0], 'emoji' => $map[$code][1]];
    }
    return ['text' => 'Unknown', 'emoji' => '🌡️'];
}

/**
 * Decide if today deserves a heads-up, using today's forecast numbers.
 * Returns ['level' => none|watch|warning, 'message' => string].
 */
function obilak_weather_alert($code, $precipMm, $precipProb, $windKph)
{
    $code = (int)$code;
    $precipMm = (float)$precipMm;
    $precipProb = (float)$precipProb;
    $windKph = (float)$windKph;

    $severe = [65, 82, 95, 96, 99];   // heavy rain, violent showers, thunderstorms
    $notable = [55, 63, 80, 81];      // steady rain / showers

    if (in_array($code, $severe, true) || $precipMm >= 50 || $windKph >= 60) {
        return [
            'level' => 'warning',
            'message' => 'Severe weather expected today. Watch low-lying and flood-prone areas.',
        ];
    }

    if (in_array($code, $notable, true) || $precipProb >= 70 || $precipMm >= 20 || $windKph >= 40) {
        return [
            'level' => 'watch',
            'message' => 'Rainy and windy today. Keep an eye on conditions.',
        ];
    }

    return ['level' => 'none', 'message' => 'No severe weather expected today.'];
}

/**
 * Fetch a URL and return the raw body, or null on failure.
 * Uses cURL when available, otherwise falls back to file_get_contents.
 */
function obilak_weather_fetch($url)
{
    if (function_exists('curl_init')) {
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 6);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 4);
        $body = curl_exec($ch);
        $ok = ($body !== false && curl_getinfo($ch, CURLINFO_HTTP_CODE) === 200);
        curl_close($ch);
        return $ok ? $body : null;
    }

    $context = stream_context_create(['http' => ['timeout' => 6]]);
    $body = @file_get_contents($url, false, $context);
    return $body !== false ? $body : null;
}

/**
 * Main entry point: get a ready-to-display weather block for a point.
 *
 * Always returns an array. When weather cannot be loaded, 'available' is false
 * so the UI can simply hide or grey-out the card.
 */
function obilak_get_weather($lat, $lon)
{
    if ($lat === null || $lon === null) {
        return ['available' => false];
    }

    $lat = round((float)$lat, 4);
    $lon = round((float)$lon, 4);
    $cacheFile = sys_get_temp_dir() . '/obilak_weather_' . md5($lat . ',' . $lon) . '.json';

    // 1) Use the cached forecast if it is still fresh.
    if (is_file($cacheFile) && (time() - filemtime($cacheFile)) < OBILAK_WEATHER_CACHE_SECONDS) {
        $cached = json_decode((string)file_get_contents($cacheFile), true);
        if (is_array($cached)) {
            return $cached;
        }
    }

    // 2) Otherwise ask Open-Meteo.
    $url = 'https://api.open-meteo.com/v1/forecast'
        . '?latitude=' . $lat
        . '&longitude=' . $lon
        . '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m'
        . '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max'
        . '&timezone=Asia%2FManila&forecast_days=4';

    $body = obilak_weather_fetch($url);

    // 3) If the internet call failed, fall back to a stale cache if we have one.
    if ($body === null) {
        if (is_file($cacheFile)) {
            $cached = json_decode((string)file_get_contents($cacheFile), true);
            if (is_array($cached)) {
                $cached['stale'] = true;
                return $cached;
            }
        }
        return ['available' => false];
    }

    $raw = json_decode($body, true);
    if (!is_array($raw) || !isset($raw['current'])) {
        return ['available' => false];
    }

    // 4) Shape the raw response into a small, friendly block.
    $current = $raw['current'];
    $currentDesc = obilak_weather_describe($current['weather_code'] ?? 0);

    $days = [];
    $daily = $raw['daily'] ?? [];
    $dates = $daily['time'] ?? [];
    for ($i = 0; $i < count($dates); $i++) {
        $desc = obilak_weather_describe($daily['weather_code'][$i] ?? 0);
        $label = ($i === 0) ? 'Today' : date('D', strtotime($dates[$i]));
        $days[] = [
            'date' => $dates[$i],
            'label' => $label,
            'emoji' => $desc['emoji'],
            'condition' => $desc['text'],
            'temp_max' => isset($daily['temperature_2m_max'][$i]) ? round($daily['temperature_2m_max'][$i]) : null,
            'temp_min' => isset($daily['temperature_2m_min'][$i]) ? round($daily['temperature_2m_min'][$i]) : null,
            'rain_chance' => isset($daily['precipitation_probability_max'][$i]) ? (int)$daily['precipitation_probability_max'][$i] : null,
        ];
    }

    // The heads-up is based on today's numbers.
    $alert = obilak_weather_alert(
        $daily['weather_code'][0] ?? ($current['weather_code'] ?? 0),
        $daily['precipitation_sum'][0] ?? 0,
        $daily['precipitation_probability_max'][0] ?? 0,
        $daily['wind_speed_10m_max'][0] ?? ($current['wind_speed_10m'] ?? 0)
    );

    $weather = [
        'available' => true,
        'stale' => false,
        'updated_at' => date('M j, g:i A'),
        'current' => [
            'temp' => isset($current['temperature_2m']) ? round($current['temperature_2m']) : null,
            'feels_like' => isset($current['apparent_temperature']) ? round($current['apparent_temperature']) : null,
            'humidity' => isset($current['relative_humidity_2m']) ? (int)$current['relative_humidity_2m'] : null,
            'wind' => isset($current['wind_speed_10m']) ? round($current['wind_speed_10m']) : null,
            'condition' => $currentDesc['text'],
            'emoji' => $currentDesc['emoji'],
        ],
        'days' => $days,
        'alert' => $alert,
    ];

    // 5) Save for next time (best effort; ignore write failures).
    @file_put_contents($cacheFile, json_encode($weather));

    return $weather;
}
