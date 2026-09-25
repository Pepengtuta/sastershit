<?php
session_start();
require_once __DIR__ . "/../app/includes/csrf.php";

if (isset($_SESSION['user_id'])) {
    header("Location: dashboard.php");
    exit;
}

$V_error = $_GET['error'] ?? '';
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login | Obilak</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        :root {
            --primary-red: #DC2626;
            --primary-red-hover: #b91c1c;
            --primary-red-disabled: #f87171;
            --background: #F3F4F6;
            --card: #FFFFFF;
            --border: #E5E7EB;
            --text-dark: #111827;
            --text-muted: #9CA3AF;
            --shadow: 0 8px 18px rgba(0, 0, 0, 0.10);
            --radius-card: 22px;
            --radius-input: 14px;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--background);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .login-card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: var(--radius-card);
            box-shadow: var(--shadow);
            padding: 32px 28px;
            width: 100%;
            max-width: 390px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        /* Logo */
        .login-logo {
            width: 120px;
            height: 120px;
            object-fit: contain;
            margin-bottom: 18px;
        }

        /* Title */
        .login-title {
            font-size: 24px;
            font-weight: 700;
            color: var(--text-dark);
            text-align: center;
            margin-bottom: 6px;
        }

        /* Subtitle */
        .login-subtitle {
            font-size: 14px;
            color: var(--text-muted);
            text-align: center;
            margin-bottom: 28px;
        }

        /* Error alert */
        .alert-error {
            width: 100%;
            background: #FEE2E2;
            border: 1px solid #FECACA;
            color: #991B1B;
            border-radius: var(--radius-input);
            padding: 10px 14px;
            font-size: 14px;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        /* Form */
        form {
            width: 100%;
        }

        .field-group {
            margin-bottom: 16px;
        }

        .field-label {
            display: block;
            font-size: 13px;
            font-weight: 500;
            color: var(--text-muted);
            margin-bottom: 6px;
        }

        .input-wrapper {
            position: relative;
            display: flex;
            align-items: center;
        }

        .input-icon {
            position: absolute;
            left: 14px;
            color: var(--text-muted);
            pointer-events: none;
            display: flex;
            align-items: center;
        }

        .form-input {
            width: 100%;
            padding: 13px 14px 13px 44px;
            font-family: 'Inter', sans-serif;
            font-size: 15px;
            color: var(--text-dark);
            background: #FFFFFF;
            border: 1.5px solid var(--border);
            border-radius: var(--radius-input);
            outline: none;
            transition: border-color 0.2s;
        }

        .form-input::placeholder {
            color: var(--text-muted);
        }

        .form-input:focus {
            border-color: var(--primary-red);
            box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.10);
        }

        /* Password toggle */
        .form-input.has-suffix {
            padding-right: 48px;
        }

        .toggle-btn {
            position: absolute;
            right: 12px;
            background: none;
            border: none;
            cursor: pointer;
            color: var(--text-muted);
            padding: 4px;
            display: flex;
            align-items: center;
            transition: color 0.2s;
        }

        .toggle-btn:hover {
            color: var(--text-dark);
        }

        /* Submit button */
        .btn-login {
            width: 100%;
            margin-top: 22px;
            padding: 15px;
            background: var(--primary-red);
            color: #fff;
            font-family: 'Inter', sans-serif;
            font-size: 16px;
            font-weight: 700;
            border: none;
            border-radius: var(--radius-input);
            cursor: pointer;
            transition: background 0.2s, transform 0.1s;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }

        .btn-login:hover {
            background: var(--primary-red-hover);
        }

        .btn-login:active {
            transform: scale(0.98);
        }

        /* Footer note */
        .login-footer {
            margin-top: 18px;
            font-size: 12px;
            color: var(--text-muted);
            text-align: center;
        }
    </style>
</head>

<body>
    <div class="login-card">

        <!-- Logo -->
        <img src="asset/login_logo_pin.png" alt="Obilak Logo" class="login-logo">

        <!-- Title & subtitle -->
        <h1 class="login-title">Ugyon</h1>
        <p class="login-subtitle">BRGY to Municipal to Provincial</p>

        <!-- Error message -->
        <?php if ($V_error != '') { ?>
            <div class="alert-error">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>
                <?php
                    if ($V_error == 'empty') {
                        echo "Please enter username and password.";
                    } elseif ($V_error == 'inactive') {
                        echo "This account is inactive. Please contact the administrator.";
                    } else {
                        echo "Invalid username or password.";
                    }
                ?>
            </div>
        <?php } ?>

        <!-- Login form -->
        <form action="../app/auth/login_process.php" method="post">
            <?php echo csrf_field(); ?>

            <!-- Username -->
            <div class="field-group">
                <label class="field-label" for="username">Username</label>
                <div class="input-wrapper">
                    <span class="input-icon">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                    </span>
                    <input
                        type="text"
                        id="username"
                        name="username"
                        class="form-input"
                        placeholder="username"
                        required
                        autofocus>
                </div>
            </div>

            <!-- Password -->
            <div class="field-group">
                <label class="field-label" for="loginPassword">Password</label>
                <div class="input-wrapper">
                    <span class="input-icon">
                        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" fill="currentColor" viewBox="0 0 24 24"><path d="M18 8h-1V6c0-2.8-2.2-5-5-5S7 3.2 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.7 1.4-3.1 3.1-3.1 1.7 0 3.1 1.4 3.1 3.1v2z"/></svg>
                    </span>
                    <input
                        type="password"
                        id="loginPassword"
                        name="password"
                        class="form-input has-suffix"
                        placeholder="••••••••"
                        required>
                    <button type="button" class="toggle-btn" id="togglePassword" aria-label="Show or hide password">
                        <!-- Eye icon (visible) -->
                        <svg id="iconEye" xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 24 24"><path d="M12 4.5C7 4.5 2.7 7.6 1 12c1.7 4.4 6 7.5 11 7.5s9.3-3.1 11-7.5C21.3 7.6 17 4.5 12 4.5zm0 12.5c-2.8 0-5-2.2-5-5s2.2-5 5-5 5 2.2 5 5-2.2 5-5 5zm0-8c-1.7 0-3 1.3-3 3s1.3 3 3 3 3-1.3 3-3-1.3-3-3-3z"/></svg>
                        <!-- Eye-off icon (hidden) -->
                        <svg id="iconEyeOff" xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 24 24" style="display:none;"><path d="M12 7c2.8 0 5 2.2 5 5 0 .6-.1 1.2-.3 1.8l2.9 2.9c1.5-1.3 2.7-3 3.4-4.7C21.3 7.6 17 4.5 12 4.5c-1.4 0-2.7.3-3.9.7l2.1 2.1c.6-.2 1.1-.3 1.8-.3zM2.5 4.3l2 2 .4.4C3.3 8.1 2 9.9 1 12c1.7 4.4 6 7.5 11 7.5 1.6 0 3.1-.3 4.5-.9l.4.4 2.7 2.7 1.2-1.2L3.7 3.1 2.5 4.3zm5.2 5.2 1.4 1.4c-.1.4-.1.7-.1 1.1 0 1.7 1.3 3 3 3 .4 0 .7 0 1.1-.1l1.4 1.4c-.8.4-1.6.6-2.5.6-2.8 0-5-2.2-5-5 0-.9.2-1.7.7-2.4zm4.3-.8 2.8 2.8V11c0-1.7-1.3-3-3-3h-.2l.4.7z"/></svg>
                    </button>
                </div>
            </div>

            <button type="submit" class="btn-login" id="loginBtn">Login</button>
        </form>

        <p class="login-footer">Demo Only</p>
    </div>

    <script>
        const togglePassword = document.getElementById('togglePassword');
        const loginPassword = document.getElementById('loginPassword');
        const iconEye = document.getElementById('iconEye');
        const iconEyeOff = document.getElementById('iconEyeOff');

        togglePassword.addEventListener('click', () => {
            const isHidden = loginPassword.type === 'password';
            loginPassword.type = isHidden ? 'text' : 'password';
            iconEye.style.display = isHidden ? 'none' : '';
            iconEyeOff.style.display = isHidden ? '' : 'none';
        });
    </script>
</body>

</html>