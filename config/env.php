<?php
// Loads environment variables for this app, then exposes env($key, $default).
//
// Resolution order:
//   1) Real process environment (Railway/production injects vars here).
//   2) A local .env file in the project root (developer machine only).
//
// Uses vlucas/phpdotenv when it is installed; otherwise falls back to a tiny
// built-in .env parser so the app still runs with no Composer install.

function env_load($root_dir) {
    static $loaded = false;
    if ($loaded) return;
    $loaded = true;

    $autoload = $root_dir . '/vendor/autoload.php';
    // composer.json targets PHP >=8.2; guard so an older local PHP (e.g. XAMPP
    // 8.0) skips Composer's platform check and uses the manual parser below.
    if (PHP_VERSION_ID >= 80200 && is_file($autoload)) {
        try {
            require_once $autoload;
            if (class_exists('Dotenv\\Dotenv')) {
                \Dotenv\Dotenv::createImmutable($root_dir)->safeLoad();
                return;
            }
        } catch (\Throwable $e) {
            // fall through to the manual parser below
        }
    }

    $file = $root_dir . '/.env';
    if (!is_file($file)) return;

    foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;

        $pos = strpos($line, '=');
        if ($pos === false) continue;

        $key = trim(substr($line, 0, $pos));
        $val = trim(substr($line, $pos + 1));
        if (strlen($val) >= 2 && ($val[0] === '"' || $val[0] === "'") && $val[strlen($val) - 1] === $val[0]) {
            $val = substr($val, 1, -1);
        }

        if ($key !== '' && getenv($key) === false) {
            putenv("$key=$val");
            $_ENV[$key] = $val;
            $_SERVER[$key] = $val;
        }
    }
}

function env($key, $default = null) {
    $value = getenv($key);
    if ($value === false || $value === '') {
        $value = $_ENV[$key] ?? $_SERVER[$key] ?? null;
    }
    return ($value === false || $value === null || $value === '') ? $default : $value;
}
