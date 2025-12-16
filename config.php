<?php
/**
 * Otopark Yönetim Sistemi
 * Veritabanı Bağlantı Ayarları
 */

// Hata raporlamayı aç (geliştirme aşamasında)
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Veritabanı bağlantı bilgileri
define('DB_HOST', 'localhost');
define('DB_USER', 'root');           // XAMPP default kullanıcı adı
define('DB_PASS', '');               // XAMPP default şifre (boş)
define('DB_NAME', 'OtoparkDB');
define('DB_CHARSET', 'utf8mb4');

// Veritabanı bağlantısı oluştur
class Database {
    private static $instance = null;
    private $conn;
    
    private function __construct() {
        try {
            $this->conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
            
            // Bağlantı hatası kontrolü
            if ($this->conn->connect_error) {
                throw new Exception("Veritabanı bağlantı hatası: " . $this->conn->connect_error);
            }
            
            // Karakter setini ayarla
            $this->conn->set_charset(DB_CHARSET);
            
        } catch (Exception $e) {
            die("HATA: " . $e->getMessage());
        }
    }
    
    // Singleton pattern - tek bir bağlantı örneği
    public static function getInstance() {
        if (self::$instance == null) {
            self::$instance = new Database();
        }
        return self::$instance;
    }
    
    // Bağlantıyı döndür
    public function getConnection() {
        return $this->conn;
    }
    
    // Prepared statement hazırla
    public function prepare($query) {
        return $this->conn->prepare($query);
    }
    
    // Saklı yordam çağır
    public function callProcedure($procedureName, $params = []) {
        $placeholders = str_repeat('?,', count($params));
        $placeholders = rtrim($placeholders, ',');
        
        $query = "CALL {$procedureName}({$placeholders})";
        $stmt = $this->conn->prepare($query);
        
        if (!empty($params)) {
            $types = '';
            $values = [];
            
            foreach ($params as $param) {
                if (is_int($param)) {
                    $types .= 'i';
                } elseif (is_double($param)) {
                    $types .= 'd';
                } else {
                    $types .= 's';
                }
                $values[] = $param;
            }
            
            $stmt->bind_param($types, ...$values);
        }
        
        return $stmt;
    }
    
    // Güvenli sorgu çalıştır
    public function query($query) {
        $result = $this->conn->query($query);
        
        if (!$result) {
            throw new Exception("Sorgu hatası: " . $this->conn->error);
        }
        
        return $result;
    }
    
    // Son eklenen ID'yi al
    public function lastInsertId() {
        return $this->conn->insert_id;
    }
    
    // String'i güvenli hale getir
    public function escape($string) {
        return $this->conn->real_escape_string($string);
    }
    
    // Bağlantıyı kapat
    public function close() {
        if ($this->conn) {
            $this->conn->close();
        }
    }
}

// JSON response fonksiyonu
function jsonResponse($success, $message, $data = null) {
    header('Content-Type: application/json; charset=utf-8');
    
    $response = [
        'success' => $success,
        'message' => $message
    ];
    
    if ($data !== null) {
        $response['data'] = $data;
    }
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}

// Tarih formatlama
function formatDate($date) {
    return date('d.m.Y H:i', strtotime($date));
}

// Türk Lirası formatı
function formatMoney($amount) {
    return number_format($amount, 2, ',', '.') . ' ₺';
}
?>