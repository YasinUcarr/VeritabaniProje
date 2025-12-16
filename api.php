<?php
/**

 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config.php';


header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit; 
}

$db = Database::getInstance();
$conn = $db->getConnection();


function callProcedureAndFetchAll($conn, $procedureName, $params = []) {
    
    $escaped = [];
    foreach ($params as $p) {
       
        if ($p === null) {
            $escaped[] = 'NULL';
            continue;
        }
        
        if (is_int($p) || is_float($p)) {
            $escaped[] = $p;
        } else {
            
            $escaped[] = "'" . $conn->real_escape_string((string)$p) . "'";
        }
    }
    $paramStr = implode(',', $escaped);
    $sql = "CALL {$procedureName}({$paramStr})";

    $rows = [];
    if (!$conn->multi_query($sql)) {
        throw new Exception("Procedure çağrı hatası: " . $conn->error . " — SQL: {$sql}");
    }

    
    if ($result = $conn->store_result()) {
        while ($r = $result->fetch_assoc()) {
            $rows[] = $r;
        }
        $result->free_result();
    }

    
    while ($conn->more_results() && $conn->next_result()) {
        if ($extra = $conn->store_result()) {
            $extra->free_result();
        }
    }

    return $rows;
}


function jsonResponseAPI($success, $message, $data = null) {
    header('Content-Type: application/json; charset=utf-8');
    $response = ['success' => $success, 'message' => (string)$message];
    if ($data !== null) $response['data'] = $data;
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    exit;
}


function getParam($name, $default = null) {
    if (isset($_POST[$name])) return $_POST[$name];
    if (isset($_GET[$name])) return $_GET[$name];
    return $default;
}

$action = isset($_GET['action']) ? $_GET['action'] : '';

try {
    switch ($action) {

        // -----------------------------
        // MÜŞTERİ İŞLEMLERİ
        // -----------------------------
        case 'musteri_ekle':
            $ad = getParam('ad', '');
            $soyad = getParam('soyad', '');
            $tc = getParam('tc', '');
            $telefon = getParam('telefon', '');
            $email = getParam('email', '');
            $adres = getParam('adres', null);

            $rows = callProcedureAndFetchAll($conn, 'sp_MusteriEkle', [$ad, $soyad, $tc, $telefon, $email, $adres]);
            
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, 'Müşteri eklendi', $row);
            break;

        case 'musteri_listele':
            $res = $db->query("SELECT * FROM MUSTERI ORDER BY MusteriID DESC");
            $data = [];
            while ($r = $res->fetch_assoc()) $data[] = $r;
            jsonResponseAPI(true, 'Müşteriler listelendi', $data);
            break;

        case 'musteri_ara':
            $arama = getParam('arama', '');
            $rows = callProcedureAndFetchAll($conn, 'sp_MusteriAra', [$arama]);
            jsonResponseAPI(true, 'Arama sonuçları', $rows);
            break;


        // -----------------------------
        // ARAÇ İŞLEMLERİ
        // -----------------------------
        case 'arac_ekle':
            $musteriID = (int)getParam('musteri_id', 0);
            $plaka = strtoupper((string)getParam('plaka', ''));
            $marka = getParam('marka', '');
            $model = getParam('model', '');
            $renk = getParam('renk', '');
            $aracTipi = getParam('arac_tipi', 'Otomobil');

            $rows = callProcedureAndFetchAll($conn, 'sp_AracEkle', [$musteriID, $plaka, $marka, $model, $renk, $aracTipi]);
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, 'Araç eklendi', $row);
            break;
          case 'hizli_arac_ekle':
    $plaka = strtoupper(getParam('plaka', ''));
    $marka = getParam('marka', 'Bilinmiyor');
    $model = getParam('model', 'Bilinmiyor');
    $renk = getParam('renk', 'Bilinmiyor');
    $musteriID = 0;

    // Plaka zaten var mı sorgu
    $plakaEscaped = $conn->real_escape_string($plaka);
    $check = $conn->query("SELECT AracID FROM ARAC WHERE Plaka = '$plakaEscaped'");

    if ($check && $check->num_rows > 0) {
        jsonResponseAPI(true, "Araç zaten kayıtlı", []);
    }

    // Araç ekle
    $stmt = $conn->prepare("
        INSERT INTO ARAC (MusteriID, Plaka, Marka, Model, Renk)
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt->bind_param("issss", $musteriID, $plaka, $marka, $model, $renk);
    $stmt->execute();

    if ($stmt->error) {
        jsonResponseAPI(false, "SQL Hatası: ".$stmt->error);
    }

    jsonResponseAPI(true, "Araç başarıyla kaydedildi!", [
        'AracID' => $conn->insert_id
    ]);
    break;


        case 'arac_listele':
            $musteriID = (int)getParam('musteri_id', 0);
            if ($musteriID > 0) {
                $rows = callProcedureAndFetchAll($conn, 'sp_MusteriAraclari', [$musteriID]);
                jsonResponseAPI(true, 'Araçlar listelendi', $rows);
            } else {
                $res = $db->query("SELECT a.*, m.Ad, m.Soyad FROM ARAC a JOIN MUSTERI m ON a.MusteriID = m.MusteriID ORDER BY a.AracID DESC");
                $data = [];
                while ($r = $res->fetch_assoc()) $data[] = $r;
                jsonResponseAPI(true, 'Araçlar listelendi', $data);
            }
            break;


        // -----------------------------
        // GİRİŞ-ÇIKIŞ İŞLEMLERİ
        // -----------------------------
        case 'arac_giris':
            $plaka = strtoupper((string)getParam('plaka', ''));
            $katNo = (int)getParam('kat_no', 0);
            $yerNumarasi = (int)getParam('yer_numarasi', 0);

            // Basit validation
            if (!$plaka || $katNo <= 0 || $yerNumarasi <= 0) {
                jsonResponseAPI(false, 'Eksik/Geçersiz parametreler (plaka/kat_no/yer_numarasi).');
            }

            $rows = callProcedureAndFetchAll($conn, 'sp_AracGiris', [$plaka, $katNo, $yerNumarasi]);
            $row = isset($rows[0]) ? $rows[0] : null;

            if ($row && isset($row['Mesaj']) && mb_stripos($row['Mesaj'], 'hata') !== false) {
                jsonResponseAPI(false, $row['Mesaj'], $row);
            } else {
                jsonResponseAPI(true, $row['Mesaj'] ?? 'Araç girişi yapıldı', $row);
            }
            break;

        case 'arac_cikis':
            $plaka = strtoupper((string)getParam('plaka', ''));
            if (!$plaka) jsonResponseAPI(false, 'Plaka giriniz.');

            $rows = callProcedureAndFetchAll($conn, 'sp_AracCikis', [$plaka]);
            $row = isset($rows[0]) ? $rows[0] : null;

            if ($row && isset($row['Mesaj']) && mb_stripos($row['Mesaj'], 'hata') !== false) {
                jsonResponseAPI(false, $row['Mesaj'], $row);
            } else {
                jsonResponseAPI(true, $row['Mesaj'] ?? 'Çıkış yapıldı', $row);
            }
            break;

        case 'aktif_araclar':
            $rows = callProcedureAndFetchAll($conn, 'sp_AktifAraclar', []);
            
            jsonResponseAPI(true, 'Aktif araçlar', $rows);
            break;


        // -----------------------------
        // ÖDEME
        // -----------------------------
        case 'odeme_yap':
            $islemID = (int)getParam('islem_id', 0);
            $odemeTipi = getParam('odeme_tipi', 'Nakit');
            if ($islemID <= 0) jsonResponseAPI(false, 'Geçersiz IslemID.');

            $rows = callProcedureAndFetchAll($conn, 'sp_OdemeYap', [$islemID, $odemeTipi]);
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, $row['Mesaj'] ?? 'Ödeme işlendi', $row);
            break;

        case 'odenmemis_islemler':
            $rows = callProcedureAndFetchAll($conn, 'sp_OdenmemisIslemler', []);
            jsonResponseAPI(true, 'Ödenmemiş işlemler', $rows);
            break;


        // -----------------------------
        // ABONELİK
        // -----------------------------
        case 'abonelik_ekle':
            $musteriID = (int)getParam('musteri_id', 0);
            $abonelikTipi = getParam('abonelik_tipi', 'Aylık');
            if ($musteriID <= 0) jsonResponseAPI(false, 'Geçersiz MusteriID.');

            $rows = callProcedureAndFetchAll($conn, 'sp_AbonelikEkle', [$musteriID, $abonelikTipi]);
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, $row['Mesaj'] ?? 'Abonelik eklendi', $row);
            break;

        case 'abonelik_listele':
            $res = $db->query("SELECT a.*, m.Ad, m.Soyad, m.Telefon FROM ABONELIK a JOIN MUSTERI m ON a.MusteriID = m.MusteriID ORDER BY a.AbonelikID DESC");
            $data = [];
            while ($r = $res->fetch_assoc()) $data[] = $r;
            jsonResponseAPI(true, 'Abonelikler', $data);
            break;


        // -----------------------------
        // PARK YERI
        // -----------------------------
        case 'bos_park_yerleri':
            $rows = callProcedureAndFetchAll($conn, 'sp_BosParkYerleri', []);
            jsonResponseAPI(true, 'Boş park yerleri', $rows);
            break;

        case 'park_yerleri':
            $katNo = (int)getParam('kat_no', 0);
            if ($katNo > 0) {
                $res = $db->query("SELECT * FROM PARK_YERI WHERE KatNo = {$katNo} ORDER BY YerNumarasi");
            } else {
                $res = $db->query("SELECT * FROM PARK_YERI ORDER BY KatNo, YerNumarasi");
            }
            $data = [];
            while ($r = $res->fetch_assoc()) $data[] = $r;
            jsonResponseAPI(true, 'Park yerleri', $data);
            break;

        case 'doluluk_orani':
            $rows = callProcedureAndFetchAll($conn, 'sp_DolulukOrani', []);
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, 'Doluluk oranı', $row);
            break;

        case 'kat_bazli_doluluk':
            $rows = callProcedureAndFetchAll($conn, 'sp_KatBazliDoluluk', []);
            jsonResponseAPI(true, 'Kat bazlı doluluk', $rows);
            break;


        // -----------------------------
        // PERSONEL & VARDİYA
        // -----------------------------
        case 'personel_ekle':
            $ad = getParam('ad', '');
            $soyad = getParam('soyad', '');
            $tc = getParam('tc', '');
            $telefon = getParam('telefon', '');
            $pozisyon = getParam('pozisyon', 'Görevli');
            $maas = (float)getParam('maas', 0);

            $rows = callProcedureAndFetchAll($conn, 'sp_PersonelEkle', [$ad, $soyad, $tc, $telefon, $pozisyon, $maas]);
            $row = isset($rows[0]) ? $rows[0] : null;
            jsonResponseAPI(true, $row['Mesaj'] ?? 'Personel eklendi', $row);
            break;

        case 'personel_listele':
            $res = $db->query("SELECT * FROM PERSONEL ORDER BY PersonelID DESC");
            $data = [];
            while ($r = $res->fetch_assoc()) $data[] = $r;
            jsonResponseAPI(true, 'Personeller', $data);
            break;

        case 'vardiya_ekle':
            $personelID = (int)getParam('personel_id', 0);
            $vardiyaTarihi = getParam('vardiya_tarihi', date('Y-m-d'));
            $vardiyaTipi = getParam('vardiya_tipi', 'Sabah');
            $rows = callProcedureAndFetchAll($conn, 'sp_VardiyaEkle', [$personelID, $vardiyaTarihi, $vardiyaTipi]);
            jsonResponseAPI(true, 'Vardiya eklendi', isset($rows[0]) ? $rows[0] : null);
            break;


        // -----------------------------
        // RAPORLAR / DASHBOARD
        // -----------------------------
        case 'gunluk_gelir':
            $tarih = getParam('tarih', date('Y-m-d'));
            $rows = callProcedureAndFetchAll($conn, 'sp_GunlukGelir', [$tarih]);
            jsonResponseAPI(true, 'Günlük gelir', isset($rows[0]) ? $rows[0] : null);
            break;

        case 'aylik_gelir':
            $yil = (int)getParam('yil', date('Y'));
            $ay = (int)getParam('ay', date('m'));
            $rows = callProcedureAndFetchAll($conn, 'sp_AylikGelir', [$yil, $ay]);
            jsonResponseAPI(true, 'Aylık gelir', $rows);
            break;

        case 'en_sadik_musteriler':
            $limit = (int)getParam('limit', 10);
            $rows = callProcedureAndFetchAll($conn, 'sp_EnSadikMusteriler', [$limit]);
            jsonResponseAPI(true, 'En sadık müşteriler', $rows);
            break;

        case 'arac_tipi_istatistik':
            $rows = callProcedureAndFetchAll($conn, 'sp_AracTipiIstatistik', []);
            jsonResponseAPI(true, 'Araç tipi istatistikleri', $rows);
            break;

        case 'dashboard_istatistik':
            $stats = [];
            $res = $db->query("SELECT COUNT(*) as sayi FROM MUSTERI");
            $stats['toplam_musteri'] = $res->fetch_assoc()['sayi'] ?? 0;

            $res = $db->query("SELECT COUNT(*) as sayi FROM ARAC");
            $stats['toplam_arac'] = $res->fetch_assoc()['sayi'] ?? 0;

            $res = $db->query("SELECT COUNT(*) as sayi FROM GIRIS_CIKIS WHERE CikisTarihi IS NULL");
            $stats['aktif_arac'] = $res->fetch_assoc()['sayi'] ?? 0;

            $res = $db->query("SELECT COUNT(*) as sayi FROM ABONELIK WHERE Durum = 'Aktif'");
            $stats['aktif_abonelik'] = $res->fetch_assoc()['sayi'] ?? 0;

            $rows = callProcedureAndFetchAll($conn, 'sp_DolulukOrani', []);
            $stats['doluluk'] = isset($rows[0]) ? $rows[0] : null;

            $rows = callProcedureAndFetchAll($conn, 'sp_GunlukGelir', [date('Y-m-d')]);
            $stats['bugun_gelir'] = isset($rows[0]) ? $rows[0] : null;

            jsonResponseAPI(true, 'Dashboard istatistikleri', $stats);
            break;


        default:
            jsonResponseAPI(false, 'Geçersiz işlem!');
            break;
    }
} catch (Exception $e) {
    // Hata mesajını dön (geliştirme aşamasında)
    jsonResponseAPI(false, 'Hata: ' . $e->getMessage());
}

// Kapat
$db->close();
