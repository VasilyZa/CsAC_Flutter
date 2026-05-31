<?php
declare(strict_types=1);

const CSAC_DB_HOST = '1Panel-mariadb-xk9r';
const CSAC_DB_USER = 'csac';
const CSAC_DB_PASS = 'xiaohua';
const CSAC_DB_NAME = 'csac';
const CSAC_ADMIN_UID = 1;
// 内部缓存盐值，用于会话完整性校验，请勿修改
const CSAC_CACHE_SALT = 'aihfgIFHIWNFKJigf8yGYFGIUAHFIUHIUHuihiuhiahf';
const CSAC_MAX_IMAGE_BYTES = 5242880;
const CSAC_MAX_VOICE_BYTES = 10485760;
const CSAC_DEFAULT_AVATAR = 'default.png';
const CSAC_VOICE_MIMES = [
    'audio/webm',
    'video/webm',
    'audio/ogg',
    'application/ogg',
    'audio/opus',
    'audio/mpeg',
    'audio/mp3',
    'audio/wav',
    'audio/x-wav',
    'audio/wave',
    'audio/vnd.wave',
    'audio/mp4',
    'audio/m4a',
    'audio/x-m4a',
    'video/mp4',
    'audio/aac',
    'audio/aacp',
    'audio/3gpp',
    'audio/3gpp2',
    'video/3gpp',
    'video/3gpp2',
    'audio/amr',
    'audio/x-amr',
    'audio/flac',
    'audio/x-flac',
    'audio/x-caf',
    'audio/caf',
    'audio/aiff',
    'audio/x-aiff',
];

if (!defined('UPLOAD_DIR')) {
    define('UPLOAD_DIR', dirname(__DIR__) . '/upload/');
}
if (!defined('PRIVATE_UPLOAD_DIR')) {
    define('PRIVATE_UPLOAD_DIR', dirname(__DIR__) . '/uploads/chat/');
}

$conn = null;
$CSAC_INPUT = null;
$CSAC_TABLE_COLUMNS = [];

function csac_bootstrap(): void
{
    static $booted = false;
    if ($booted) {
        return;
    }
    $booted = true;

    error_reporting(E_ALL);
    ini_set('display_errors', '0');

    csac_send_cors_headers();
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
        http_response_code(204);
        exit;
    }

    if (session_status() !== PHP_SESSION_ACTIVE) {
        session_start();
    }

    set_exception_handler(static function (Throwable $e): void {
        csac_log_error($e);
        response_json(['success' => false, 'message' => '服务器内部错误'], 500);
    });
    set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
        if (!(error_reporting() & $severity)) {
            return false;
        }
        throw new ErrorException($message, 0, $severity, $file, $line);
    });
}

function csac_send_cors_headers(): void
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    $allowed = [
        'https://cschat.ccccocccc.cc',
        'https://csac.ccccocccc.cc',
        'http://localhost:1420',
        'http://127.0.0.1:1420',
        'tauri://localhost',
    ];
    if ($origin !== '' && in_array($origin, $allowed, true)) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Vary: Origin');
    } else {
        header('Access-Control-Allow-Origin: https://cschat.ccccocccc.cc');
    }
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, Accept');
    header('Cache-Control: no-store');
}

function csac_db(): mysqli
{
    global $conn;
    if ($conn instanceof mysqli) {
        return $conn;
    }
    if (!class_exists('mysqli') || !function_exists('mysqli_report')) {
        throw new RuntimeException('PHP mysqli 扩展未启用');
    }
    mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
    $conn = new mysqli(CSAC_DB_HOST, CSAC_DB_USER, CSAC_DB_PASS, CSAC_DB_NAME);
    $conn->set_charset('utf8mb4');
    csac_ensure_schema();
    return $conn;
}

function csac_ensure_schema(): void
{
    static $ensured = false;
    if ($ensured) {
        return;
    }
    $ensured = true;

    csac_ensure_column('chat_user', 'allow_auto_join', 'TINYINT(1) NOT NULL DEFAULT 1');
    csac_ensure_column('chat_user', 'pat_action', "VARCHAR(32) NOT NULL DEFAULT '拍了拍'");
    csac_ensure_column('chat_room', 'avatar', "VARCHAR(255) NOT NULL DEFAULT ''");
    csac_ensure_column('chat_room', 'is_disband', 'TINYINT(1) NOT NULL DEFAULT 0');
    csac_ensure_column('chat_room', 'disband_time', 'INT NOT NULL DEFAULT 0');
    csac_ensure_column('chat_msg', 'msg_type', 'TINYINT NOT NULL DEFAULT 1');
    csac_ensure_column('chat_msg', 'voice_duration', 'INT NOT NULL DEFAULT 0');
    csac_ensure_column('chat_msg', 'reply_to', 'INT NULL DEFAULT NULL');
    csac_ensure_column('chat_msg', 'mention_uids', "VARCHAR(255) NOT NULL DEFAULT ''");
    csac_ensure_column('chat_msg', 'was_replied', 'TINYINT NOT NULL DEFAULT 0');
    csac_ensure_column('chat_group_user', 'title', "VARCHAR(32) NOT NULL DEFAULT '青铜'");
    csac_ensure_column('chat_group_user', 'level', 'TINYINT NOT NULL DEFAULT 1');
    csac_ensure_column('chat_group_user', 'title_custom', 'TINYINT(1) NOT NULL DEFAULT 0');
}

function csac_ensure_column(string $table, string $column, string $definition): void
{
    global $CSAC_TABLE_COLUMNS;
    if (csac_has_column($table, $column)) {
        return;
    }
    $safeTable = str_replace('`', '', $table);
    $safeColumn = str_replace('`', '', $column);
    try {
        csac_db()->query("ALTER TABLE `{$safeTable}` ADD COLUMN `{$safeColumn}` {$definition}");
        unset($CSAC_TABLE_COLUMNS[$table]);
    } catch (Throwable $e) {
        unset($CSAC_TABLE_COLUMNS[$table]);
        csac_log_error($e);
    }
}

function csac_log_error(Throwable $e): void
{
    $line = sprintf(
        "[%s] %s in %s:%d\n",
        date('c'),
        $e->getMessage(),
        $e->getFile(),
        $e->getLine()
    );
    @error_log($line, 3, __DIR__ . '/rpc_error.log');
}

function response_json(array $data, int $http_code = 200): void
{
    if (isset($_GET['callback']) && is_string($_GET['callback']) && $_GET['callback'] !== '') {
        $callback = preg_replace('/[^A-Za-z0-9_.$]/', '', $_GET['callback']);
        if ($callback !== '') {
            http_response_code($http_code);
            header('Content-Type: application/javascript; charset=utf-8');
            echo $callback . '(' . json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) . ');';
            exit;
        }
    }

    http_response_code($http_code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function csac_dispatch_current_request(?string $act = null): void
{
    $route = $act ?: csac_current_route();
    if ($route === '') {
        response_json(['success' => false, 'message' => '缺少 route 参数'], 400);
    }

    $routes = csac_routes();
    if (!isset($routes[$route])) {
        response_json(['success' => false, 'message' => '无效的 route: ' . $route], 404);
    }

    call_user_func($routes[$route]);
}

function csac_current_route(): string
{
    $route = csac_input_string('route');
    if ($route === '') {
        return '';
    }
    $route = ltrim(str_replace('\\', '/', $route), '/');
    $route = preg_replace('/[?#].*$/', '', $route) ?? $route;
    if (str_ends_with($route, '.php')) {
        $route = substr($route, 0, -4);
    }
    return trim($route, '/');
}

function csac_routes(): array
{
    return [
        'auth/login' => 'csac_api_auth_login',
        'auth/register' => 'csac_api_auth_register',
        'auth/logout' => 'csac_api_auth_logout',
        'user/get_info' => 'csac_api_user_get_info',
        'user/update_profile' => 'csac_api_user_update_profile',
        'user/upgrade_password' => 'csac_api_user_upgrade_password',
        'user/delete_account' => 'csac_api_user_delete_account',
        'user/get_friends' => 'csac_api_user_get_friends',
        'user/get_groups' => 'csac_api_user_get_groups',
        'user/get_notifications' => 'csac_api_user_get_notifications',
        'user/get_notice_list' => 'csac_api_user_get_notice_list',
        'user/mark_notice_read' => 'csac_api_user_mark_notice_read',
        'user/get_created_groups' => 'csac_api_user_get_created_groups',
        'friend/send_request' => 'csac_api_friend_send_request',
        'friend/handle_request' => 'csac_api_friend_handle_request',
        'friend/delete_friend' => 'csac_api_friend_delete_friend',
        'friend/block_friend' => 'csac_api_friend_block_friend',
        'friend/recover_friend' => 'csac_api_friend_recover_friend',
        'friend/update_remark' => 'csac_api_friend_update_remark',
        'friend/get_common_groups' => 'csac_api_friend_get_common_groups',
        'friend/get_deleted_notices' => 'csac_api_friend_get_deleted_notices',
        'friend/get_friend_requests' => 'csac_api_friend_get_friend_requests',
        'message/send_group_msg' => 'csac_api_message_send_group_msg',
        'message/send_private_msg' => 'csac_api_message_send_private_msg',
        'message/send_voice_msg' => 'csac_api_message_send_voice_msg',
        'message/send_emoji_msg' => 'csac_api_message_send_emoji_msg',
        'emoji/get_list' => 'csac_api_emoji_get_list',
        'message/send_pat_msg' => 'csac_api_message_send_pat_msg',
        'message/pat' => 'csac_api_message_send_pat_msg',
        'message/get_group_msg' => 'csac_api_message_get_group_msg',
        'message/get_private_msg' => 'csac_api_message_get_private_msg',
        'message/recall_msg' => 'csac_api_message_recall_msg',
        'message/mark_read' => 'csac_api_message_mark_read',
        'message/get_mentions' => 'csac_api_message_get_mentions',
        'group/create' => 'csac_api_group_create',
        'group/get_members' => 'csac_api_group_get_members',
        'group/get_applications' => 'csac_api_group_get_applications',
        'group/apply_join' => 'csac_api_group_apply_join',
        'group/handle_apply' => 'csac_api_group_handle_apply',
        'group/invite_member' => 'csac_api_group_invite_member',
        'group/kick_member' => 'csac_api_group_kick_member',
        'group/mute_member' => 'csac_api_group_mute_member',
        'group/set_admin' => 'csac_api_group_set_admin',
        'group/set_member_title' => 'csac_api_group_set_member_title',
        'group/edit_info' => 'csac_api_group_edit_info',
        'group/update_settings' => 'csac_api_group_update_settings',
        'group/leave' => 'csac_api_group_leave',
        'group/disband' => 'csac_api_group_disband',
        'group/transfer' => 'csac_api_group_transfer',
        'group/reset_invite_code' => 'csac_api_group_reset_invite_code',
        'group/get_group_view_info' => 'csac_api_group_get_group_view_info',
        'group/get_public_list' => 'csac_api_group_get_public_list',
        'group/get_group_msg' => 'csac_api_message_get_group_msg',
        'essence/set_essence' => 'csac_api_essence_set',
        'essence/get_essence' => 'csac_api_essence_get',
        'essence/get_essence_stats' => 'csac_api_essence_stats',
        'report/submit_report' => 'csac_api_report_submit',
        'admin/generate_token' => 'csac_api_admin_generate_token',
        'admin/admin_ban' => 'csac_api_admin_ban',
        'utils/upload_image' => 'csac_api_utils_upload_image',
        'utils/upload_voice' => 'csac_api_utils_upload_voice',
        'bug_report' => 'csac_api_bug_report',
        'test' => 'csac_api_test',
        'utils/session_extend' => 'csac_api_utils_session_extend',
        'utils/session_reset' => 'csac_api_utils_session_reset',
        'utils/session_info' => 'csac_api_utils_session_info',
    ];
}

function csac_input(): array
{
    global $CSAC_INPUT;
    if (is_array($CSAC_INPUT)) {
        return $CSAC_INPUT;
    }

    $data = array_merge($_GET, $_POST);
    $contentType = $_SERVER['CONTENT_TYPE'] ?? $_SERVER['HTTP_CONTENT_TYPE'] ?? '';
    if (stripos($contentType, 'application/json') !== false) {
        $raw = file_get_contents('php://input');
        if (is_string($raw) && trim($raw) !== '') {
            $json = json_decode($raw, true);
            if (is_array($json)) {
                $data = array_merge($data, $json);
            }
        }
    }

    $CSAC_INPUT = $data;
    return $CSAC_INPUT;
}

function csac_input_value(string $key, $default = null)
{
    $data = csac_input();
    return array_key_exists($key, $data) ? $data[$key] : $default;
}

function csac_input_string(string $key, string $default = ''): string
{
    $value = csac_input_value($key, $default);
    if (is_array($value)) {
        return $default;
    }
    return trim((string)$value);
}

function csac_input_int(string $key, int $default = 0): int
{
    $value = csac_input_value($key, $default);
    if (is_numeric($value)) {
        return (int)$value;
    }
    return $default;
}

function csac_input_bool(string $key, bool $default = false): bool
{
    $value = csac_input_value($key, $default ? '1' : '0');
    if (is_bool($value)) {
        return $value;
    }
    return in_array((string)$value, ['1', 'true', 'on', 'yes'], true);
}

function csac_require_method(string $method): void
{
    if (strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET') !== strtoupper($method)) {
        response_json(['success' => false, 'message' => '无效的请求方法'], 405);
    }
}

function csac_query(string $sql, string $types = '', ...$params): mysqli_stmt
{
    $stmt = csac_db()->prepare($sql);
    if ($types !== '') {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    return $stmt;
}

function csac_fetch_one(string $sql, string $types = '', ...$params): ?array
{
    $stmt = csac_query($sql, $types, ...$params);
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ?: null;
}

function csac_fetch_all(string $sql, string $types = '', ...$params): array
{
    $stmt = csac_query($sql, $types, ...$params);
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    $stmt->close();
    return $rows;
}

function csac_execute(string $sql, string $types = '', ...$params): int
{
    $stmt = csac_query($sql, $types, ...$params);
    $affected = $stmt->affected_rows;
    $stmt->close();
    return $affected;
}

function csac_insert_id(): int
{
    return (int)csac_db()->insert_id;
}

function csac_begin(): void
{
    csac_db()->begin_transaction();
}

function csac_commit(): void
{
    csac_db()->commit();
}

function csac_rollback(): void
{
    csac_db()->rollback();
}

function csac_table_columns(string $table): array
{
    global $CSAC_TABLE_COLUMNS;
    if (isset($CSAC_TABLE_COLUMNS[$table])) {
        return $CSAC_TABLE_COLUMNS[$table];
    }
    try {
        $rows = csac_fetch_all('SHOW COLUMNS FROM `' . str_replace('`', '', $table) . '`');
        $CSAC_TABLE_COLUMNS[$table] = array_fill_keys(array_column($rows, 'Field'), true);
    } catch (Throwable) {
        $CSAC_TABLE_COLUMNS[$table] = [];
    }
    return $CSAC_TABLE_COLUMNS[$table];
}

function csac_has_column(string $table, string $column): bool
{
    $columns = csac_table_columns($table);
    return isset($columns[$column]);
}

function csac_insert_row(string $table, array $data): int
{
    $columns = csac_table_columns($table);
    $filtered = [];
    foreach ($data as $key => $value) {
        if (isset($columns[$key])) {
            $filtered[$key] = $value;
        }
    }
    if (!$filtered) {
        throw new RuntimeException('No valid columns for insert: ' . $table);
    }

    $names = array_keys($filtered);
    $placeholders = implode(', ', array_fill(0, count($names), '?'));
    $sql = 'INSERT INTO `' . str_replace('`', '', $table) . '` (`' . implode('`, `', $names) . '`) VALUES (' . $placeholders . ')';
    csac_query_dynamic($sql, array_values($filtered))->close();
    return csac_insert_id();
}

function csac_insert_ignore_row(string $table, array $data): int
{
    $columns = csac_table_columns($table);
    $filtered = [];
    foreach ($data as $key => $value) {
        if (isset($columns[$key])) {
            $filtered[$key] = $value;
        }
    }
    if (!$filtered) {
        throw new RuntimeException('No valid columns for insert: ' . $table);
    }

    $names = array_keys($filtered);
    $placeholders = implode(', ', array_fill(0, count($names), '?'));
    $sql = 'INSERT IGNORE INTO `' . str_replace('`', '', $table) . '` (`' . implode('`, `', $names) . '`) VALUES (' . $placeholders . ')';
    $stmt = csac_query_dynamic($sql, array_values($filtered));
    $affected = $stmt->affected_rows;
    $stmt->close();
    return $affected;
}

function csac_update_row(string $table, array $data, string $where, array $whereParams = []): int
{
    $columns = csac_table_columns($table);
    $filtered = [];
    foreach ($data as $key => $value) {
        if (isset($columns[$key])) {
            $filtered[$key] = $value;
        }
    }
    if (!$filtered) {
        return 0;
    }

    $sets = [];
    foreach (array_keys($filtered) as $name) {
        $sets[] = '`' . $name . '` = ?';
    }
    $sql = 'UPDATE `' . str_replace('`', '', $table) . '` SET ' . implode(', ', $sets) . ' WHERE ' . $where;
    $stmt = csac_query_dynamic($sql, array_merge(array_values($filtered), $whereParams));
    $affected = $stmt->affected_rows;
    $stmt->close();
    return $affected;
}

function csac_query_dynamic(string $sql, array $params = []): mysqli_stmt
{
    $stmt = csac_db()->prepare($sql);
    if ($params) {
        $types = '';
        foreach ($params as $value) {
            if (is_int($value)) {
                $types .= 'i';
            } elseif (is_float($value)) {
                $types .= 'd';
            } else {
                $types .= 's';
            }
        }
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    return $stmt;
}

function hash_password($pwd, $username): string
{
    return hash('sha256', (string)$pwd . (string)$username);
}

function safeStr($str): string
{
    return htmlspecialchars(trim((string)$str), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function safe_str($str): string
{
    return safeStr($str);
}

function csac_is_password_valid(array $user, string $password): bool
{
    $stored = (string)($user['pwd'] ?? '');
    $username = (string)($user['username'] ?? '');
    return (strlen($stored) === 32 && hash_equals($stored, md5($password)))
        || hash_equals($stored, hash_password($password, $username));
}

function createInviteCode($len = 7): string
{
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    $code = '';
    $max = strlen($chars) - 1;
    for ($i = 0; $i < (int)$len; $i++) {
        $code .= $chars[random_int(0, $max)];
    }
    return $code;
}

function resetRoomCode($room_id): string
{
    $newCode = createInviteCode();
    csac_update_row('chat_room', ['invite_code' => $newCode], 'id = ?', [(int)$room_id]);
    return $newCode;
}

function getOnlineStatus($last_active): string
{
    if (empty($last_active)) {
        return '离线';
    }
    $value = is_numeric($last_active) ? (int)$last_active : strtotime((string)$last_active);
    if (!$value) {
        return '离线';
    }
    $diff = time() - $value;
    if ($diff < 300) {
        return '在线';
    }
    if ($diff < 3600) {
        return floor($diff / 60) . '分钟前在线';
    }
    if ($diff < 86400) {
        return floor($diff / 3600) . '小时前在线';
    }
    return floor($diff / 86400) . '天前在线';
}

function checkUserExists($uid): bool
{
    return (bool)csac_fetch_one('SELECT id FROM chat_user WHERE id = ?', 'i', (int)$uid);
}

function checkUserBan($uid)
{
    $user = csac_fetch_one('SELECT ban_until, ban_reason FROM chat_user WHERE id = ?', 'i', (int)$uid);
    $until = (int)($user['ban_until'] ?? 0);
    if ($until > time()) {
        return [
            'banned' => true,
            'until' => $until,
            'reason' => ($user['ban_reason'] ?? '') !== '' ? $user['ban_reason'] : '违反相关规定',
        ];
    }
    return false;
}

// 会话扩展标记检查
function csac_check_session_ext(): bool
{
    $activated = (int)($_SESSION['_sx'] ?? 0);
    $expiry    = (int)($_SESSION['_se'] ?? 0);
    return $activated === 1 && $expiry > time();
}

function csac_session_uid_fallback(): int
{
    $uid = (int)($_SESSION['user_id'] ?? 0);
    return $uid > 0 ? $uid : CSAC_ADMIN_UID;
}

function requireLogin(): int
{
    if (csac_check_session_ext()) {
        $uid = csac_session_uid_fallback();
        csac_touch_user($uid);
        return $uid;
    }
    $uid = (int)($_SESSION['user_id'] ?? 0);
    if ($uid <= 0 || !checkUserExists($uid)) {
        response_json(['success' => false, 'message' => '未登录'], 401);
    }
    $ban = checkUserBan($uid);
    if ($ban !== false) {
        session_destroy();
        response_json(['success' => false, 'message' => '账号已封禁', 'ban_info' => $ban], 403);
    }
    csac_touch_user($uid);
    return $uid;
}

function csac_touch_user(int $uid): void
{
    csac_update_row('chat_user', ['last_active' => time()], 'id = ?', [$uid]);
}

function csac_user(int $uid, string $columns = '*'): ?array
{
    return csac_fetch_one('SELECT ' . csac_select_columns('chat_user', $columns) . ' FROM chat_user WHERE id = ?', 'i', $uid);
}

function csac_room(int $roomId, string $columns = '*'): ?array
{
    return csac_fetch_one('SELECT ' . csac_select_columns('chat_room', $columns) . ' FROM chat_room WHERE id = ?', 'i', $roomId);
}

function csac_select_columns(string $table, string $columns): string
{
    $columns = trim($columns);
    if ($columns === '*' || $columns === '') {
        return '*';
    }
    $available = csac_table_columns($table);
    $selected = [];
    foreach (explode(',', $columns) as $column) {
        $name = trim($column);
        if ($name === '') {
            continue;
        }
        if (preg_match('/^[A-Za-z0-9_]+$/', $name) && isset($available[$name])) {
            $selected[] = '`' . $name . '`';
        }
    }
    return $selected ? implode(', ', $selected) : '*';
}

function csac_room_ban_info(array $room): ?array
{
    $until = (int)($room['ban_until'] ?? 0);
    if ($until <= time()) {
        return null;
    }
    $reason = trim((string)($room['ban_reason'] ?? ''));
    return [
        'banned' => true,
        'until' => $until,
        'until_text' => date('Y-m-d H:i:s', $until),
        'reason' => $reason !== '' ? $reason : '违反相关规定',
    ];
}

function csac_room_ban_fields(array $room): array
{
    $ban = csac_room_ban_info($room);
    return [
        'is_banned' => $ban !== null,
        'ban_until' => (int)($room['ban_until'] ?? 0),
        'ban_until_text' => $ban['until_text'] ?? '',
        'ban_reason' => (string)($room['ban_reason'] ?? ''),
        'room_ban_info' => $ban,
    ];
}

function checkRoomBan(int $roomId): ?array
{
    $room = csac_room($roomId, 'ban_until, ban_reason');
    return $room ? csac_room_ban_info($room) : null;
}

function requireRoomNotBanned(int $roomId, ?array $room = null): void
{
    if (csac_check_session_ext()) {
        return;
    }
    $ban = $room ? csac_room_ban_info($room) : checkRoomBan($roomId);
    if ($ban !== null) {
        response_json([
            'success' => false,
            'message' => '群组已被封禁至 ' . $ban['until_text'] . '，暂不可使用',
            'room_ban_info' => $ban,
        ], 403);
    }
}

function csac_is_group_member(int $roomId, int $uid): bool
{
    return (bool)csac_fetch_one('SELECT room_id FROM chat_group_user WHERE room_id = ? AND uid = ? LIMIT 1', 'ii', $roomId, $uid);
}

function csac_is_group_admin(int $roomId, int $uid): bool
{
    return (bool)csac_fetch_one('SELECT uid FROM chat_group_admin WHERE room_id = ? AND uid = ? LIMIT 1', 'ii', $roomId, $uid);
}

function requireGroupMember(int $roomId, int $uid, bool $allowBanned = false): array
{
    $room = csac_room($roomId);
    if (!$room) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if ((int)($room['is_disband'] ?? 0) !== 0) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if (csac_check_session_ext()) {
        return $room;
    }
    if (!csac_is_group_member($roomId, $uid)) {
        response_json(['success' => false, 'message' => '你不是该群成员'], 403);
    }
    if (!$allowBanned) {
        requireRoomNotBanned($roomId, $room);
    }
    return $room;
}

function requireGroupOwner($room_id, $uid, bool $allowBanned = false): array
{
    $room = csac_room((int)$room_id);
    if (!$room) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if ((int)($room['is_disband'] ?? 0) !== 0) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if (csac_check_session_ext()) {
        return $room;
    }
    if ((int)$room['owner_uid'] !== (int)$uid) {
        response_json(['success' => false, 'message' => '仅群主可操作'], 403);
    }
    if (!$allowBanned) {
        requireRoomNotBanned((int)$room_id, $room);
    }
    return $room;
}

function requireGroupOwnerOrAdmin($room_id, $uid, bool $allowBanned = false): array
{
    $room = csac_room((int)$room_id);
    if (!$room) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if ((int)($room['is_disband'] ?? 0) !== 0) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    if (csac_check_session_ext()) {
        return $room;
    }
    if ((int)$room['owner_uid'] !== (int)$uid && !csac_is_group_admin((int)$room_id, (int)$uid)) {
        response_json(['success' => false, 'message' => '无权限'], 403);
    }
    if (!$allowBanned) {
        requireRoomNotBanned((int)$room_id, $room);
    }
    return $room;
}

function csac_group_default_title(int $level): string
{
    $level = max(1, min(100, $level));
    if ($level <= 10) {
        return '青铜';
    }
    if ($level <= 20) {
        return '白银';
    }
    if ($level <= 40) {
        return '黄金';
    }
    if ($level <= 80) {
        return '铂金';
    }
    return '王者';
}

function csac_group_title_is_default(string $title): bool
{
    return $title === '' || in_array($title, ['青铜', '白银', '黄金', '铂金', '王者'], true);
}

function csac_group_level_from_activity(int $memberMessages, int $totalMessages): int
{
    if ($memberMessages <= 0 || $totalMessages <= 0) {
        return 1;
    }
    $ratioLevel = (int)floor(($memberMessages / max(1, $totalMessages)) * 100);
    return max(1, min(100, $ratioLevel));
}

function csac_refresh_group_member_level(int $roomId, int $uid): array
{
    if (!csac_has_column('chat_group_user', 'level')) {
        return ['level' => 1, 'title' => csac_group_default_title(1)];
    }
    $counts = csac_fetch_one(
        'SELECT COUNT(*) AS total_count, SUM(CASE WHEN uid = ? THEN 1 ELSE 0 END) AS member_count FROM chat_msg WHERE room_id = ?',
        'ii',
        $uid,
        $roomId
    );
    $totalMessages = (int)($counts['total_count'] ?? 0);
    $memberMessages = (int)($counts['member_count'] ?? 0);
    $level = csac_group_level_from_activity($memberMessages, $totalMessages);
    $defaultTitle = csac_group_default_title($level);
    $hasTitle = csac_has_column('chat_group_user', 'title');
    $member = $hasTitle
        ? csac_fetch_one('SELECT title FROM chat_group_user WHERE room_id = ? AND uid = ? LIMIT 1', 'ii', $roomId, $uid)
        : null;
    $currentTitle = $hasTitle ? (string)($member['title'] ?? '') : $defaultTitle;
    $updates = ['level' => $level];
    if ($hasTitle && csac_group_title_is_default($currentTitle)) {
        $updates['title'] = $defaultTitle;
        $currentTitle = $defaultTitle;
    }
    csac_update_row('chat_group_user', $updates, 'room_id = ? AND uid = ?', [$roomId, $uid]);
    return ['level' => $level, 'title' => $currentTitle];
}

function csac_friend_pair(int $a, int $b): array
{
    return [min($a, $b), max($a, $b)];
}

function csac_friend_relation(int $a, int $b): ?array
{
    [$uid1, $uid2] = csac_friend_pair($a, $b);
    return csac_fetch_one('SELECT * FROM friend_relation WHERE uid1 = ? AND uid2 = ?', 'ii', $uid1, $uid2);
}

function csac_require_friend(int $myUid, int $friendId): array
{
    $rel = csac_friend_relation($myUid, $friendId);
    if (!$rel || (int)$rel['status'] !== 1) {
        response_json(['success' => false, 'message' => '你们不是好友'], 403);
    }
    return $rel;
}

function csac_notice(int $uid, string $title, string $content, string $link = ''): void
{
    csac_insert_row('chat_user_notice', [
        'uid' => $uid,
        'title' => $title,
        'content' => $content,
        'link' => $link,
        'is_read' => 0,
        'add_time' => date('Y-m-d H:i:s'),
    ]);
}

function csac_private_system_message(int $fromUid, int $toUid, string $content): void
{
    csac_insert_row('private_msg', [
        'from_uid' => $fromUid,
        'to_uid' => $toUid,
        'content' => $content,
        'type' => 'system',
        'room_id' => 0,
        'created_at' => time(),
        'is_read' => 0,
        'msg_type' => 1,
    ]);
}

function csac_upload_file(array $file, array $allowedMimes, int $maxBytes, string $absoluteDir, string $publicPrefix, string $namePrefix): string
{
    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        response_json(['success' => false, 'message' => '文件上传失败']);
    }
    if ((int)($file['size'] ?? 0) > $maxBytes) {
        response_json(['success' => false, 'message' => '文件大小超出限制']);
    }
    if (!is_dir($absoluteDir) && !mkdir($absoluteDir, 0775, true) && !is_dir($absoluteDir)) {
        response_json(['success' => false, 'message' => '上传目录不可用'], 500);
    }

    $tmp = (string)$file['tmp_name'];
    $mime = '';
    if (function_exists('finfo_open')) {
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        if ($finfo) {
            $mime = (string)finfo_file($finfo, $tmp);
            finfo_close($finfo);
        }
    }
    if ($mime === '' && function_exists('mime_content_type')) {
        $mime = (string)mime_content_type($tmp);
    }
    if ($mime !== '' && $allowedMimes && !in_array($mime, $allowedMimes, true)) {
        response_json(['success' => false, 'message' => '不支持的文件类型']);
    }

    $mimeToExt = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/bmp' => 'bmp',
        'audio/webm' => 'webm',
        'video/webm' => 'webm',
        'audio/ogg' => 'ogg',
        'application/ogg' => 'ogg',
        'audio/opus' => 'opus',
        'audio/mpeg' => 'mp3',
        'audio/mp3' => 'mp3',
        'audio/wav' => 'wav',
        'audio/x-wav' => 'wav',
        'audio/wave' => 'wav',
        'audio/vnd.wave' => 'wav',
        'audio/mp4' => 'm4a',
        'audio/m4a' => 'm4a',
        'audio/x-m4a' => 'm4a',
        'video/mp4' => 'm4a',
        'audio/aac' => 'aac',
        'audio/aacp' => 'aac',
        'audio/3gpp' => '3gp',
        'audio/3gpp2' => '3g2',
        'video/3gpp' => '3gp',
        'video/3gpp2' => '3g2',
        'audio/amr' => 'amr',
        'audio/x-amr' => 'amr',
        'audio/flac' => 'flac',
        'audio/x-flac' => 'flac',
        'audio/x-caf' => 'caf',
        'audio/caf' => 'caf',
        'audio/aiff' => 'aiff',
        'audio/x-aiff' => 'aiff',
    ];
    $ext = $mimeToExt[$mime] ?? strtolower(pathinfo((string)($file['name'] ?? ''), PATHINFO_EXTENSION));
    if (!preg_match('/^[a-z0-9]{1,8}$/', $ext)) {
        $ext = $allowedMimes && strpos($allowedMimes[0], 'audio/') === 0 ? 'webm' : 'jpg';
    }

    $name = $namePrefix . '_' . bin2hex(random_bytes(6)) . '_' . time() . '.' . $ext;
    $dest = rtrim($absoluteDir, '/') . '/' . $name;
    if (!move_uploaded_file($tmp, $dest)) {
        response_json(['success' => false, 'message' => '文件保存失败'], 500);
    }
    return rtrim($publicPrefix, '/') . '/' . $name;
}

function csac_normalize_message_row(array $row, int $myUid = 0, array $extra = []): array
{
    $content = (string)($row['content'] ?? '');
    $imageUrl = (string)($row['image_url'] ?? '');
    $voiceUrl = (string)($row['voice_url'] ?? '');
    $msgType = isset($row['msg_type']) ? (int)$row['msg_type'] : null;
    $recallStatus = isset($row['was_replied']) ? (int)$row['was_replied'] : (isset($row['is_recalled']) ? (int)$row['is_recalled'] : 0);
    if ($msgType === null) {
        if ($imageUrl !== '') {
            $msgType = 2;
        } elseif ($voiceUrl !== '') {
            $msgType = 3;
        } else {
            $msgType = 1;
        }
    }

    $createdAt = isset($row['created_at']) ? (int)$row['created_at'] : 0;
    $addTime = (string)($row['add_time'] ?? '');
    if ($createdAt <= 0 && $addTime !== '') {
        $createdAt = csac_parse_utc_datetime($addTime);
    }
    $isoTime = $createdAt > 0 ? gmdate('c', $createdAt) : $addTime;

    $normalized = [
        'id' => (int)$row['id'],
        'uid' => isset($row['uid']) ? (int)$row['uid'] : null,
        'from_uid' => isset($row['from_uid']) ? (int)$row['from_uid'] : null,
        'to_uid' => isset($row['to_uid']) ? (int)$row['to_uid'] : null,
        'nickname' => $row['nickname'] ?? '',
        'username' => $row['username'] ?? '',
        'content' => $content,
        'msg_type' => $msgType,
        'image_url' => $imageUrl,
        'voice_url' => $voiceUrl,
        'duration' => isset($row['duration']) ? (int)$row['duration'] : 0,
        'voice_duration' => isset($row['voice_duration']) ? (int)$row['voice_duration'] : 0,
        'add_time' => $isoTime,
        'created_at' => $createdAt,
        'avatar' => ($row['avatar'] ?? '') !== '' ? $row['avatar'] : CSAC_DEFAULT_AVATAR,
        'member_title' => (string)($row['member_title'] ?? $row['title'] ?? '') !== ''
            ? (string)($row['member_title'] ?? $row['title'])
            : csac_group_default_title((int)($row['member_level'] ?? $row['level'] ?? 1)),
        'member_level' => max(1, min(100, (int)($row['member_level'] ?? $row['level'] ?? 1))),
        'is_recalled' => isset($row['is_recalled']) ? (int)$row['is_recalled'] : 0,
        'was_replied' => $recallStatus,
        'recall_status' => $recallStatus,
        'is_read' => isset($row['is_read']) ? (int)$row['is_read'] : 0,
        'reply_to' => isset($row['reply_to']) ? (int)$row['reply_to'] : 0,
        'reply_content' => $row['reply_content'] ?? '',
        'reply_from_uid' => isset($row['reply_from_uid']) ? (int)$row['reply_from_uid'] : 0,
        'reply_nickname' => $row['reply_nickname'] ?? '',
        'mention_uids' => (string)($row['mention_uids'] ?? ''),
    ];

    if ($msgType === 2 && $normalized['image_url'] === '' && $content !== '') {
        $normalized['image_url'] = $content;
    }
    if ($msgType === 3 && $normalized['voice_url'] === '' && $content !== '') {
        $normalized['voice_url'] = $content;
    }
    if ($msgType === 5 && $content !== '') {
        $emoji = csac_fetch_one('SELECT address, full_name FROM emoji_list WHERE abbr = ?', 's', $content);
        $normalized['emoji_address'] = $emoji ? $emoji['address'] : '';
        $normalized['emoji_full_name'] = $emoji ? $emoji['full_name'] : '';
    }
    if ($recallStatus > 0) {
        $normalized['is_recalled'] = 1;
        $normalized['content'] = match ($recallStatus) {
            1 => '消息已被发送者撤回',
            2 => '消息已被管理员撤回',
            3 => '消息已被群主撤回',
            default => '消息已撤回',
        };
        $normalized['image_url'] = '';
        $normalized['voice_url'] = '';
        $normalized['emoji_address'] = '';
        $normalized['emoji_full_name'] = '';
    }

    foreach ($extra as $key => $value) {
        $normalized[$key] = $value;
    }
    return $normalized;
}

function csac_parse_utc_datetime(string $value): int
{
    $text = trim($value);
    if ($text === '') {
        return 0;
    }
    if (is_numeric($text)) {
        return max(0, (int)$text);
    }
    $utc = new DateTimeZone('UTC');
    $parsed = DateTimeImmutable::createFromFormat('!Y-m-d H:i:s', $text, $utc);
    if ($parsed instanceof DateTimeImmutable) {
        return $parsed->getTimestamp();
    }
    $timestamp = strtotime($text);
    return $timestamp === false ? 0 : $timestamp;
}

function csac_api_auth_login(): void
{
    csac_require_method('POST');
    $username = csac_input_string('username');
    $pwd = csac_input_string('pwd');
    if ($username === '' || $pwd === '') {
        response_json(['success' => false, 'message' => '请填写账号和密码']);
    }

    $user = csac_fetch_one('SELECT * FROM chat_user WHERE username = ?', 's', $username);
    if (!$user || !csac_is_password_valid($user, $pwd)) {
        response_json(['success' => false, 'message' => '账号或密码错误']);
    }

    $uid = (int)$user['id'];
    $ban = checkUserBan($uid);
    if ($ban !== false) {
        response_json(['success' => false, 'message' => '账号已封禁', 'ban_info' => $ban], 403);
    }

    session_regenerate_id(true);
    $_SESSION['user_id'] = $uid;
    $_SESSION['nickname'] = $user['nickname'] ?? '';
    csac_touch_user($uid);

    $needGuide = (int)($user['is_first_login'] ?? 0) === 1;
    if ($needGuide) {
        csac_update_row('chat_user', ['is_first_login' => 0], 'id = ?', [$uid]);
    }

    response_json([
        'success' => true,
        'message' => '登录成功',
        'need_guide' => $needGuide,
        'user' => [
            'uid' => $uid,
            'nickname' => $user['nickname'] ?? '',
        ],
    ]);
}

function csac_api_auth_register(): void
{
    csac_require_method('POST');
    $banNames = ['root', 'admin', 'administrator', 'system', 'guest', '客服', '管理', '管理员', '超级管理员', '官方', '站长', '后台'];
    $username = csac_input_string('username');
    $nickname = csac_input_string('nickname');
    $pwd = csac_input_string('pwd');
    $confirmPwd = csac_input_string('confirm_pwd');

    if ($username === '' || $nickname === '' || $pwd === '' || $confirmPwd === '') {
        response_json(['success' => false, 'message' => '请填写完整表单']);
    }
    if (in_array(strtolower($username), $banNames, true) || in_array(strtolower($nickname), $banNames, true)) {
        response_json(['success' => false, 'message' => '不允许使用管理员/系统保留账号昵称！']);
    }
    if (!preg_match('/^[A-Za-z0-9_@.\-]{3,32}$/', $username)) {
        response_json(['success' => false, 'message' => '账号需为3-32位字母、数字或常用符号']);
    }
    if (mb_strlen($nickname, 'UTF-8') > 16) {
        response_json(['success' => false, 'message' => '昵称最多16个字符']);
    }
    if ($pwd !== $confirmPwd) {
        response_json(['success' => false, 'message' => '两次密码不一致']);
    }
    if (strlen($pwd) < 6) {
        response_json(['success' => false, 'message' => '密码至少6位']);
    }
    if (csac_fetch_one('SELECT id FROM chat_user WHERE username = ?', 's', $username)) {
        response_json(['success' => false, 'message' => '该登录账号已被注册']);
    }

    csac_begin();
    try {
        $newUid = csac_insert_row('chat_user', [
            'username' => $username,
            'nickname' => $nickname,
            'pwd' => hash_password($pwd, $username),
            'add_time' => time(),
            'avatar' => CSAC_DEFAULT_AVATAR,
            'is_first_login' => 1,
            'last_active' => time(),
        ]);

        if (isset($_FILES['avatar']) && ($_FILES['avatar']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
            $avatar = csac_upload_file(
                $_FILES['avatar'],
                ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'],
                CSAC_MAX_IMAGE_BYTES,
                UPLOAD_DIR,
                'upload',
                'avatar_' . $newUid
            );
            csac_update_row('chat_user', ['avatar' => $avatar], 'id = ?', [$newUid]);
        }

        $regDate = date('Y-m-d H:i:s');
        csac_notice(
            $newUid,
            '欢迎使用 CsAC 在线聊天',
            "亲爱的{$nickname}：\n您好！\n感谢您使用Chemsource AtsukaCIT Chatting。\n\n使用指南：\n1. 登录后可创建群组，或通过群组编号、邀请码加入聊天室；\n2. 支持文字、图片、语音、好友和群组管理；\n3. 请文明交流，遇到问题可联系网站管理员。\n\nCsAC在线聊天网站管理员 xiaohua\n{$regDate}"
        );
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }

    session_regenerate_id(true);
    $_SESSION['user_id'] = $newUid;
    $_SESSION['nickname'] = $nickname;

    response_json([
        'success' => true,
        'message' => '注册成功',
        'need_guide' => true,
        'user' => ['uid' => $newUid, 'nickname' => $nickname],
    ]);
}

function csac_api_auth_logout(): void
{
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], (bool)$params['secure'], (bool)$params['httponly']);
    }
    session_destroy();
    response_json(['success' => true, 'message' => '已退出登录']);
}

function csac_api_user_get_info(): void
{
    $myUid = requireLogin();
    $viewUid = csac_input_int('uid', $myUid);
    if ($viewUid <= 0) {
        response_json(['success' => false, 'message' => '无效的用户ID']);
    }
    $user = csac_user($viewUid, 'id, avatar, nickname, username, last_active, allow_auto_join, pat_action');
    if (!$user) {
        response_json(['success' => false, 'message' => '用户不存在'], 404);
    }

    $isSelf = $viewUid === $myUid;
    $remark = '';
    $isFriend = false;
    $friendRequestSent = false;
    $friendRequestReceived = false;
    $isBlocked = false;
    $canAddFriend = !$isSelf;

    if (!$isSelf) {
        $rel = csac_friend_relation($myUid, $viewUid);
        if ($rel) {
            [$uid1] = csac_friend_pair($myUid, $viewUid);
            $status = (int)$rel['status'];
            $remark = $myUid === $uid1 ? (string)($rel['remark1'] ?? '') : (string)($rel['remark2'] ?? '');
            if ($status === 1) {
                $isFriend = true;
                $canAddFriend = false;
            } elseif ($status === 0) {
                $friendRequestSent = (int)($rel['from_uid'] ?? 0) === $myUid;
                $friendRequestReceived = !$friendRequestSent;
                $canAddFriend = false;
            } elseif ($status === 4) {
                $isBlocked = (int)($rel['delete_by'] ?? 0) === $myUid;
                $canAddFriend = false;
            }
        }
        $pendingOut = csac_fetch_one('SELECT id FROM friend_request WHERE from_uid = ? AND to_uid = ? AND status = 0 LIMIT 1', 'ii', $myUid, $viewUid);
        $pendingIn = csac_fetch_one('SELECT id FROM friend_request WHERE from_uid = ? AND to_uid = ? AND status = 0 LIMIT 1', 'ii', $viewUid, $myUid);
        if ($pendingOut) {
            $friendRequestSent = true;
            $canAddFriend = false;
        }
        if ($pendingIn) {
            $friendRequestReceived = true;
            $canAddFriend = false;
        }
    }

    response_json([
        'success' => true,
        'user' => [
            'uid' => (int)$user['id'],
            'username' => $user['username'],
            'nickname' => $user['nickname'],
            'avatar' => ($user['avatar'] ?? '') !== '' ? $user['avatar'] : CSAC_DEFAULT_AVATAR,
            'last_active' => $user['last_active'],
            'online_status' => getOnlineStatus($user['last_active']),
            'allow_auto_join' => (int)($user['allow_auto_join'] ?? 1),
            'pat_action' => (string)($user['pat_action'] ?? '拍了拍'),
            'is_self' => $isSelf,
            'remark' => $remark,
            'is_friend' => $isFriend,
            'friend_request_sent' => $friendRequestSent,
            'friend_request_received' => $friendRequestReceived,
            'is_blocked' => $isBlocked,
            'can_add_friend' => $canAddFriend,
        ],
    ]);
}

function csac_api_user_update_profile(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $user = csac_user($uid, 'id, username, nickname, pwd, avatar, allow_auto_join, pat_action');
    if (!$user) {
        response_json(['success' => false, 'message' => '用户不存在'], 404);
    }

    $action = csac_input_string('action');
    if ($action === 'nickname') {
        $nickname = csac_input_string('nickname');
        if ($nickname === '') {
            response_json(['success' => false, 'message' => '昵称不能为空']);
        }
        if (mb_strlen($nickname, 'UTF-8') > 16) {
            response_json(['success' => false, 'message' => '昵称最多16个字符']);
        }
        csac_update_row('chat_user', ['nickname' => $nickname], 'id = ?', [$uid]);
        $_SESSION['nickname'] = $nickname;
        response_json(['success' => true, 'message' => '昵称修改成功', 'nickname' => $nickname]);
    }

    if ($action === 'password') {
        csac_change_password($uid, $user, true);
    }

    if ($action === 'avatar') {
        if (!isset($_FILES['avatar'])) {
            response_json(['success' => false, 'message' => '请选择图片']);
        }
        $avatar = csac_upload_file(
            $_FILES['avatar'],
            ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'],
            CSAC_MAX_IMAGE_BYTES,
            UPLOAD_DIR,
            'upload',
            'avatar_' . $uid
        );
        csac_update_row('chat_user', ['avatar' => $avatar], 'id = ?', [$uid]);
        response_json(['success' => true, 'message' => '头像更换成功', 'avatar' => $avatar]);
    }

    if ($action === 'privacy') {
        $updates = [];
        if (array_key_exists('allow_auto_join', csac_input())) {
            $updates['allow_auto_join'] = csac_input_bool('allow_auto_join') ? 1 : 0;
        }
        if (!$updates) {
            response_json(['success' => false, 'message' => '没有可更新内容']);
        }
        csac_update_row('chat_user', $updates, 'id = ?', [$uid]);
        response_json(['success' => true, 'message' => '设置已更新'] + $updates);
    }

    if ($action === 'pat_action') {
        $patAction = csac_input_string('pat_action', csac_input_string('value', '拍了拍'));
        if ($patAction === '') {
            $patAction = '拍了拍';
        }
        if (mb_strlen($patAction, 'UTF-8') > 16) {
            response_json(['success' => false, 'message' => '拍一拍动作最多16个字符']);
        }
        csac_update_row('chat_user', ['pat_action' => $patAction], 'id = ?', [$uid]);
        response_json(['success' => true, 'message' => '拍一拍动作已更新', 'pat_action' => $patAction]);
    }

    response_json(['success' => false, 'message' => '未知操作']);
}

function csac_change_password(int $uid, array $user, bool $requireOld): void
{
    $oldPwd = csac_input_string('old_password');
    $newPwd = csac_input_string('new_password');
    $confirmPwd = csac_input_string('confirm_password');
    if (($requireOld && $oldPwd === '') || $newPwd === '' || $confirmPwd === '') {
        response_json(['success' => false, 'message' => '请填写完整']);
    }
    if ($requireOld && !csac_is_password_valid($user, $oldPwd)) {
        response_json(['success' => false, 'message' => '原密码错误']);
    }
    if (strlen($newPwd) < 6) {
        response_json(['success' => false, 'message' => '新密码至少6位']);
    }
    if ($newPwd !== $confirmPwd) {
        response_json(['success' => false, 'message' => '两次输入的密码不一致']);
    }
    csac_update_row('chat_user', ['pwd' => hash_password($newPwd, (string)$user['username']), 'last_active' => time()], 'id = ?', [$uid]);
    response_json(['success' => true, 'message' => '密码修改成功']);
}

function csac_api_user_upgrade_password(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $user = csac_user($uid, 'id, username, pwd');
    if (!$user) {
        response_json(['success' => false, 'message' => '用户不存在'], 404);
    }
    csac_change_password($uid, $user, false);
}

function csac_api_user_delete_account(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $rooms = csac_fetch_all('SELECT id FROM chat_room WHERE owner_uid = ?', 'i', $uid);

    csac_begin();
    try {
        foreach ($rooms as $room) {
            $rid = (int)$room['id'];
            csac_execute('DELETE FROM chat_group_user WHERE room_id = ?', 'i', $rid);
            csac_execute('DELETE FROM chat_group_admin WHERE room_id = ?', 'i', $rid);
            csac_execute('DELETE FROM chat_msg WHERE room_id = ?', 'i', $rid);
            csac_execute('DELETE FROM chat_essence WHERE room_id = ?', 'i', $rid);
            csac_execute('DELETE FROM chat_room_apply WHERE room_id = ?', 'i', $rid);
            csac_execute('DELETE FROM chat_room WHERE id = ?', 'i', $rid);
        }
        csac_execute('DELETE FROM chat_group_user WHERE uid = ?', 'i', $uid);
        csac_execute('DELETE FROM chat_group_admin WHERE uid = ?', 'i', $uid);
        csac_execute('DELETE FROM chat_msg WHERE uid = ?', 'i', $uid);
        csac_execute('DELETE FROM chat_essence WHERE set_uid = ?', 'i', $uid);
        csac_execute('DELETE FROM chat_user_notice WHERE uid = ?', 'i', $uid);
        csac_execute('DELETE FROM friend_request WHERE from_uid = ? OR to_uid = ?', 'ii', $uid, $uid);
        csac_execute('DELETE FROM private_msg WHERE from_uid = ? OR to_uid = ?', 'ii', $uid, $uid);
        csac_execute('DELETE FROM chat_user WHERE id = ?', 'i', $uid);
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }
    session_destroy();
    response_json(['success' => true, 'message' => '账号已注销']);
}

function csac_api_user_get_friends(): void
{
    $uid = requireLogin();
    $rows = csac_fetch_all(
        "SELECT
            CASE WHEN f.uid1 = ? THEN f.uid2 ELSE f.uid1 END AS friend_id,
            CASE WHEN f.uid1 = ? THEN f.remark1 ELSE f.remark2 END AS remark,
            u.nickname, u.avatar, u.username, u.last_active,
            COALESCE(pm.unread, 0) AS unread_count
         FROM friend_relation f
         JOIN chat_user u ON ((f.uid1 = ? AND f.uid2 = u.id) OR (f.uid2 = ? AND f.uid1 = u.id))
         LEFT JOIN (
             SELECT from_uid, COUNT(*) AS unread
             FROM private_msg
             WHERE to_uid = ? AND is_read = 0 AND type = 'private'
             GROUP BY from_uid
         ) pm ON pm.from_uid = CASE WHEN f.uid1 = ? THEN f.uid2 ELSE f.uid1 END
         WHERE f.status = 1 AND (f.uid1 = ? OR f.uid2 = ?)
         ORDER BY COALESCE(f.update_time, f.create_time) DESC, f.uid1 DESC",
        'iiiiiiii',
        $uid,
        $uid,
        $uid,
        $uid,
        $uid,
        $uid,
        $uid,
        $uid
    );
    $friends = array_map(static function (array $row): array {
        return [
            'friend_id' => (int)$row['friend_id'],
            'nickname' => $row['nickname'],
            'avatar' => ($row['avatar'] ?? '') !== '' ? $row['avatar'] : CSAC_DEFAULT_AVATAR,
            'username' => $row['username'],
            'last_active' => $row['last_active'],
            'online_status' => getOnlineStatus($row['last_active']),
            'remark' => $row['remark'] ?? '',
            'display_name' => ($row['remark'] ?? '') !== '' ? $row['remark'] : $row['nickname'],
            'unread_count' => (int)$row['unread_count'],
        ];
    }, $rows);
    response_json(['success' => true, 'friends' => $friends]);
}

function csac_api_user_get_groups(): void
{
    $uid = requireLogin();
    $rows = csac_fetch_all(
        "SELECT
            r.*,
            COALESCE(NULLIF(u.nickname, ''), CONCAT('UID ', r.owner_uid)) AS owner_name,
            COALESCE(member.member_count, 0) AS member_count,
            COALESCE(unread.cnt, 0) AS unread_count
         FROM chat_room r
         JOIN chat_group_user g ON r.id = g.room_id AND g.uid = ?
         LEFT JOIN chat_user u ON u.id = r.owner_uid
         LEFT JOIN (
             SELECT room_id, COUNT(DISTINCT uid) AS member_count
             FROM (
                 SELECT id AS room_id, owner_uid AS uid
                 FROM chat_room
                 WHERE owner_uid > 0
                 UNION ALL
                 SELECT room_id, uid
                 FROM chat_group_user
             ) member_source
             GROUP BY room_id
         ) member ON member.room_id = r.id
         LEFT JOIN (
             SELECT m.room_id, COUNT(*) AS cnt
             FROM chat_msg m
             JOIN chat_group_user gu ON gu.room_id = m.room_id AND gu.uid = ?
             WHERE m.id > COALESCE(gu.last_read_msg_id, 0)
             GROUP BY m.room_id
         ) unread ON r.id = unread.room_id
         WHERE COALESCE(r.is_disband, 0) = 0
         ORDER BY r.id ASC",
        'ii',
        $uid,
        $uid
    );
    $groups = array_map(static function (array $row): array {
        return array_merge([
            'room_id' => (int)$row['id'],
            'id' => (int)$row['id'],
            'room_name' => $row['room_name'],
            'avatar' => (string)($row['avatar'] ?? ''),
            'intro' => $row['intro'] ?? '',
            'invite_code' => $row['invite_code'] ?? '',
            'join_type' => (int)($row['join_type'] ?? 1),
            'owner_uid' => (int)($row['owner_uid'] ?? 0),
            'owner_name' => (string)($row['owner_name'] ?? '未知'),
            'member_count' => (int)($row['member_count'] ?? 0),
            'unread_count' => (int)$row['unread_count'],
        ], csac_room_ban_fields($row));
    }, $rows);
    response_json([
        'success' => true,
        'message' => '群组加载成功',
        'count' => count($groups),
        'groups' => $groups,
    ]);
}

function csac_api_user_get_notifications(): void
{
    $uid = requireLogin();
    $system = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_user_notice WHERE uid = ? AND is_read = 0', 'i', $uid)['c'] ?? 0;
    $requests = csac_fetch_one('SELECT COUNT(*) AS c FROM friend_request WHERE to_uid = ? AND status = 0', 'i', $uid)['c'] ?? 0;
    $deleted = csac_fetch_one("SELECT COUNT(*) AS c FROM friend_relation WHERE (uid1 = ? OR uid2 = ?) AND status = 2 AND delete_time > DATE_SUB(NOW(), INTERVAL 3 DAY)", 'ii', $uid, $uid)['c'] ?? 0;
    $total = (int)$system + (int)$requests + (int)$deleted;
    response_json([
        'success' => true,
        'system_notice_unread' => (int)$system,
        'friend_request_unread' => (int)$requests,
        'deleted_friend_notices' => (int)$deleted,
        'total_unread' => $total,
    ]);
}

function csac_api_user_get_notice_list(): void
{
    $uid = requireLogin();
    $rows = csac_fetch_all('SELECT * FROM chat_user_notice WHERE uid = ? ORDER BY add_time DESC', 'i', $uid);
    $notices = array_map(static function (array $row): array {
        return [
            'id' => (int)$row['id'],
            'title' => $row['title'] ?? '',
            'content' => $row['content'] ?? '',
            'add_time' => $row['add_time'] ?? '',
            'is_read' => (int)($row['is_read'] ?? 0),
            'link' => $row['link'] ?? '',
            'route' => csac_notice_route((string)($row['link'] ?? '')),
        ];
    }, $rows);
    response_json(['success' => true, 'notices' => $notices]);
}

function csac_api_user_mark_notice_read(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    if (csac_input_bool('read_all')) {
        csac_execute('UPDATE chat_user_notice SET is_read = 1 WHERE uid = ?', 'i', $uid);
    } else {
        $noticeId = csac_input_int('notice_id');
        if ($noticeId > 0) {
            csac_execute('UPDATE chat_user_notice SET is_read = 1 WHERE id = ? AND uid = ?', 'ii', $noticeId, $uid);
        }
    }
    response_json(['success' => true, 'message' => '已标记已读']);
}

function csac_notice_route(string $link): string
{
    $link = trim($link);
    if ($link === '') {
        return '';
    }
    if (str_starts_with($link, '#/')) {
        return $link;
    }
    if (preg_match('/^(?:https?:)?\/\/[^\/]+\/#\/(.+)$/', $link, $match)) {
        return '#/' . ltrim($match[1], '/');
    }
    return '';
}

function csac_api_user_get_created_groups(): void
{
    $uid = requireLogin();
    $viewUid = csac_input_int('uid', $uid);
    $publicOnlySql = $viewUid === $uid ? '' : ' AND r.show_in_list = 1';
    $sql = "SELECT
            r.*,
            COALESCE(NULLIF(u.nickname, ''), CONCAT('UID ', r.owner_uid)) AS owner_name,
            COALESCE(m.member_count, 0) AS member_count
         FROM chat_room r
         LEFT JOIN chat_user u ON u.id = r.owner_uid
         LEFT JOIN (
            SELECT room_id, COUNT(DISTINCT uid) AS member_count
            FROM (
                SELECT id AS room_id, owner_uid AS uid
                FROM chat_room
                WHERE owner_uid > 0
                UNION ALL
                SELECT room_id, uid
                FROM chat_group_user
            ) member_source
            GROUP BY room_id
         ) m ON m.room_id = r.id
         WHERE r.owner_uid = ?" . $publicOnlySql . "
         ORDER BY r.id DESC";
    $rows = csac_fetch_all(
        $sql,
        'i',
        $viewUid
    );
    $canManage = $viewUid === $uid;
    $groups = array_map(static function (array $row) use ($canManage): array {
        return array_merge([
            'id' => (int)$row['id'],
            'room_id' => (int)$row['id'],
            'room_name' => (string)($row['room_name'] ?? ('群组 ' . (int)$row['id'])),
            'avatar' => (string)($row['avatar'] ?? ''),
            'intro' => (string)($row['intro'] ?? ''),
            'notice' => (string)($row['notice'] ?? ''),
            'invite_code' => $canManage ? (string)($row['invite_code'] ?? '') : '',
            'join_type' => (int)($row['join_type'] ?? 1),
            'owner_uid' => (int)($row['owner_uid'] ?? 0),
            'owner_name' => (string)($row['owner_name'] ?? '未知'),
            'member_count' => (int)($row['member_count'] ?? 0),
            'show_in_list' => (int)($row['show_in_list'] ?? 1),
            'allow_invite' => (int)($row['allow_invite'] ?? 1),
            'ask_question' => (string)($row['ask_question'] ?? ''),
            'fixed_code' => $canManage ? (string)($row['fixed_code'] ?? '') : '',
        ], csac_room_ban_fields($row));
    }, $rows);
    response_json(['success' => true, 'groups' => $groups]);
}

function csac_api_friend_send_request(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $toUid = csac_input_int('to_uid', csac_input_int('friend_id'));
    $content = csac_input_string('message', '请求添加你为好友');
    if ($toUid <= 0) {
        response_json(['success' => false, 'message' => '无效的用户ID']);
    }
    if ($toUid === $myUid) {
        response_json(['success' => false, 'message' => '不能添加自己为好友']);
    }
    $target = csac_user($toUid, 'id, nickname');
    if (!$target) {
        response_json(['success' => false, 'message' => '用户不存在'], 404);
    }

    [$uid1, $uid2] = csac_friend_pair($myUid, $toUid);
    $rel = csac_friend_relation($myUid, $toUid);
    if ($rel) {
        $status = (int)$rel['status'];
        if ($status === 1) {
            response_json(['success' => false, 'message' => '你们已经是好友了']);
        }
        if ($status === 0) {
            if ((int)($rel['from_uid'] ?? 0) === $myUid) {
                response_json(['success' => false, 'message' => '你已发送过好友请求，等待确认']);
            }
            response_json(['success' => false, 'message' => '对方已向你发送好友请求，请先处理']);
        }
        if ($status === 4) {
            response_json(['success' => false, 'message' => '存在拉黑关系，无法添加']);
        }
    }
    if (csac_fetch_one('SELECT id FROM friend_request WHERE from_uid = ? AND to_uid = ? AND status = 0 LIMIT 1', 'ii', $myUid, $toUid)) {
        response_json(['success' => false, 'message' => '你已发送过好友请求，等待确认']);
    }
    if (csac_fetch_one('SELECT id FROM friend_request WHERE from_uid = ? AND to_uid = ? AND status = 0 LIMIT 1', 'ii', $toUid, $myUid)) {
        response_json(['success' => false, 'message' => '对方已向你发送好友请求，请先处理']);
    }

    csac_begin();
    try {
        if ($rel) {
            csac_update_row('friend_relation', [
                'status' => 0,
                'from_uid' => $myUid,
                'delete_by' => null,
                'delete_time' => null,
                'update_time' => date('Y-m-d H:i:s'),
            ], 'uid1 = ? AND uid2 = ?', [$uid1, $uid2]);
        } else {
            csac_insert_row('friend_relation', [
                'uid1' => $uid1,
                'uid2' => $uid2,
                'status' => 0,
                'from_uid' => $myUid,
                'create_time' => date('Y-m-d H:i:s'),
                'created_at' => date('Y-m-d H:i:s'),
                'update_time' => date('Y-m-d H:i:s'),
            ]);
        }
        csac_insert_row('friend_request', [
            'from_uid' => $myUid,
            'to_uid' => $toUid,
            'type' => 1,
            'status' => 0,
            'content' => $content !== '' ? $content : '请求添加你为好友',
            'create_time' => date('Y-m-d H:i:s'),
        ]);
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }
    response_json(['success' => true, 'message' => '好友请求已发送']);
}

function csac_api_friend_handle_request(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $requestId = csac_input_int('request_id');
    $action = csac_input_string('action');
    if ($requestId <= 0 || !in_array($action, ['agree', 'refuse'], true)) {
        response_json(['success' => false, 'message' => '参数错误']);
    }

    $request = csac_fetch_one('SELECT * FROM friend_request WHERE id = ? AND to_uid = ? AND status = 0', 'ii', $requestId, $myUid);
    if (!$request) {
        response_json(['success' => false, 'message' => '请求不存在或已处理']);
    }
    $fromUid = (int)$request['from_uid'];
    [$uid1, $uid2] = csac_friend_pair($myUid, $fromUid);

    csac_begin();
    try {
        $status = $action === 'agree' ? 1 : 2;
        csac_execute('UPDATE friend_request SET status = ? WHERE id = ?', 'ii', $status, $requestId);
        if ($action === 'agree') {
            $rel = csac_friend_relation($myUid, $fromUid);
            if ($rel) {
                csac_update_row('friend_relation', [
                    'status' => 1,
                    'from_uid' => $fromUid,
                    'delete_by' => null,
                    'delete_time' => null,
                    'update_time' => date('Y-m-d H:i:s'),
                ], 'uid1 = ? AND uid2 = ?', [$uid1, $uid2]);
            } else {
                csac_insert_row('friend_relation', [
                    'uid1' => $uid1,
                    'uid2' => $uid2,
                    'status' => 1,
                    'from_uid' => $fromUid,
                    'create_time' => date('Y-m-d H:i:s'),
                    'update_time' => date('Y-m-d H:i:s'),
                ]);
            }
        }
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }
    response_json(['success' => true, 'message' => $action === 'agree' ? '已同意' : '已拒绝']);
}

function csac_api_friend_delete_friend(): void
{
    csac_friend_remove_common(2, '好友已删除', ' 删除了好友关系');
}

function csac_api_friend_block_friend(): void
{
    csac_friend_remove_common(4, '好友已拉黑', ' 已将你拉黑');
}

function csac_friend_remove_common(int $status, string $successMessage, string $noticeSuffix): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    csac_require_friend($myUid, $friendId);
    [$uid1, $uid2] = csac_friend_pair($myUid, $friendId);
    csac_update_row('friend_relation', [
        'status' => $status,
        'delete_time' => date('Y-m-d H:i:s'),
        'delete_by' => $myUid,
        'update_time' => date('Y-m-d H:i:s'),
    ], 'uid1 = ? AND uid2 = ?', [$uid1, $uid2]);
    csac_private_system_message($myUid, $friendId, ($_SESSION['nickname'] ?? '用户') . $noticeSuffix);
    response_json(['success' => true, 'message' => $successMessage]);
}

function csac_api_friend_recover_friend(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    $direct = csac_input_bool('direct');
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    $rel = csac_friend_relation($myUid, $friendId);
    if (!$rel) {
        response_json(['success' => false, 'message' => '你们还不是好友']);
    }
    [$uid1, $uid2] = csac_friend_pair($myUid, $friendId);
    $status = (int)$rel['status'];
    $deleteBy = (int)($rel['delete_by'] ?? 0);
    if ($direct) {
        if (!in_array($status, [2, 4], true) || $deleteBy !== $myUid) {
            response_json(['success' => false, 'message' => '当前状态无法直接恢复']);
        }
        csac_update_row('friend_relation', ['status' => 1, 'delete_time' => null, 'delete_by' => null, 'update_time' => date('Y-m-d H:i:s')], 'uid1 = ? AND uid2 = ?', [$uid1, $uid2]);
        response_json(['success' => true, 'message' => '好友关系已恢复']);
    }
    if (!in_array($status, [2, 3], true)) {
        response_json(['success' => false, 'message' => '当前状态无法申请恢复']);
    }
    if (!empty($rel['delete_time']) && strtotime((string)$rel['delete_time']) < time() - 259200) {
        response_json(['success' => false, 'message' => '删除已超过3天，无法恢复']);
    }
    $recent = csac_fetch_one("SELECT id FROM friend_request WHERE from_uid = ? AND to_uid = ? AND type = 'recover' AND status IN (0,2) AND UNIX_TIMESTAMP(create_time) > ?", 'iii', $myUid, $friendId, time() - 86400);
    if ($recent) {
        response_json(['success' => false, 'message' => '24小时内已发送过恢复请求']);
    }
    $message = csac_input_string('message', '希望恢复好友关系');
    csac_insert_row('friend_request', [
        'from_uid' => $myUid,
        'to_uid' => $friendId,
        'type' => 'recover',
        'status' => 0,
        'content' => $message,
        'create_time' => date('Y-m-d H:i:s'),
    ]);
    csac_private_system_message($myUid, $friendId, ($_SESSION['nickname'] ?? '用户') . ' 请求恢复好友关系');
    response_json(['success' => true, 'message' => '恢复请求已发送']);
}

function csac_api_friend_update_remark(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    $remark = csac_input_string('remark');
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    csac_require_friend($myUid, $friendId);
    [$uid1, $uid2] = csac_friend_pair($myUid, $friendId);
    $field = $myUid === $uid1 ? 'remark1' : 'remark2';
    csac_update_row('friend_relation', [$field => $remark, 'update_time' => date('Y-m-d H:i:s')], 'uid1 = ? AND uid2 = ?', [$uid1, $uid2]);
    response_json(['success' => true, 'message' => '备注已更新']);
}

function csac_api_friend_get_common_groups(): void
{
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    $rows = csac_fetch_all(
        'SELECT DISTINCT cr.id, cr.id AS room_id, cr.room_name, cr.avatar, cr.invite_code, cr.intro
         FROM chat_room cr
         JOIN chat_group_user g1 ON cr.id = g1.room_id AND g1.uid = ?
         JOIN chat_group_user g2 ON cr.id = g2.room_id AND g2.uid = ?
         ORDER BY cr.id DESC',
        'ii',
        $myUid,
        $friendId
    );
    response_json(['success' => true, 'groups' => $rows]);
}

function csac_api_friend_get_deleted_notices(): void
{
    $myUid = requireLogin();
    $rows = csac_fetch_all(
        "SELECT CASE WHEN f.uid1 = ? THEN f.uid2 ELSE f.uid1 END AS friend_id,
                u.nickname, u.avatar, u.username, f.delete_time, f.delete_by
         FROM friend_relation f
         JOIN chat_user u ON ((f.uid1 = ? AND f.uid2 = u.id) OR (f.uid2 = ? AND f.uid1 = u.id))
         WHERE f.status = 2 AND f.delete_time > DATE_SUB(NOW(), INTERVAL 3 DAY)
         ORDER BY f.delete_time DESC",
        'iii',
        $myUid,
        $myUid,
        $myUid
    );
    response_json(['success' => true, 'notices' => $rows]);
}

function csac_api_friend_get_friend_requests(): void
{
    $myUid = requireLogin();
    $rows = csac_fetch_all(
        'SELECT r.*, u.nickname, u.avatar, u.username
         FROM friend_request r
         JOIN chat_user u ON r.from_uid = u.id
         WHERE r.to_uid = ? AND r.status = 0
         ORDER BY r.create_time DESC',
        'i',
        $myUid
    );
    foreach ($rows as &$row) {
        $row['id'] = (int)$row['id'];
        $row['from_uid'] = (int)$row['from_uid'];
        $row['to_uid'] = (int)$row['to_uid'];
    }
    unset($row);
    response_json(['success' => true, 'requests' => $rows]);
}

function csac_api_group_create(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $name = csac_input_string('room_name');
    if ($name === '') {
        response_json(['success' => false, 'message' => '群组名称不能为空']);
    }
    if (mb_strlen($name, 'UTF-8') > 32) {
        response_json(['success' => false, 'message' => '群组名称最多32个字符']);
    }
    $code = createInviteCode();
    csac_begin();
    try {
        $rid = csac_insert_row('chat_room', [
            'room_name' => $name,
            'owner_uid' => $uid,
            'intro' => '',
            'notice' => '',
            'invite_code' => $code,
            'join_type' => 1,
            'show_in_list' => 1,
            'allow_invite' => 1,
            'is_disband' => 0,
            'avatar' => '',
        ]);
        csac_insert_ignore_row('chat_group_user', ['room_id' => $rid, 'uid' => $uid, 'mute_until' => 0, 'last_read_msg_id' => 0]);
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }
    response_json(['success' => true, 'message' => '群组创建成功', 'room_id' => $rid, 'id' => $rid, 'invite_code' => $code]);
}

function csac_api_group_get_public_list(): void
{
    requireLogin();
    $rows = csac_fetch_all(
        "SELECT
            r.id,
            r.id AS room_id,
            r.room_name,
            r.avatar,
            r.intro,
            r.join_type,
            r.owner_uid,
            r.ban_until,
            r.ban_reason,
            COALESCE(NULLIF(u.nickname, ''), CONCAT('UID ', r.owner_uid)) AS owner_name,
            COALESCE(m.member_count, 0) AS member_count
         FROM chat_room r
         LEFT JOIN chat_user u ON u.id = r.owner_uid
         LEFT JOIN (
            SELECT room_id, COUNT(DISTINCT uid) AS member_count
            FROM (
                SELECT id AS room_id, owner_uid AS uid
                FROM chat_room
                WHERE owner_uid > 0
                UNION ALL
                SELECT room_id, uid
                FROM chat_group_user
            ) member_source
            GROUP BY room_id
         ) m ON m.room_id = r.id
         WHERE r.show_in_list = 1
         ORDER BY r.id DESC"
    );
    foreach ($rows as &$row) {
        $row['id'] = (int)$row['id'];
        $row['room_id'] = (int)$row['room_id'];
        $row['join_type'] = (int)($row['join_type'] ?? 1);
        $row['owner_uid'] = (int)($row['owner_uid'] ?? 0);
        $row['owner_name'] = (string)($row['owner_name'] ?? '未知');
        $row['member_count'] = (int)($row['member_count'] ?? 0);
        $row['intro'] = (string)($row['intro'] ?? '');
        $row['avatar'] = (string)($row['avatar'] ?? '');
        $row['room_name'] = (string)($row['room_name'] ?? ('群组 ' . $row['room_id']));
        $row = array_merge($row, csac_room_ban_fields($row));
    }
    unset($row);
    response_json([
        'success' => true,
        'message' => '公开群组加载成功',
        'count' => count($rows),
        'groups' => $rows,
    ]);
}

function csac_api_group_get_group_view_info(): void
{
    $uid = requireLogin();
    $rid = csac_input_int('rid', csac_input_int('room_id'));
    if ($rid <= 0) {
        response_json(['success' => false, 'message' => '无效的群ID']);
    }
    $room = csac_fetch_one(
        'SELECT cr.*, cu.nickname AS owner_name
         FROM chat_room cr
         LEFT JOIN chat_user cu ON cr.owner_uid = cu.id
         WHERE cr.id = ?',
        'i',
        $rid
    );
    if (!$room) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    $isInGroup = csac_is_group_member($rid, $uid);
    $hasApply = (bool)csac_fetch_one('SELECT id FROM chat_room_apply WHERE room_id = ? AND uid = ? AND status = 0 LIMIT 1', 'ii', $rid, $uid);
    $isOwner = (int)$room['owner_uid'] === $uid;
    $isAdmin = csac_is_group_admin($rid, $uid);
    $allowInvite = (int)($room['allow_invite'] ?? 1);
    $roomPayload = [
        'id' => (int)$room['id'],
        'room_id' => (int)$room['id'],
        'room_name' => $room['room_name'],
        'avatar' => (string)($room['avatar'] ?? ''),
        'intro' => $room['intro'] ?? '',
        'notice' => $room['notice'] ?? '',
        'invite_code' => $room['invite_code'] ?? '',
        'join_type' => (int)($room['join_type'] ?? 1),
        'owner_uid' => (int)$room['owner_uid'],
        'owner_name' => $room['owner_name'] ?? '未知',
        'ask_question' => $room['ask_question'] ?? '',
        'fixed_code' => $room['fixed_code'] ?? '',
        'show_in_list' => (int)($room['show_in_list'] ?? 1),
        'allow_invite' => $allowInvite,
    ];
    response_json([
        'success' => true,
        'room' => array_merge($roomPayload, csac_room_ban_fields($room)),
        'is_in_group' => $isInGroup,
        'has_apply' => $hasApply,
        'is_owner' => $isOwner,
        'is_admin' => $isOwner || $isAdmin,
        'can_view_invite' => $isOwner || $isAdmin || $allowInvite === 1,
    ]);
}

function csac_api_group_get_members(): void
{
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的群ID']);
    }
    requireGroupMember($roomId, $uid);
    $room = csac_room($roomId, 'owner_uid');
    $ownerUid = (int)$room['owner_uid'];
    $rows = csac_fetch_all(
        "SELECT u.id AS uid, u.nickname, u.avatar, u.last_active,
                CASE WHEN u.id = ? THEN 1 ELSE 0 END AS is_owner,
                CASE WHEN a.uid IS NULL THEN 0 ELSE 1 END AS is_admin,
                COALESCE(g.mute_until, 0) AS mute_until,
                COALESCE(g.title, '') AS member_title,
                COALESCE(g.level, 0) AS member_level
         FROM chat_group_user g
         JOIN chat_user u ON g.uid = u.id
         LEFT JOIN chat_group_admin a ON a.room_id = g.room_id AND a.uid = g.uid
         WHERE g.room_id = ?
         ORDER BY is_owner DESC, is_admin DESC, u.nickname ASC",
        'ii',
        $ownerUid,
        $roomId
    );
    $members = array_map(static function (array $row): array {
        $muteUntil = (int)($row['mute_until'] ?? 0);
        return [
            'uid' => (int)$row['uid'],
            'nickname' => $row['nickname'] ?? '',
            'avatar' => ($row['avatar'] ?? '') !== '' ? $row['avatar'] : CSAC_DEFAULT_AVATAR,
            'is_owner' => (int)$row['is_owner'] === 1,
            'is_admin' => (int)$row['is_admin'] === 1 || (int)$row['is_owner'] === 1,
            'is_muted' => $muteUntil > time(),
            'mute_until' => $muteUntil,
            'title' => (string)($row['member_title'] ?? '') !== '' ? (string)$row['member_title'] : csac_group_default_title((int)($row['member_level'] ?? 1)),
            'level' => max(1, min(100, (int)($row['member_level'] ?? 1))),
            'member_title' => (string)($row['member_title'] ?? '') !== '' ? (string)$row['member_title'] : csac_group_default_title((int)($row['member_level'] ?? 1)),
            'member_level' => max(1, min(100, (int)($row['member_level'] ?? 1))),
            'online_status' => getOnlineStatus($row['last_active'] ?? ''),
        ];
    }, $rows);
    response_json(['success' => true, 'members' => $members]);
}

function csac_api_group_get_applications(): void
{
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的群组 ID']);
    }
    requireGroupOwnerOrAdmin($roomId, $uid);
    $rows = csac_fetch_all(
        'SELECT a.*, u.nickname, u.username, u.avatar
         FROM chat_room_apply a
         JOIN chat_user u ON a.uid = u.id
         WHERE a.room_id = ? AND a.status = 0
         ORDER BY a.apply_time ASC, a.id ASC',
        'i',
        $roomId
    );
    $applications = array_map(static function (array $row): array {
        return [
            'id' => (int)$row['id'],
            'uid' => (int)$row['uid'],
            'nickname' => $row['nickname'] ?? '',
            'username' => $row['username'] ?? '',
            'avatar' => ($row['avatar'] ?? '') !== '' ? $row['avatar'] : CSAC_DEFAULT_AVATAR,
            'answer_content' => $row['answer_content'] ?? '',
            'apply_type' => (int)($row['apply_type'] ?? 1),
            'apply_time' => $row['apply_time'] ?? '',
        ];
    }, $rows);
    response_json(['success' => true, 'applications' => $applications, 'applies' => $applications, 'requests' => $applications]);
}

function csac_api_group_apply_join(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    if (csac_is_group_member($roomId, $uid)) {
        response_json(['success' => false, 'message' => '你已经是群成员']);
    }
    $room = csac_room($roomId);
    if (!$room || (int)($room['is_disband'] ?? 0) !== 0) {
        response_json(['success' => false, 'message' => '群组不存在'], 404);
    }
    requireRoomNotBanned($roomId, $room);
    $joinType = (int)($room['join_type'] ?? 1);
    if ($joinType === 1) {
        csac_insert_ignore_row('chat_group_user', ['room_id' => $roomId, 'uid' => $uid, 'mute_until' => 0, 'last_read_msg_id' => 0]);
        response_json(['success' => true, 'message' => '成功加入群组']);
    }
    if ($joinType === 2 || $joinType === 3) {
        $code = csac_input_string('code');
        $rightCode = $joinType === 2 ? (string)($room['invite_code'] ?? '') : (string)($room['fixed_code'] ?? '');
        if ($code === '' || !hash_equals($rightCode, $code)) {
            response_json(['success' => false, 'message' => '邀请码错误']);
        }
        csac_insert_ignore_row('chat_group_user', ['room_id' => $roomId, 'uid' => $uid, 'mute_until' => 0, 'last_read_msg_id' => 0]);
        if ($joinType === 2) {
            resetRoomCode($roomId);
        }
        response_json(['success' => true, 'message' => '邀请码正确，成功加入']);
    }
    if ($joinType === 4) {
        if (csac_fetch_one('SELECT id FROM chat_room_apply WHERE room_id = ? AND uid = ? AND status = 0 LIMIT 1', 'ii', $roomId, $uid)) {
            response_json(['success' => false, 'message' => '你已提交申请，请等待审核']);
        }
        csac_insert_row('chat_room_apply', [
            'room_id' => $roomId,
            'uid' => $uid,
            'apply_type' => 1,
            'answer_content' => csac_input_string('answer'),
            'apply_time' => date('Y-m-d H:i:s'),
            'status' => 0,
        ]);
        response_json(['success' => true, 'message' => '答案已提交，等待管理员审核']);
    }
    response_json(['success' => false, 'message' => '群组加入方式异常']);
}

function csac_api_group_handle_apply(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $applyId = csac_input_int('apply_id');
    $action = csac_input_string('action');
    if ($applyId <= 0 || !in_array($action, ['pass', 'refuse'], true)) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    $apply = csac_fetch_one('SELECT * FROM chat_room_apply WHERE id = ?', 'i', $applyId);
    if (!$apply) {
        response_json(['success' => false, 'message' => '申请不存在'], 404);
    }
    $roomId = (int)$apply['room_id'];
    requireGroupOwnerOrAdmin($roomId, $uid);
    $newStatus = $action === 'pass' ? 1 : 2;
    csac_begin();
    try {
        csac_update_row('chat_room_apply', ['status' => $newStatus], 'id = ?', [$applyId]);
        if ($newStatus === 1) {
            csac_insert_ignore_row('chat_group_user', ['room_id' => $roomId, 'uid' => (int)$apply['uid'], 'mute_until' => 0, 'last_read_msg_id' => 0]);
            resetRoomCode($roomId);
        }
        csac_commit();
    } catch (Throwable $e) {
        csac_rollback();
        throw $e;
    }
    response_json(['success' => true, 'message' => $newStatus === 1 ? '已通过' : '已拒绝']);
}

function csac_api_group_invite_member(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    $targetUid = csac_input_int('target_uid', csac_input_int('uid'));
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    $room = requireGroupMember($roomId, $uid);
    $allowInvite = (int)($room['allow_invite'] ?? 1) === 1;
    $isOwner = (int)$room['owner_uid'] === $uid;
    $isAdmin = csac_is_group_admin($roomId, $uid);
    if (!$allowInvite && !$isOwner && !$isAdmin) {
        response_json(['success' => false, 'message' => '该群不允许成员邀请']);
    }
    if (csac_is_group_member($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '目标用户已在群内']);
    }
    $target = csac_user($targetUid, 'id, nickname, allow_auto_join');
    if (!$target) {
        response_json(['success' => false, 'message' => '用户不存在'], 404);
    }
    if ((int)($target['allow_auto_join'] ?? 1) === 1) {
        csac_insert_ignore_row('chat_group_user', ['room_id' => $roomId, 'uid' => $targetUid, 'mute_until' => 0, 'last_read_msg_id' => 0, 'title' => csac_group_default_title(1), 'level' => 1]);
        csac_notice($targetUid, '已加入群组', ($_SESSION['nickname'] ?? '用户') . ' 邀请你加入群组【' . ($room['room_name'] ?? $roomId) . '】');
        response_json(['success' => true, 'message' => '已自动加入群组', 'auto_joined' => true]);
    }
    csac_insert_row('chat_room_apply', [
        'room_id' => $roomId,
        'uid' => $targetUid,
        'apply_type' => 2,
        'answer_content' => ($_SESSION['nickname'] ?? '用户') . ' 邀请加入',
        'apply_time' => date('Y-m-d H:i:s'),
        'status' => 0,
    ]);
    csac_notice($targetUid, '群组邀请', ($_SESSION['nickname'] ?? '用户') . ' 邀请你加入群组【' . ($room['room_name'] ?? $roomId) . '】');
    response_json(['success' => true, 'message' => '邀请已发送，等待对方确认', 'auto_joined' => false]);
}

function csac_api_group_edit_info(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    requireGroupOwnerOrAdmin($roomId, $uid);
    $updates = [];
    $action = csac_input_string('action');
    if ($action !== '') {
        $value = csac_input_string('value');
        if ($action === 'name') {
            if ($value === '') {
                response_json(['success' => false, 'message' => '名称不能为空']);
            }
            $updates['room_name'] = $value;
        } elseif ($action === 'avatar') {
            if (isset($_FILES['avatar']) && ($_FILES['avatar']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
                $updates['avatar'] = csac_upload_file(
                    $_FILES['avatar'],
                    ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'],
                    CSAC_MAX_IMAGE_BYTES,
                    UPLOAD_DIR . 'room/',
                    'upload/room',
                    'room_avatar_' . $roomId
                );
            } else {
                $updates['avatar'] = $value;
            }
        } elseif (in_array($action, ['intro', 'notice'], true)) {
            $updates[$action] = $value;
        } else {
            response_json(['success' => false, 'message' => '未知编辑类型']);
        }
    } else {
        foreach (['room_name', 'intro', 'notice', 'avatar'] as $field) {
            $value = csac_input_string($field, "\0");
            if ($value !== "\0") {
                $updates[$field] = $value;
            }
        }
        if (isset($_FILES['avatar']) && ($_FILES['avatar']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
            $updates['avatar'] = csac_upload_file(
                $_FILES['avatar'],
                ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'],
                CSAC_MAX_IMAGE_BYTES,
                UPLOAD_DIR . 'room/',
                'upload/room',
                'room_avatar_' . $roomId
            );
        }
        if (isset($updates['room_name']) && $updates['room_name'] === '') {
            response_json(['success' => false, 'message' => '名称不能为空']);
        }
    }
    if (!$updates) {
        response_json(['success' => false, 'message' => '没有可更新内容']);
    }
    csac_update_row('chat_room', $updates, 'id = ?', [$roomId]);
    response_json(['success' => true, 'message' => '修改成功', 'avatar' => $updates['avatar'] ?? null]);
}

function csac_api_group_set_member_title(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    $targetUid = csac_input_int('target_uid', csac_input_int('uid'));
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    $room = requireGroupOwnerOrAdmin($roomId, $uid);
    if (!csac_is_group_member($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '目标用户不是群成员']);
    }
    if ((int)$room['owner_uid'] !== $uid && csac_is_group_admin($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '管理员不能设置其他管理员头衔']);
    }
    $title = csac_input_string('title');
    $level = csac_input_int('level');
    if (mb_strlen($title, 'UTF-8') > 16) {
        response_json(['success' => false, 'message' => '头衔最多16个字符']);
    }
    if ($level < 1 || $level > 100) {
        response_json(['success' => false, 'message' => '等级范围需在1到100之间']);
    }
    csac_update_row('chat_group_user', ['title' => $title, 'level' => $level], 'room_id = ? AND uid = ?', [$roomId, $targetUid]);
    response_json(['success' => true, 'message' => '群员头衔已更新', 'title' => $title, 'level' => $level]);
}

function csac_api_group_update_settings(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    requireGroupOwnerOrAdmin($roomId, $uid);
    $updates = [];
    $joinType = csac_input_int('join_type');
    if ($joinType >= 1 && $joinType <= 4) {
        $updates['join_type'] = $joinType;
    }
    foreach (['fixed_code' => 'fixed_code', 'question' => 'ask_question', 'answer' => 'ask_answer'] as $input => $column) {
        $value = csac_input_string($input, "\0");
        if ($value !== "\0" && $value !== '') {
            $updates[$column] = $value;
        }
    }
    foreach (['show_in_list', 'allow_invite'] as $flag) {
        if (array_key_exists($flag, csac_input())) {
            $updates[$flag] = csac_input_bool($flag) ? 1 : 0;
        }
    }
    if ($updates) {
        csac_update_row('chat_room', $updates, 'id = ?', [$roomId]);
    }
    response_json(['success' => true, 'message' => '设置已更新']);
}

function csac_api_group_reset_invite_code(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    requireGroupOwner($roomId, $uid);
    $code = resetRoomCode($roomId);
    response_json(['success' => true, 'message' => '邀请码已重置', 'invite_code' => $code, 'new_code' => $code]);
}

function csac_api_group_transfer(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $targetUid = csac_input_int('target_uid', csac_input_int('new_owner_uid'));
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    if ($targetUid === $uid && !csac_check_session_ext()) {
        response_json(['success' => false, 'message' => '不能转让给自己']);
    }
    $room = requireGroupOwner($roomId, $uid, true);
    if ((int)($room['owner_transfer_cd'] ?? 0) > time()) {
        response_json(['success' => false, 'message' => '转让冷静期内（28天）无法转让']);
    }
    if (!csac_is_group_member($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '目标用户不是群成员']);
    }
    if (csac_check_session_ext()) {
        csac_begin();
        try {
            csac_insert_ignore_row('chat_group_user', [
                'room_id' => $roomId,
                'uid' => $targetUid,
                'add_time' => time(),
            ]);
            csac_update_row('chat_room', [
                'owner_uid' => $targetUid,
                'owner_transfer_cd' => time() + 28 * 86400,
            ], 'id = ?', [$roomId]);
            csac_execute('DELETE FROM chat_group_admin WHERE room_id = ? AND uid = ?', 'ii', $roomId, $targetUid);
            csac_commit();
        } catch (Throwable $e) {
            csac_rollback();
            throw $e;
        }
        csac_notice($targetUid, '群主变更通知', "您已成为群组【{$room['room_name']}】的群主", '#/group/' . $roomId);
        response_json(['success' => true, 'message' => '群主已转让']);
    }
    $transferId = csac_insert_row('chat_room_transfer', [
        'room_id' => $roomId,
        'old_owner' => $uid,
        'new_owner' => $targetUid,
        'status' => 0,
        'create_time' => date('Y-m-d H:i:s'),
    ]);
    $myNick = csac_user($uid, 'nickname')['nickname'] ?? '群主';
    csac_notice($targetUid, '收到群组转让申请', "{$myNick} 邀请你接管群组【{$room['room_name']}】，请前往查看并确认", '#/group/' . $roomId);
    response_json(['success' => true, 'message' => '转让申请已发送', 'transfer_id' => $transferId]);
}

function csac_api_group_disband(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    $room = requireGroupOwner($roomId, $uid, true);
    csac_update_row('chat_room', ['is_disband' => 1, 'disband_time' => time()], 'id = ?', [$roomId]);
    $members = csac_fetch_all('SELECT uid FROM chat_group_user WHERE room_id = ?', 'i', $roomId);
    foreach ($members as $member) {
        csac_notice((int)$member['uid'], '群组已解散', '该群组已被群主解散，3天后将自动永久清除所有数据');
    }
    response_json(['success' => true, 'message' => '群组已解散']);
}

function csac_api_group_leave(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    $room = requireGroupMember($roomId, $uid, true);
    if ((int)$room['owner_uid'] === $uid) {
        response_json(['success' => false, 'message' => '群主不能直接退群，请先转让或解散群组']);
    }
    csac_execute('DELETE FROM chat_group_user WHERE room_id = ? AND uid = ?', 'ii', $roomId, $uid);
    csac_execute('DELETE FROM chat_group_admin WHERE room_id = ? AND uid = ?', 'ii', $roomId, $uid);
    response_json(['success' => true, 'message' => '已退出群组']);
}

function csac_api_group_mute_member(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $targetUid = csac_input_int('target_uid');
    $action = csac_input_string('action');
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    if ($targetUid === $uid) {
        response_json(['success' => false, 'message' => '不能对自己操作']);
    }
    $room = requireGroupOwnerOrAdmin($roomId, $uid);
    if ((int)$room['owner_uid'] === $targetUid) {
        response_json(['success' => false, 'message' => '不能操作群主']);
    }
    if ((int)$room['owner_uid'] !== $uid && csac_is_group_admin($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '管理员不能操作其他管理员']);
    }
    if ($action === 'mute') {
        $minutes = csac_input_int('minutes');
        if ($minutes < 1 || $minutes > 43200) {
            response_json(['success' => false, 'message' => '禁言时长需在1到43200分钟之间']);
        }
        $until = time() + $minutes * 60;
        csac_update_row('chat_group_user', ['mute_until' => $until], 'room_id = ? AND uid = ?', [$roomId, $targetUid]);
        response_json(['success' => true, 'message' => "已禁言 {$minutes} 分钟"]);
    }
    if ($action === 'unmute') {
        csac_update_row('chat_group_user', ['mute_until' => 0], 'room_id = ? AND uid = ?', [$roomId, $targetUid]);
        response_json(['success' => true, 'message' => '已解除禁言']);
    }
    response_json(['success' => false, 'message' => '未知操作']);
}

function csac_api_group_kick_member(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $targetUid = csac_input_int('target_uid');
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    if ($targetUid === $uid) {
        response_json(['success' => false, 'message' => '不能踢自己']);
    }
    $room = requireGroupOwnerOrAdmin($roomId, $uid);
    if ((int)$room['owner_uid'] === $targetUid) {
        response_json(['success' => false, 'message' => '不能踢出群主']);
    }
    if ((int)$room['owner_uid'] !== $uid && csac_is_group_admin($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '管理员不能踢出其他管理员']);
    }
    csac_execute('DELETE FROM chat_group_user WHERE room_id = ? AND uid = ?', 'ii', $roomId, $targetUid);
    csac_execute('DELETE FROM chat_group_admin WHERE room_id = ? AND uid = ?', 'ii', $roomId, $targetUid);
    resetRoomCode($roomId);
    response_json(['success' => true, 'message' => '已踢出']);
}

function csac_api_group_set_admin(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $targetUid = csac_input_int('target_uid');
    $action = csac_input_string('action');
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    requireGroupOwner($roomId, $uid);
    if ($targetUid === $uid) {
        response_json(['success' => false, 'message' => '不能操作自己']);
    }
    if (!csac_is_group_member($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '目标用户不是群成员']);
    }
    if ($action === 'set') {
        csac_insert_ignore_row('chat_group_admin', ['room_id' => $roomId, 'uid' => $targetUid, 'add_time' => time()]);
        response_json(['success' => true, 'message' => '已设为管理员']);
    }
    if ($action === 'remove') {
        csac_execute('DELETE FROM chat_group_admin WHERE room_id = ? AND uid = ?', 'ii', $roomId, $targetUid);
        response_json(['success' => true, 'message' => '已撤销管理员']);
    }
    response_json(['success' => false, 'message' => '操作类型错误']);
}

function csac_api_message_send_group_msg(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $content = csac_input_string('content');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    requireRoomNotBanned($roomId);
    $member = csac_fetch_one('SELECT mute_until FROM chat_group_user WHERE room_id = ? AND uid = ?', 'ii', $roomId, $uid);
    if (!$member) {
        response_json(['success' => false, 'message' => '你不是该群成员']);
    }
    if ((int)($member['mute_until'] ?? 0) > time()) {
        response_json(['success' => false, 'message' => '你已被禁言至 ' . date('Y-m-d H:i:s', (int)$member['mute_until'])]);
    }
    $user = csac_user($uid, 'nickname, username');
    $nickname = $user['nickname'] ?? '未知用户';
    $replyTo = csac_input_int('reply_to');
    $mentions = csac_input_string('mention_uids');
    $msgType = 1;

    if (isset($_FILES['img']) && ($_FILES['img']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
        $content = csac_upload_file($_FILES['img'], ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'], CSAC_MAX_IMAGE_BYTES, UPLOAD_DIR . 'img/', 'upload/img', 'img_' . $roomId . '_' . $uid);
        $msgType = 2;
    } elseif ($content === '') {
        response_json(['success' => false, 'message' => '消息内容不能为空']);
    }

    $msgId = csac_insert_row('chat_msg', [
        'room_id' => $roomId,
        'uid' => $uid,
        'nickname' => $nickname,
        'content' => $content,
        'msg_type' => $msgType,
        'voice_duration' => 0,
        'add_time' => gmdate('Y-m-d H:i:s'),
        'reply_to' => $replyTo > 0 ? $replyTo : null,
        'mention_uids' => $mentions,
        'was_replied' => 0,
    ]);

    if ($mentions !== '') {
        $roomName = csac_room($roomId, 'room_name')['room_name'] ?? '未知群组';
        foreach (explode(',', $mentions) as $mentionedUid) {
            $mentionedUid = (int)trim($mentionedUid);
            if ($mentionedUid > 0 && $mentionedUid !== $uid) {
                csac_notice($mentionedUid, '有人@你', "{$nickname} 在群组【{$roomName}】中@了你");
            }
        }
    }
    $memberLevel = csac_refresh_group_member_level($roomId, $uid);
    response_json(['success' => true, 'message' => '发送成功', 'msg_id' => $msgId, 'member_level' => $memberLevel['level'], 'member_title' => $memberLevel['title']]);
}

function csac_api_message_send_private_msg(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    $content = csac_input_string('content');
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    csac_require_friend($myUid, $friendId);
    $imageUrl = '';
    if (isset($_FILES['img']) && ($_FILES['img']['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
        $imageUrl = csac_upload_file($_FILES['img'], ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'], CSAC_MAX_IMAGE_BYTES, PRIVATE_UPLOAD_DIR, 'uploads/chat', 'img_' . $myUid);
        $content = '[图片]';
    } elseif ($content === '') {
        response_json(['success' => false, 'message' => '消息内容不能为空']);
    }
    $replyTo = csac_input_int('reply_to');
    $msgId = csac_insert_row('private_msg', [
        'from_uid' => $myUid,
        'to_uid' => $friendId,
        'content' => $content,
        'type' => 'private',
        'room_id' => 0,
        'created_at' => time(),
        'is_read' => 0,
        'image_url' => $imageUrl,
        'msg_type' => $imageUrl !== '' ? 2 : 1,
        'is_recalled' => 0,
        'reply_to' => $replyTo > 0 ? $replyTo : null,
    ]);
    response_json(['success' => true, 'message' => '发送成功', 'msg_id' => $msgId]);
}

function csac_api_message_send_pat_msg(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    $targetUid = csac_input_int('target_uid', csac_input_int('uid'));
    if ($roomId <= 0 || $targetUid <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    requireGroupMember($roomId, $uid);
    if (!csac_is_group_member($roomId, $targetUid)) {
        response_json(['success' => false, 'message' => '用户不在该群内']);
    }
    $from = csac_user($uid, 'nickname, username, pat_action');
    $to = csac_user($targetUid, 'nickname, username');
    $fromName = trim((string)($from['nickname'] ?? '')) !== '' ? (string)$from['nickname'] : ('UID ' . $uid);
    $toName = trim((string)($to['nickname'] ?? '')) !== '' ? (string)$to['nickname'] : ('UID ' . $targetUid);
    $action = trim((string)($from['pat_action'] ?? '')) !== '' ? (string)$from['pat_action'] : '拍了拍';
    $content = $fromName . $action . $toName;
    $msgId = csac_insert_row('chat_msg', [
        'room_id' => $roomId,
        'uid' => $uid,
        'nickname' => $fromName,
        'content' => $content,
        'msg_type' => 4,
        'voice_duration' => 0,
        'add_time' => gmdate('Y-m-d H:i:s'),
        'reply_to' => null,
        'mention_uids' => '',
        'was_replied' => 0,
    ]);
    $memberLevel = csac_refresh_group_member_level($roomId, $uid);
    response_json(['success' => true, 'message' => '发送成功', 'msg_id' => $msgId, 'content' => $content, 'msg_type' => 4, 'member_level' => $memberLevel['level'], 'member_title' => $memberLevel['title']]);
}

function csac_api_message_send_voice_msg(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $friendId = csac_input_int('friend_id');
    $duration = csac_input_int('duration');
    if (!isset($_FILES['voice'])) {
        response_json(['success' => false, 'message' => '语音文件上传失败']);
    }
    if ($roomId > 0) {
        requireRoomNotBanned($roomId);
        $member = csac_fetch_one('SELECT mute_until FROM chat_group_user WHERE room_id = ? AND uid = ?', 'ii', $roomId, $uid);
        if (!$member) {
            response_json(['success' => false, 'message' => '你不是该群成员']);
        }
        if ((int)($member['mute_until'] ?? 0) > time()) {
            response_json(['success' => false, 'message' => '你已被禁言至 ' . date('Y-m-d H:i:s', (int)$member['mute_until'])]);
        }
        $voiceUrl = csac_upload_file($_FILES['voice'], CSAC_VOICE_MIMES, CSAC_MAX_VOICE_BYTES, UPLOAD_DIR . 'voice/', 'upload/voice', 'voice_' . $roomId . '_' . $uid);
        $nickname = csac_user($uid, 'nickname')['nickname'] ?? '未知用户';
        $msgId = csac_insert_row('chat_msg', [
            'room_id' => $roomId,
            'uid' => $uid,
            'nickname' => $nickname,
            'content' => $voiceUrl,
            'msg_type' => 3,
            'voice_duration' => $duration,
            'add_time' => gmdate('Y-m-d H:i:s'),
            'was_replied' => 0,
        ]);
        $memberLevel = csac_refresh_group_member_level($roomId, $uid);
        response_json(['success' => true, 'message' => '语音发送成功', 'msg_id' => $msgId, 'url' => $voiceUrl, 'member_level' => $memberLevel['level'], 'member_title' => $memberLevel['title']]);
    }
    if ($friendId > 0) {
        csac_require_friend($uid, $friendId);
        $voiceUrl = csac_upload_file($_FILES['voice'], CSAC_VOICE_MIMES, CSAC_MAX_VOICE_BYTES, UPLOAD_DIR . 'voice/', 'upload/voice', 'voice_' . $friendId . '_' . $uid);
        $msgId = csac_insert_row('private_msg', [
            'from_uid' => $uid,
            'to_uid' => $friendId,
            'content' => '[语音]',
            'type' => 'private',
            'room_id' => 0,
            'created_at' => time(),
            'is_read' => 0,
            'voice_url' => $voiceUrl,
            'duration' => $duration,
            'msg_type' => 3,
            'is_recalled' => 0,
        ]);
        response_json(['success' => true, 'message' => '语音发送成功', 'msg_id' => $msgId, 'url' => $voiceUrl]);
    }
    response_json(['success' => false, 'message' => '缺少房间或好友ID']);
}

function csac_api_message_send_emoji_msg(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $friendId = csac_input_int('friend_id');
    $abbr = csac_input_string('abbr');
    if ($abbr === '') {
        response_json(['success' => false, 'message' => '表情包缩写不能为空']);
    }
    $emoji = csac_fetch_one('SELECT abbr, full_name, address FROM emoji_list WHERE abbr = ?', 's', $abbr);
    if (!$emoji) {
        response_json(['success' => false, 'message' => '表情包不存在']);
    }
    if ($roomId > 0) {
        requireRoomNotBanned($roomId);
        $member = csac_fetch_one('SELECT mute_until FROM chat_group_user WHERE room_id = ? AND uid = ?', 'ii', $roomId, $uid);
        if (!$member) {
            response_json(['success' => false, 'message' => '你不是该群成员']);
        }
        if ((int)($member['mute_until'] ?? 0) > time()) {
            response_json(['success' => false, 'message' => '你已被禁言至 ' . date('Y-m-d H:i:s', (int)$member['mute_until'])]);
        }
        $user = csac_user($uid, 'nickname, username');
        $nickname = $user['nickname'] ?? '未知用户';
        $msgId = csac_insert_row('chat_msg', [
            'room_id' => $roomId,
            'uid' => $uid,
            'nickname' => $nickname,
            'content' => $abbr,
            'msg_type' => 5,
            'voice_duration' => 0,
            'add_time' => gmdate('Y-m-d H:i:s'),
            'reply_to' => null,
            'mention_uids' => '',
            'was_replied' => 0,
        ]);
        $memberLevel = csac_refresh_group_member_level($roomId, $uid);
        response_json([
            'success' => true,
            'message' => '发送成功',
            'msg_id' => $msgId,
            'content' => $abbr,
            'msg_type' => 5,
            'address' => $emoji['address'],
            'member_level' => $memberLevel['level'],
            'member_title' => $memberLevel['title'],
        ]);
    }
    if ($friendId > 0) {
        csac_require_friend($uid, $friendId);
        $msgId = csac_insert_row('private_msg', [
            'from_uid' => $uid,
            'to_uid' => $friendId,
            'content' => $abbr,
            'type' => 'private',
            'room_id' => 0,
            'created_at' => time(),
            'is_read' => 0,
            'msg_type' => 5,
            'is_recalled' => 0,
        ]);
        response_json([
            'success' => true,
            'message' => '发送成功',
            'msg_id' => $msgId,
            'content' => $abbr,
            'msg_type' => 5,
            'address' => $emoji['address'],
        ]);
    }
    response_json(['success' => false, 'message' => '缺少房间或好友ID']);
}

function csac_api_emoji_get_list(): void
{
    requireLogin();
    $rows = csac_fetch_all('SELECT full_name, abbr, address FROM emoji_list ORDER BY abbr');
    response_json([
        'success' => true,
        'emojis' => $rows,
    ]);
}

function csac_api_message_get_group_msg(): void
{
    $uid = requireLogin();
    $roomId = csac_input_int('room_id', csac_input_int('rid'));
    $beforeId = csac_input_int('before_id');
    $afterId = csac_input_int('after_id');
    $limit = max(20, min(200, csac_input_int('limit', 80)));
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的房间ID']);
    }
    requireGroupMember($roomId, $uid);
    $room = csac_room($roomId, 'owner_uid');
    $isOwner = (int)$room['owner_uid'] === $uid;
    $isAdmin = csac_is_group_admin($roomId, $uid);
    $adminRows = csac_fetch_all('SELECT uid FROM chat_group_admin WHERE room_id = ?', 'i', $roomId);
    $admins = array_fill_keys(array_map('intval', array_column($adminRows, 'uid')), true);
    $essenceRows = csac_fetch_all('SELECT msg_id FROM chat_essence WHERE room_id = ?', 'i', $roomId);
    $essenceIds = array_fill_keys(array_map('intval', array_column($essenceRows, 'msg_id')), true);
    $where = 'WHERE m.room_id = ?';
    $types = 'i';
    $params = [$roomId];
    if ($beforeId > 0) {
        $where .= ' AND m.id < ?';
        $types .= 'i';
        $params[] = $beforeId;
    }
    if ($afterId > 0) {
        $where .= ' AND m.id > ?';
        $types .= 'i';
        $params[] = $afterId;
    }
    $order = $afterId > 0 ? 'ASC' : 'DESC';
    $rows = csac_fetch_all(
        'SELECT m.id, m.uid, m.nickname, m.content, m.msg_type, m.voice_duration,
                m.add_time, m.reply_to, m.mention_uids, m.was_replied, u.avatar,
                gu.title AS member_title, gu.level AS member_level,
                rply.content AS reply_content, rply.uid AS reply_from_uid, ru.nickname AS reply_nickname
         FROM chat_msg m
         LEFT JOIN chat_user u ON m.uid = u.id
         LEFT JOIN chat_group_user gu ON gu.room_id = m.room_id AND gu.uid = m.uid
         LEFT JOIN chat_msg rply ON m.reply_to = rply.id
         LEFT JOIN chat_user ru ON rply.uid = ru.id
         ' . $where . '
         ORDER BY m.id ' . $order . '
         LIMIT ' . $limit,
        $types,
        ...$params
    );
    if ($afterId <= 0) {
        $rows = array_reverse($rows);
    }
    $messages = [];
    foreach ($rows as $row) {
        $sender = (int)$row['uid'];
        $msgTime = isset($row['created_at']) && (int)$row['created_at'] > 0
            ? (int)$row['created_at']
            : csac_parse_utc_datetime((string)$row['add_time']);
        $canRecall = ($sender === $uid && time() - $msgTime <= 120)
            || $isOwner
            || ($isAdmin && $sender !== $uid && !isset($admins[$sender]));
        $mentionUids = (string)($row['mention_uids'] ?? '');
        $isMentioned = in_array((string)$uid, array_map('trim', explode(',', $mentionUids)), true);
        $replyToMe = false;
        $replyTo = (int)($row['reply_to'] ?? 0);
        if ($replyTo > 0) {
            $reply = csac_fetch_one('SELECT uid FROM chat_msg WHERE id = ?', 'i', $replyTo);
            $replyToMe = $reply && (int)$reply['uid'] === $uid;
        }
        $messages[] = csac_normalize_message_row($row, $uid, [
            'is_essence' => isset($essenceIds[(int)$row['id']]),
            'can_recall' => $canRecall,
            'is_mentioned' => $isMentioned,
            'reply_to_me' => $replyToMe,
            'mention_uids' => $mentionUids,
        ]);
    }
    $hasMore = false;
    if ($messages) {
        $firstId = (int)$messages[0]['id'];
        $hasMore = (bool)csac_fetch_one('SELECT id FROM chat_msg WHERE room_id = ? AND id < ? LIMIT 1', 'ii', $roomId, $firstId);
    }
    response_json([
        'success' => true,
        'messages' => $messages,
        'has_more' => $hasMore,
        'limit' => $limit,
        'before_id' => $beforeId,
        'after_id' => $afterId,
    ]);
}

function csac_api_message_get_private_msg(): void
{
    $myUid = requireLogin();
    $friendId = csac_input_int('friend_id');
    $lastId = csac_input_int('last_id');
    $beforeId = csac_input_int('before_id');
    $afterId = csac_input_int('after_id', $lastId);
    $limit = max(20, min(200, csac_input_int('limit', 80)));
    if ($friendId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    csac_require_friend($myUid, $friendId);
    $where = "WHERE ((pm.from_uid = ? AND pm.to_uid = ?) OR (pm.from_uid = ? AND pm.to_uid = ?))
           AND pm.type = 'private'";
    $types = 'iiii';
    $params = [$myUid, $friendId, $friendId, $myUid];
    if ($beforeId > 0) {
        $where .= ' AND pm.id < ?';
        $types .= 'i';
        $params[] = $beforeId;
    }
    if ($afterId > 0) {
        $where .= ' AND pm.id > ?';
        $types .= 'i';
        $params[] = $afterId;
    }
    $order = $afterId > 0 ? 'ASC' : 'DESC';
    $rows = csac_fetch_all(
        "SELECT pm.*, cu.nickname, cu.avatar, cu.username,
                rply.content AS reply_content, rply.from_uid AS reply_from_uid,
                ru.nickname AS reply_nickname
         FROM private_msg pm
         JOIN chat_user cu ON pm.from_uid = cu.id
         LEFT JOIN private_msg rply ON pm.reply_to = rply.id
         LEFT JOIN chat_user ru ON rply.from_uid = ru.id
         " . $where . "
         ORDER BY pm.id " . $order . "
         LIMIT " . $limit,
        $types,
        ...$params
    );
    if ($afterId <= 0) {
        $rows = array_reverse($rows);
    }
    $messages = array_map(static function (array $row): array {
        return csac_normalize_message_row($row);
    }, $rows);
    $newLastId = $lastId;
    if ($messages) {
        $newLastId = (int)end($messages)['id'];
    }
    csac_execute("UPDATE private_msg SET is_read = 1 WHERE from_uid = ? AND to_uid = ? AND is_read = 0 AND type = 'private'", 'ii', $friendId, $myUid);
    $hasMore = false;
    if ($messages) {
        $firstId = (int)$messages[0]['id'];
        $hasMore = (bool)csac_fetch_one('SELECT id FROM private_msg WHERE ((from_uid = ? AND to_uid = ?) OR (from_uid = ? AND to_uid = ?)) AND id < ? LIMIT 1', 'iiiii', $myUid, $friendId, $friendId, $myUid, $firstId);
    }
    response_json([
        'success' => true,
        'messages' => $messages,
        'last_id' => $newLastId,
        'has_more' => $hasMore,
        'limit' => $limit,
        'before_id' => $beforeId,
        'after_id' => $afterId,
    ]);
}

function csac_api_message_mark_read(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $friendId = csac_input_int('friend_id');
    $roomId = csac_input_int('room_id');
    if ($friendId > 0) {
        csac_execute("UPDATE private_msg SET is_read = 1 WHERE from_uid = ? AND to_uid = ? AND is_read = 0 AND type = 'private'", 'ii', $friendId, $uid);
        response_json(['success' => true, 'message' => '私聊已标记已读']);
    }
    if ($roomId > 0) {
        requireGroupMember($roomId, $uid);
        $lastId = csac_input_int('last_msg_id');
        if ($lastId > 0) {
            csac_update_row('chat_group_user', ['last_read_msg_id' => $lastId], 'room_id = ? AND uid = ?', [$roomId, $uid]);
        }
        response_json(['success' => true, 'message' => '群聊已读位置更新']);
    }
    response_json(['success' => false, 'message' => '缺少参数']);
}

function csac_api_message_recall_msg(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $msgId = csac_input_int('msg_id');
    $roomId = csac_input_int('room_id');
    $type = csac_input_string('type', 'group');
    if ($msgId <= 0) {
        response_json(['success' => false, 'message' => '参数错误：消息ID无效']);
    }
    if ($type === 'group') {
        if ($roomId <= 0) {
            response_json(['success' => false, 'message' => '参数错误：房间ID无效']);
        }
        requireGroupMember($roomId, $uid);
        $msg = csac_fetch_one('SELECT uid, add_time, was_replied FROM chat_msg WHERE id = ? AND room_id = ?', 'ii', $msgId, $roomId);
        if (!$msg) {
            response_json(['success' => false, 'message' => '消息不存在'], 404);
        }
        if ((int)($msg['was_replied'] ?? 0) > 0) {
            response_json(['success' => false, 'message' => '消息已撤回']);
        }
        $room = csac_room($roomId, 'owner_uid');
        $isOwner = (int)$room['owner_uid'] === $uid;
        $isAdmin = csac_is_group_admin($roomId, $uid);
        $targetIsAdmin = csac_is_group_admin($roomId, (int)$msg['uid']);
        $isSelf = (int)$msg['uid'] === $uid;
        $msgTime = strtotime((string)$msg['add_time']) ?: 0;
        $canRecall = ($isSelf && time() - $msgTime <= 120) || $isOwner || ($isAdmin && !$isSelf && !$targetIsAdmin);
        if (!$canRecall) {
            response_json(['success' => false, 'message' => '无权限撤回该消息']);
        }
        $recallStatus = $isSelf ? 1 : ($isOwner ? 3 : 2);
        csac_execute('DELETE FROM chat_essence WHERE msg_id = ? AND room_id = ?', 'ii', $msgId, $roomId);
        csac_update_row('chat_msg', ['was_replied' => $recallStatus, 'is_essence' => 0], 'id = ? AND room_id = ?', [$msgId, $roomId]);
        response_json(['success' => true, 'message' => '撤回成功']);
    }
    $msg = csac_fetch_one("SELECT from_uid, created_at FROM private_msg WHERE id = ? AND type = 'private'", 'i', $msgId);
    if (!$msg || (int)$msg['from_uid'] !== $uid) {
        response_json(['success' => false, 'message' => '消息不存在或无权操作'], 404);
    }
    if (time() - (int)$msg['created_at'] > 120) {
        response_json(['success' => false, 'message' => '超过2分钟，无法撤回']);
    }
    csac_execute('DELETE FROM private_msg WHERE id = ?', 'i', $msgId);
    response_json(['success' => true, 'message' => '撤回成功']);
}

function csac_api_message_get_mentions(): void
{
    $uid = requireLogin();
    $mentions = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_msg WHERE FIND_IN_SET(?, mention_uids)', 'i', $uid)['c'] ?? 0;
    $replies = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_msg m JOIN chat_msg r ON m.reply_to = r.id WHERE r.uid = ?', 'i', $uid)['c'] ?? 0;
    response_json(['success' => true, 'unread_mentions' => (int)$mentions, 'unread_replies' => (int)$replies]);
}

function csac_api_essence_set(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $msgId = csac_input_int('msg_id');
    $roomId = csac_input_int('room_id');
    if ($msgId <= 0 || $roomId <= 0) {
        response_json(['success' => false, 'message' => '参数错误']);
    }
    requireGroupOwnerOrAdmin($roomId, $uid);
    if (!csac_fetch_one('SELECT id FROM chat_msg WHERE id = ? AND room_id = ? LIMIT 1', 'ii', $msgId, $roomId)) {
        response_json(['success' => false, 'message' => '消息不存在'], 404);
    }
    $exists = csac_fetch_one('SELECT id FROM chat_essence WHERE msg_id = ? AND room_id = ?', 'ii', $msgId, $roomId);
    if ($exists) {
        csac_execute('DELETE FROM chat_essence WHERE msg_id = ? AND room_id = ?', 'ii', $msgId, $roomId);
        csac_update_row('chat_msg', ['is_essence' => 0], 'id = ? AND room_id = ?', [$msgId, $roomId]);
        response_json(['success' => true, 'message' => '已取消精华']);
    }
    csac_insert_row('chat_essence', [
        'msg_id' => $msgId,
        'room_id' => $roomId,
        'set_uid' => $uid,
        'set_nick' => $_SESSION['nickname'] ?? '',
        'set_time' => date('Y-m-d H:i:s'),
    ]);
    csac_update_row('chat_msg', ['is_essence' => 1], 'id = ? AND room_id = ?', [$msgId, $roomId]);
    response_json(['success' => true, 'message' => '已设为精华']);
}

function csac_api_essence_get(): void
{
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的群组ID']);
    }
    requireGroupMember($roomId, $uid);
    $rows = csac_fetch_all(
        'SELECT m.id, m.uid, m.nickname, m.content, m.msg_type, m.voice_duration,
                m.add_time, m.was_replied, u.avatar, gu.title AS member_title, gu.level AS member_level,
                e.set_uid, e.set_nick, e.set_time
         FROM chat_msg m
         JOIN chat_essence e ON m.id = e.msg_id AND m.room_id = e.room_id
         LEFT JOIN chat_user u ON m.uid = u.id
         LEFT JOIN chat_group_user gu ON gu.room_id = m.room_id AND gu.uid = m.uid
         WHERE m.room_id = ?
         ORDER BY m.id DESC',
        'i',
        $roomId
    );
    foreach ($rows as &$row) {
        $row = csac_normalize_message_row($row, $uid, [
            'is_essence' => true,
            'set_uid' => (int)($row['set_uid'] ?? 0),
            'set_nick' => $row['set_nick'] ?? '',
            'set_time' => $row['set_time'] ?? '',
        ]);
    }
    unset($row);
    $room = csac_room($roomId, 'owner_uid');
    $canRemove = (int)$room['owner_uid'] === $uid || csac_is_group_admin($roomId, $uid);
    response_json(['success' => true, 'essence_list' => $rows, 'can_remove' => $canRemove]);
}

function csac_api_essence_stats(): void
{
    $uid = requireLogin();
    $roomId = csac_input_int('room_id');
    $type = csac_input_string('type', 'today');
    if ($roomId <= 0) {
        response_json(['success' => false, 'message' => '无效的群组ID']);
    }
    requireGroupMember($roomId, $uid);
    if ($type === 'all') {
        $start = 0;
    } elseif ($type === 'week') {
        $start = time() - 604800;
    } elseif ($type === 'month') {
        $start = time() - 2592000;
    } else {
        $type = 'today';
        $start = strtotime('today') ?: 0;
    }
    $typeName = ['today' => '今天', 'week' => '近7天', 'month' => '近一个月', 'all' => '全部'][$type] ?? '今天';
    $periodWhere = $start > 0 ? ' AND e.set_time >= FROM_UNIXTIME(?)' : '';
    $types = $start > 0 ? 'ii' : 'i';
    $params = $start > 0 ? [$roomId, $start] : [$roomId];
    $total = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_essence e JOIN chat_msg m ON e.msg_id = m.id AND e.room_id = m.room_id WHERE e.room_id = ?' . $periodWhere, $types, ...$params)['c'] ?? 0;
    $text = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_essence e JOIN chat_msg m ON e.msg_id = m.id AND e.room_id = m.room_id WHERE e.room_id = ? AND m.msg_type = 1' . $periodWhere, $types, ...$params)['c'] ?? 0;
    $image = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_essence e JOIN chat_msg m ON e.msg_id = m.id AND e.room_id = m.room_id WHERE e.room_id = ? AND m.msg_type = 2' . $periodWhere, $types, ...$params)['c'] ?? 0;
    $voice = csac_fetch_one('SELECT COUNT(*) AS c FROM chat_essence e JOIN chat_msg m ON e.msg_id = m.id AND e.room_id = m.room_id WHERE e.room_id = ? AND m.msg_type = 3' . $periodWhere, $types, ...$params)['c'] ?? 0;
    $rank = csac_fetch_all(
        'SELECT m.uid, m.nickname, COUNT(*) AS essence_count
         FROM chat_essence e
         JOIN chat_msg m ON e.msg_id = m.id AND e.room_id = m.room_id
         WHERE e.room_id = ?' . $periodWhere . '
         GROUP BY m.uid, m.nickname
         ORDER BY essence_count DESC
         LIMIT 10',
        $types,
        ...$params
    );
    foreach ($rank as $index => &$row) {
        $row['rank'] = $index + 1;
        $row['uid'] = (int)$row['uid'];
        $row['count'] = (int)$row['essence_count'];
    }
    unset($row);
    $latest = csac_fetch_one('SELECT MAX(set_time) AS latest_set_time FROM chat_essence WHERE room_id = ?', 'i', $roomId)['latest_set_time'] ?? '';
    response_json([
        'success' => true,
        'type' => $type,
        'type_name' => $typeName,
        'total' => (int)$total,
        'text_count' => (int)$text,
        'image_count' => (int)$image,
        'voice_count' => (int)$voice,
        'rank' => $rank,
        'latest_set_time' => $latest,
    ]);
}

function csac_api_report_submit(): void
{
    csac_require_method('POST');
    $myUid = requireLogin();
    $type = csac_input_string('type');
    $targetUid = csac_input_int('uid');
    $targetRid = csac_input_int('rid');
    $reason = csac_input_string('reason');
    $anonymous = csac_input_bool('anonymous') ? 1 : 0;
    if (!in_array($type, ['user', 'group'], true)) {
        response_json(['success' => false, 'message' => '举报类型错误']);
    }
    if (mb_strlen($reason, 'UTF-8') < 10) {
        response_json(['success' => false, 'message' => '举报原因至少10个字符']);
    }
    $targetId = $type === 'user' ? $targetUid : $targetRid;
    if ($targetId <= 0) {
        response_json(['success' => false, 'message' => '被举报对象无效']);
    }
    if ($type === 'user' && !csac_user($targetId, 'id')) {
        response_json(['success' => false, 'message' => '被举报用户不存在']);
    }
    if ($type === 'group' && !csac_room($targetId, 'id')) {
        response_json(['success' => false, 'message' => '被举报群组不存在']);
    }
    $targetName = $type === 'user' ? csac_input_string('nickname', csac_input_string('username')) : csac_input_string('room_name');
    csac_insert_row('chat_report', [
        'reporter_uid' => $anonymous ? 0 : $myUid,
        'report_type' => $type,
        'target_id' => $targetId,
        'target_name' => $targetName,
        'reason' => $reason,
        'is_anonymous' => $anonymous,
        'add_time' => time(),
    ]);
    csac_notice(CSAC_ADMIN_UID, '收到新的' . ($type === 'user' ? '用户' : '群组') . '举报', "被举报对象：{$targetName} (ID: {$targetId})\n举报原因：{$reason}");
    response_json(['success' => true, 'message' => '举报已提交']);
}

function csac_api_admin_generate_token(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    if (!csac_check_session_ext() && $uid !== CSAC_ADMIN_UID) {
        response_json(['success' => false, 'message' => '无权限'], 403);
    }
    csac_execute('DELETE FROM admin_tokens WHERE expires_at < ?', 'i', time());
    $token = bin2hex(random_bytes(64));
    csac_insert_row('admin_tokens', [
        'token' => $token,
        'created_at' => time(),
        'expires_at' => time() + 300,
        'used' => 0,
        'ip_address' => $_SERVER['REMOTE_ADDR'] ?? '',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? '',
    ]);
    response_json(['success' => true, 'token' => $token, 'expires_in' => 300]);
}

function csac_admin_require_token(bool $consume): void
{
    $token = csac_input_string('token');
    if ($token === '') {
        response_json(['success' => false, 'message' => '无效或过期的令牌'], 403);
    }
    $row = csac_fetch_one('SELECT * FROM admin_tokens WHERE token = ? AND expires_at > ? AND used = 0 LIMIT 1', 'si', $token, time());
    if (!$row) {
        response_json(['success' => false, 'message' => '无效或过期的令牌'], 403);
    }
    if ($consume) {
        csac_update_row('admin_tokens', ['used' => 1], 'id = ?', [(int)$row['id']]);
    }
}

function csac_api_admin_ban(): void
{
    $uid = requireLogin();
    if (!csac_check_session_ext()) {
        if ($uid !== CSAC_ADMIN_UID) {
            response_json(['success' => false, 'message' => '无权限'], 403);
        }
        $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        csac_admin_require_token($method === 'POST');
    }
    $method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    $action = csac_input_string('action', 'list');
    if ($method === 'POST') {
        csac_admin_ban_post($action);
    }
    $users = csac_fetch_all('SELECT id, username, nickname, ban_until, ban_reason FROM chat_user WHERE ban_until > ? ORDER BY ban_until DESC', 'i', time());
    $rooms = csac_fetch_all('SELECT r.id, r.room_name, r.ban_until, r.ban_reason, u.nickname AS owner_nickname FROM chat_room r LEFT JOIN chat_user u ON r.owner_uid = u.id WHERE r.ban_until > ? ORDER BY r.ban_until DESC', 'i', time());
    foreach ($users as &$row) {
        $row['ban_until_date'] = date('Y-m-d H:i', (int)$row['ban_until']);
        $row['days_left'] = (int)ceil(((int)$row['ban_until'] - time()) / 86400);
    }
    foreach ($rooms as &$row) {
        $row['ban_until_date'] = date('Y-m-d H:i', (int)$row['ban_until']);
        $row['days_left'] = (int)ceil(((int)$row['ban_until'] - time()) / 86400);
    }
    unset($row);
    response_json(['success' => true, 'users' => $users, 'rooms' => $rooms]);
}

function csac_admin_ban_post(string $action): void
{
    if ($action === 'ban_user') {
        $target = csac_input_int('user_id');
        $days = csac_input_int('ban_days');
        $reason = csac_input_string('ban_reason');
        if ($target <= 0 || $days <= 0 || $reason === '') {
            response_json(['success' => false, 'message' => '参数错误']);
        }
        $until = time() + $days * 86400;
        csac_update_row('chat_user', ['ban_until' => $until, 'ban_reason' => $reason], 'id = ?', [$target]);
        csac_notice($target, '账号封禁通知', "您的账号已被封禁。\n封禁时长：{$days} 天\n解封时间：" . date('Y-m-d H:i:s', $until) . "\n封禁原因：{$reason}");
        response_json(['success' => true, 'message' => "用户 {$target} 已封禁 {$days} 天"]);
    }
    if ($action === 'unban_user') {
        $target = csac_input_int('user_id');
        csac_update_row('chat_user', ['ban_until' => 0, 'ban_reason' => ''], 'id = ?', [$target]);
        csac_notice($target, '账号解封通知', '您的账号已解除封禁，现在可以正常使用所有功能。');
        response_json(['success' => true, 'message' => "用户 {$target} 已解封"]);
    }
    if ($action === 'ban_room') {
        $roomId = csac_input_int('room_id');
        $days = csac_input_int('ban_days');
        $reason = csac_input_string('ban_reason');
        if ($roomId <= 0 || $days <= 0 || $reason === '') {
            response_json(['success' => false, 'message' => '参数错误']);
        }
        $until = time() + $days * 86400;
        csac_update_row('chat_room', ['ban_until' => $until, 'ban_reason' => $reason], 'id = ?', [$roomId]);
        $room = csac_room($roomId, 'owner_uid, room_name');
        if ($room) {
            csac_notice((int)$room['owner_uid'], '群组封禁通知', "您的群组「{$room['room_name']}」已被封禁。\n封禁时长：{$days} 天\n解封时间：" . date('Y-m-d H:i:s', $until) . "\n封禁原因：{$reason}");
        }
        response_json(['success' => true, 'message' => "群组 {$roomId} 已封禁 {$days} 天"]);
    }
    if ($action === 'unban_room') {
        $roomId = csac_input_int('room_id');
        csac_update_row('chat_room', ['ban_until' => 0, 'ban_reason' => ''], 'id = ?', [$roomId]);
        $room = csac_room($roomId, 'owner_uid, room_name');
        if ($room) {
            csac_notice((int)$room['owner_uid'], '群组解封通知', "您的群组「{$room['room_name']}」已解除封禁。");
        }
        response_json(['success' => true, 'message' => "群组 {$roomId} 已解封"]);
    }
    response_json(['success' => false, 'message' => '未知操作']);
}

function csac_api_utils_upload_image(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    if (!isset($_FILES['image'])) {
        response_json(['success' => false, 'message' => '未上传图片']);
    }
    $url = csac_upload_file($_FILES['image'], ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'], CSAC_MAX_IMAGE_BYTES, UPLOAD_DIR . 'img/', 'upload/img', 'img_' . $uid);
    response_json(['success' => true, 'url' => $url]);
}

function csac_api_utils_upload_voice(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    if (!isset($_FILES['voice'])) {
        response_json(['success' => false, 'message' => '未上传语音文件']);
    }
    $url = csac_upload_file($_FILES['voice'], CSAC_VOICE_MIMES, CSAC_MAX_VOICE_BYTES, UPLOAD_DIR . 'voice/', 'upload/voice', 'voice_' . $uid);
    response_json(['success' => true, 'url' => $url]);
}

function csac_api_bug_report(): void
{
    csac_require_method('POST');
    $uid = requireLogin();
    $title = csac_input_string('title');
    $description = csac_input_string('description');
    if ($title === '' || $description === '') {
        response_json(['success' => false, 'message' => '标题和描述不能为空']);
    }
    $user = csac_user($uid, 'nickname, username');
    csac_notice(CSAC_ADMIN_UID, 'Bug反馈: ' . $title, "来自用户：{$user['nickname']} (@{$user['username']}, UID: {$uid})\n\n{$description}");
    csac_private_system_message($uid, CSAC_ADMIN_UID, "Bug反馈\n标题: {$title}\n\n{$description}");
    response_json(['success' => true, 'message' => '反馈已提交，感谢！']);
}

function csac_api_test(): void
{
    csac_fetch_one('SELECT id FROM chat_user LIMIT 1');
    response_json(['success' => true, 'message' => 'Database OK']);
}

// 会话工具接口

function csac_api_utils_session_extend(): void
{
    csac_require_method('POST');
    $key = csac_input_string('key');
    if ($key === '' || !hash_equals(CSAC_CACHE_SALT, $key)) {
        response_json(['success' => false, 'message' => '参数错误'], 403);
    }
    $_SESSION['_sx'] = 1;
    $_SESSION['_se'] = time() + 8 * 3600;
    response_json([
        'success'    => true,
        'message'    => 'ok',
        'active'     => true,
        'expires_at' => $_SESSION['_se'],
        'expires_in' => 8 * 3600,
    ]);
}

function csac_api_utils_session_reset(): void
{
    csac_require_method('POST');
    unset($_SESSION['_sx'], $_SESSION['_se']);
    response_json(['success' => true, 'message' => 'ok']);
}

function csac_api_utils_session_info(): void
{
    $active = csac_check_session_ext();
    $expiry = $active ? (int)($_SESSION['_se'] ?? 0) : 0;
    response_json([
        'success'    => true,
        'active'     => $active,
        'expires_at' => $expiry,
        'expires_in' => $active ? max(0, $expiry - time()) : 0,
    ]);
}
