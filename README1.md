# Deploying Ugyon to Your Own Railway Account

This guide walks you through running the **Ugyon** (Saster) system on **your own** Railway account. We'll set up MySQL, deploy the PHP app from GitHub, import the database, and test the login.

Follow the steps in order.

---

## Prerequisites

- A **Railway account** — sign up free at [railway.com](https://railway.com) (use your GitHub account).
- **Your own GitHub repository** with this project's code.
- The **database file** — `database/Railway/capstone-with-data.sql`. This contains the tables and test data.
- **HeidiSQL** (or any MySQL client) — to import the database. Download at [heidisql.com](https://www.heidisql.com/).
- PHP 8.2 or newer. Railway installs it automatically; no setup needed.

---

## Step 1: Create a Railway Project

1. Go to [railway.com](https://railway.com) and sign in with your GitHub account.
2. Click **+ New Project**.
3. Keep this page open — you'll add services to it next.

---

## Step 2: Add MySQL

1. In your project, click **+ Add Service** → **Database** → **MySQL**.
2. Wait until it finishes deploying. Watch the **Deployments** tab on the left.

Railway automatically creates the MySQL variables you need:
- `MYSQLHOST`
- `MYSQLUSER`
- `MYSQLPASSWORD`
- `MYSQLDATABASE`
- `MYSQLPORT`

The database is named **`railway`** by default. You will import your data into it in **Step 4**.

---

## Step 3: Connect Your GitHub Repository

1. In the same project, click **+ Add Service** → **GitHub Repo**.
2. Click **Authorize Railway** to allow it to access your GitHub account.
3. Select your repository (the one containing this project).
4. Select the **`main`** branch.
5. Click **Deploy**.

Railway detects that this is a PHP project because of the `composer.json` and `railpack.json` files in the root. It installs everything automatically.

**Note:** If the build says "Detected Staticfile" instead of "Detected PHP", make sure both `composer.json` and `railpack.json` exist at the top level of your repo.

---

## Step 4: Import Your Database

Your app needs the tables and test data. You'll use HeidiSQL to connect to Railway's MySQL and run the import.

### 4.1 — Enable public access to MySQL

1. Open the **MySQL service** in Railway.
2. Go to **Settings → Networking**.
3. Click **Public Access** (also called **TCP Proxy**). This creates a public address.
4. Note the **hostname** (e.g., `xxxx.proxy.rlwy.net`) and **port** (e.g., `12345`).

### 4.2 — Connect HeidiSQL to Railway

1. Open HeidiSQL.
2. Click **New** (bottom left).
3. Fill in:
   - **Network type:** MySQL or MariaDB (TCP/IP)
   - **Hostname:** the host from 4.1
   - **Port:** the port from 4.1
   - **User:** `root`
   - **Password:** find this in MySQL service → **Variables** tab, copy the value of `MYSQLPASSWORD`
4. Click **Open**.

### 4.3 — Export your local database with data

**Important:** The first time you export, make sure you export **structure AND data**, not just structure.

1. In HeidiSQL, create a new connection to your **local XAMPP** (`127.0.0.1`, user `root`, password empty).
2. Click the `capstone` database.
3. Go to **Tools → Export database as SQL**.
4. Under **Tables:**
   - **Structure:** set to "Create"
   - **Data:** set to "Insert" (this is the important part)
5. Save to a file like `capstone-with-data.sql`.

### 4.4 — Import into Railway

1. Switch to your **Railway connection** (from 4.2).
2. Click the **`railway`** database on the left panel.
3. Go to **File → Run SQL file**.
4. Choose encoding **UTF-8**.
5. Select your `capstone-with-data.sql` file and run it.
6. Wait for it to finish, then press **F5** to refresh.
7. Open a **Query** tab and run:

```sql
SELECT COUNT(*) FROM users;
```

If it returns a number greater than 0, the import succeeded.

---

## Step 5: Add MySQL Variables to Your App

Your PHP app reads the database settings from **environment variables**. Add them to your **GitHub service**.

1. Open the **GitHub service** in Railway (the one running your code, not MySQL).
2. Go to the **Variables** tab.
3. Add these five variables. When you type `${{`, Railway suggests values from the MySQL service — select them:

| Variable Name | Value |
|---------------|-------|
| `MYSQLHOST` | `${{MySQL.MYSQLHOST}}` |
| `MYSQLUSER` | `${{MySQL.MYSQLUSER}}` |
| `MYSQLPASSWORD` | `${{MySQL.MYSQLPASSWORD}}` |
| `MYSQLDATABASE` | `${{MySQL.MYSQLDATABASE}}` |
| `MYSQLPORT` | `${{MySQL.MYSQLPORT}}` |

4. Click **Save**. Railway **automatically redeploys** your app.

---

## Step 6: Update Your Database Connection Code

Your PHP code must read these variables. Update your database connection file (usually `config/db_connection.php`):

```php
<?php
// Read from environment variables set in Railway.
// On localhost, use fallback values for local XAMPP testing.

$db_host = getenv("MYSQLHOST")     ?: "localhost";
$db_user = getenv("MYSQLUSER")     ?: "root";
$db_pass = getenv("MYSQLPASSWORD") ?: "";
$db_name = getenv("MYSQLDATABASE") ?: "capstone";
$db_port = getenv("MYSQLPORT")     ?: 3306;

$connection = mysqli_connect($db_host, $db_user, $db_pass, $db_name, (int)$db_port);

if (!$connection) {
    http_response_code(500);
    die("Database connection failed: " . mysqli_connect_error());
}

mysqli_set_charset($connection, "utf8mb4");
?>
```

**Why this works:**
- On **Railway:** reads the five variables you just added.
- On **your PC:** the variables don't exist, so it uses the fallback values (localhost, root, etc.).
- **Same code. Both places.**

Commit and push to GitHub. Railway redeploys automatically.

---

## Step 7: Get Your Public Domain

1. Open the **GitHub service** in Railway (the one running your code).
2. Go to **Settings → Networking**.
3. Under **Public Networking**, click **Generate Domain**.
4. Railway creates a free domain like `ugyon-production.up.railway.app`.
5. Copy this domain — you'll need it for testing and for the Flutter app.

---

## Step 8: Test the Login

1. Open your browser and go to:
   ```
   https://your-domain/public/
   ```
   Replace `your-domain` with the domain from Step 7 (e.g., `ugyon-production.up.railway.app`).

2. Log in with test credentials (ask the developer for a test username and password).

3. If login succeeds, you're taken to the dashboard.

**If login fails** with "Invalid username or password":
- Make sure the database was imported: in HeidiSQL, run `SELECT COUNT(*) FROM users;` — it should return a number greater than 0.
- Make sure you imported into the **`railway`** database, not `capstone`.
- The password hashes must start with `$2y$` (bcrypt format).

---

## Step 9: Update the Flutter App (If Using)

If you have the Flutter mobile app, update its API configuration to point to your Railway domain.

1. Open the Flutter app's API config file (usually `flutter/flutter_saster/lib/config/api_config.dart` or similar).

2. Update it to use your Railway domain:

```dart
class ApiConfig {
static const String _root = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ugyon-production.up.railway.app',
  );

  static const String baseUrl = '$_root/api';
  static const String fileBaseUrl = _root;

}
```

Replace `your-domain` with your actual Railway domain from **Step 7** (e.g., `ugyon-production.up.railway.app`).

3. Rebuild the APK:
   ```bash
   flutter build apk --release
   ```
   Production APK	
   ```
   flutter build apk --dart-define=API_BASE_URL=https://ugyon-production.up.railway.app

4. Install on your phone and test login. The app now connects to your Railway server, not your local PC.

---

## Step 10: (Optional) Set Up File Uploads with Cloudinary

If users upload incident photos or videos, the app stores them by default on the server's temporary disk. **These files are deleted every time the app redeploys**, so any photos disappear.

To keep uploads permanently, use **Cloudinary** (free plan available):

1. Sign up at [cloudinary.com](https://cloudinary.com) (free).
2. Get your credentials from **Settings → Access Keys**: Cloud Name, API Key, and API Secret.
3. Add to your **GitHub service Variables**:

| Variable Name | Value |
|---------------|-------|
| `CLOUDINARY_CLOUD_NAME` | your Cloud Name |
| `CLOUDINARY_API_KEY` | your API Key |
| `CLOUDINARY_API_SECRET` | your API Secret |

4. Your app (if configured) will now upload to Cloudinary instead of the local disk.

*This step is optional and can be added later.*

---

## Cleanup

Once your app is working:

1. **Optional:** Remove the MySQL **Public Access**. Go to **MySQL → Settings → Networking** and disable **Public Access**. Your app uses an internal connection, so the public proxy is not needed. You can re-enable it later if you need to connect from outside (e.g., HeidiSQL).

2. **Important:** Check your Railway **Billing** page. The free 30-day trial has an end date. After it expires, Railway charges for usage (MySQL storage and network traffic). For a capstone project with light usage, costs are usually minimal or free.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **Build says "Detected Staticfile" instead of "Detected PHP"** | Make sure `composer.json` and `railpack.json` exist in the root of your GitHub repo. If missing, create them and push to GitHub, then redeploy. |
| **404 on the Railway domain** | Make sure the **Root Directory** setting on the GitHub service is empty. Then open `/public/login.php`, not just the domain. |
| **Database connection error** | Check that all five MySQL variables are added to the **GitHub service** (not just the MySQL service). Then redeploy the GitHub service. |
| **Login shows "Invalid username or password"** | The database export only had table structure, not data. In HeidiSQL, export again from local with **Data → Insert**, then re-import into Railway. Verify with `SELECT COUNT(*) FROM users;` — it should return a number greater than 0. |
| **"No database selected" error during import** | Make sure you **select the `railway` database** in HeidiSQL left panel *before* running the SQL file. |
| **Photos/videos uploaded by users disappear after redeploy** | Uploads are stored on temporary disk and get deleted. Set up Cloudinary (Step 10) so files are stored permanently. |
| **Flutter app cannot connect to the server** | Make sure the app's `api_config.dart` uses the Railway domain (from Step 7), not `localhost`. Test on mobile data to verify it works outside Wi-Fi. |

---

## Support

For more information, visit:
- [Railway Docs](https://docs.railway.com)
- [Railpack PHP Guide](https://railpack.com/languages/php)
- [Railway Help Station](https://station.railway.com)

---

**Last updated:** October 2026