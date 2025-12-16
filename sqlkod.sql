-- ====================================
-- OTOPARK YÖNETİM SİSTEMİ VERİTABANI
-- ====================================

DROP DATABASE IF EXISTS OtoparkDB;
CREATE DATABASE OtoparkDB CHARACTER SET utf8mb4 COLLATE utf8mb4_turkish_ci;
USE OtoparkDB;

-- ====================================
-- TABLOLARIN OLUŞTURULMASI
-- ====================================

-- MUSTERI Tablosu
CREATE TABLE MUSTERI (
    MusteriID INT AUTO_INCREMENT PRIMARY KEY,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    TCKimlikNo CHAR(11) UNIQUE NOT NULL,
    Telefon VARCHAR(15) NOT NULL,
    Email VARCHAR(100),
    KayitTarihi DATE NOT NULL DEFAULT (CURRENT_DATE),
    Adres TEXT,
    INDEX idx_tc (TCKimlikNo),
    INDEX idx_telefon (Telefon)
);

-- ARAC Tablosu
CREATE TABLE ARAC (
    AracID INT AUTO_INCREMENT PRIMARY KEY,
    MusteriID INT NOT NULL,
    Plaka VARCHAR(15) UNIQUE NOT NULL,
    Marka VARCHAR(50) NOT NULL,
    Model VARCHAR(50),
    Renk VARCHAR(30),
    AracTipi ENUM('Otomobil', 'SUV', 'Minivan', 'Motosiklet') DEFAULT 'Otomobil',
    FOREIGN KEY (MusteriID) REFERENCES MUSTERI(MusteriID) ON DELETE CASCADE,
    INDEX idx_plaka (Plaka),
    INDEX idx_musteri (MusteriID)
);

-- ABONELIK Tablosu
CREATE TABLE ABONELIK (
    AbonelikID INT AUTO_INCREMENT PRIMARY KEY,
    MusteriID INT NOT NULL,
    AbonelikTipi ENUM('Aylık', 'Yıllık') NOT NULL,
    BaslangicTarihi DATE NOT NULL,
    BitisTarihi DATE NOT NULL,
    Ucret DECIMAL(10,2) NOT NULL,
    Durum ENUM('Aktif', 'Pasif', 'İptal') DEFAULT 'Aktif',
    FOREIGN KEY (MusteriID) REFERENCES MUSTERI(MusteriID) ON DELETE CASCADE,
    INDEX idx_durum (Durum),
    INDEX idx_tarih (BaslangicTarihi, BitisTarihi)
);

-- PARK_YERI Tablosu
CREATE TABLE PARK_YERI (
    ParkYeriID INT AUTO_INCREMENT PRIMARY KEY,
    KatNo INT NOT NULL CHECK (KatNo BETWEEN 1 AND 5),
    YerNumarasi INT NOT NULL,
    Durum ENUM('Boş', 'Dolu', 'Bakımda') DEFAULT 'Boş',
    AracTipiUygun VARCHAR(50) DEFAULT 'Tümü',
    UNIQUE KEY unique_park (KatNo, YerNumarasi),
    INDEX idx_durum (Durum)
);

-- GIRIS_CIKIS Tablosu
CREATE TABLE GIRIS_CIKIS (
    IslemID INT AUTO_INCREMENT PRIMARY KEY,
    AracID INT NOT NULL,
    ParkYeriID INT NOT NULL,
    GirisTarihi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CikisTarihi DATETIME,
    ToplamSure INT,
    Ucret DECIMAL(10,2),
    FOREIGN KEY (AracID) REFERENCES ARAC(AracID) ON DELETE CASCADE,
    FOREIGN KEY (ParkYeriID) REFERENCES PARK_YERI(ParkYeriID),
    INDEX idx_giris (GirisTarihi),
    INDEX idx_arac (AracID)
);

-- ODEME Tablosu
CREATE TABLE ODEME (
    OdemeID INT AUTO_INCREMENT PRIMARY KEY,
    IslemID INT NOT NULL,
    OdemeTarihi DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    OdemeTipi ENUM('Nakit', 'Kredi Kartı', 'Havale') NOT NULL,
    Tutar DECIMAL(10,2) NOT NULL,
    OdemeDurumu ENUM('Ödendi', 'Beklemede', 'İptal') DEFAULT 'Beklemede',
    FOREIGN KEY (IslemID) REFERENCES GIRIS_CIKIS(IslemID) ON DELETE CASCADE,
    INDEX idx_durum (OdemeDurumu),
    INDEX idx_tarih (OdemeTarihi)
);

-- PERSONEL Tablosu
CREATE TABLE PERSONEL (
    PersonelID INT AUTO_INCREMENT PRIMARY KEY,
    Ad VARCHAR(50) NOT NULL,
    Soyad VARCHAR(50) NOT NULL,
    TCKimlikNo CHAR(11) UNIQUE NOT NULL,
    Telefon VARCHAR(15) NOT NULL,
    Pozisyon ENUM('Görevli', 'Yönetici', 'Güvenlik') NOT NULL,
    Maas DECIMAL(10,2) NOT NULL,
    IseGirisTarihi DATE NOT NULL,
    INDEX idx_pozisyon (Pozisyon)
);

-- VARDIYA Tablosu
CREATE TABLE VARDIYA (
    VardiyaID INT AUTO_INCREMENT PRIMARY KEY,
    PersonelID INT NOT NULL,
    VardiyaTarihi DATE NOT NULL,
    BaslangicSaati TIME NOT NULL,
    BitisSaati TIME NOT NULL,
    VardiyaTipi ENUM('Sabah', 'Öğle', 'Gece') NOT NULL,
    FOREIGN KEY (PersonelID) REFERENCES PERSONEL(PersonelID) ON DELETE CASCADE,
    INDEX idx_tarih (VardiyaTarihi),
    INDEX idx_personel (PersonelID)
);

-- ====================================
-- SAKLI YORDAMLAR - VERİ GİRİŞİ
-- ====================================

DELIMITER //

-- Müşteri Ekleme
CREATE PROCEDURE sp_MusteriEkle(
    IN p_Ad VARCHAR(50),
    IN p_Soyad VARCHAR(50),
    IN p_TCKimlikNo CHAR(11),
    IN p_Telefon VARCHAR(15),
    IN p_Email VARCHAR(100),
    IN p_Adres TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Müşteri eklenemedi!' AS Mesaj;
    END;
    
    START TRANSACTION;
    INSERT INTO MUSTERI (Ad, Soyad, TCKimlikNo, Telefon, Email, Adres)
    VALUES (p_Ad, p_Soyad, p_TCKimlikNo, p_Telefon, p_Email, p_Adres);
    COMMIT;
    SELECT 'Müşteri başarıyla eklendi!' AS Mesaj, LAST_INSERT_ID() AS MusteriID;
END //

-- Araç Ekleme
CREATE PROCEDURE sp_AracEkle(
    IN p_MusteriID INT,
    IN p_Plaka VARCHAR(15),
    IN p_Marka VARCHAR(50),
    IN p_Model VARCHAR(50),
    IN p_Renk VARCHAR(30),
    IN p_AracTipi VARCHAR(20)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Araç eklenemedi!' AS Mesaj;
    END;
    
    START TRANSACTION;
    INSERT INTO ARAC (MusteriID, Plaka, Marka, Model, Renk, AracTipi)
    VALUES (p_MusteriID, p_Plaka, p_Marka, p_Model, p_Renk, p_AracTipi);
    COMMIT;
    SELECT 'Araç başarıyla eklendi!' AS Mesaj, LAST_INSERT_ID() AS AracID;
END //

-- Abonelik Ekleme
CREATE PROCEDURE sp_AbonelikEkle(
    IN p_MusteriID INT,
    IN p_AbonelikTipi VARCHAR(10)
)
BEGIN
    DECLARE v_Ucret DECIMAL(10,2);
    DECLARE v_BitisTarihi DATE;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Abonelik eklenemedi!' AS Mesaj;
    END;
    
    START TRANSACTION;
    
    IF p_AbonelikTipi = 'Aylık' THEN
        SET v_Ucret = 2000.00;
        SET v_BitisTarihi = DATE_ADD(CURDATE(), INTERVAL 1 MONTH);
    ELSE
        SET v_Ucret = 20000.00;
        SET v_BitisTarihi = DATE_ADD(CURDATE(), INTERVAL 1 YEAR);
    END IF;
    
    INSERT INTO ABONELIK (MusteriID, AbonelikTipi, BaslangicTarihi, BitisTarihi, Ucret)
    VALUES (p_MusteriID, p_AbonelikTipi, CURDATE(), v_BitisTarihi, v_Ucret);
    
    COMMIT;
    SELECT 'Abonelik başarıyla eklendi!' AS Mesaj, LAST_INSERT_ID() AS AbonelikID;
END //

-- Park Yeri Ekleme (Otomatik doldurma)
CREATE PROCEDURE sp_ParkYerleriOlustur()
BEGIN
    DECLARE v_Kat INT DEFAULT 1;
    DECLARE v_Yer INT;
    
    WHILE v_Kat <= 5 DO
        SET v_Yer = 1;
        WHILE v_Yer <= 40 DO
            INSERT INTO PARK_YERI (KatNo, YerNumarasi, Durum)
            VALUES (v_Kat, v_Yer, 'Boş');
            SET v_Yer = v_Yer + 1;
        END WHILE;
        SET v_Kat = v_Kat + 1;
    END WHILE;
    
    SELECT '200 park yeri başarıyla oluşturuldu!' AS Mesaj;
END //

-- Araç Giriş İşlemi
CREATE PROCEDURE sp_AracGiris(
    IN p_Plaka VARCHAR(15),
    IN p_KatNo INT,
    IN p_YerNumarasi INT
)
BEGIN
    DECLARE v_AracID INT;
    DECLARE v_ParkYeriID INT;
    DECLARE v_Durum VARCHAR(20);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Giriş işlemi yapılamadı!' AS Mesaj;
    END;
    
    START TRANSACTION;
    
    SELECT AracID INTO v_AracID FROM ARAC WHERE Plaka = p_Plaka;
    
    IF v_AracID IS NULL THEN
        SELECT 'Hata: Araç sistemde kayıtlı değil!' AS Mesaj;
        ROLLBACK;
    ELSE
        SELECT ParkYeriID, Durum INTO v_ParkYeriID, v_Durum 
        FROM PARK_YERI 
        WHERE KatNo = p_KatNo AND YerNumarasi = p_YerNumarasi;
        
        IF v_Durum != 'Boş' THEN
            SELECT 'Hata: Park yeri dolu veya bakımda!' AS Mesaj;
            ROLLBACK;
        ELSE
            INSERT INTO GIRIS_CIKIS (AracID, ParkYeriID, GirisTarihi)
            VALUES (v_AracID, v_ParkYeriID, NOW());
            
            UPDATE PARK_YERI SET Durum = 'Dolu' WHERE ParkYeriID = v_ParkYeriID;
            
            COMMIT;
            SELECT 'Araç girişi başarılı!' AS Mesaj, LAST_INSERT_ID() AS IslemID;
        END IF;
    END IF;
END //

-- Araç Çıkış İşlemi
CREATE PROCEDURE sp_AracCikis(
    IN p_Plaka VARCHAR(15)
)
BEGIN
    DECLARE v_IslemID INT;
    DECLARE v_ParkYeriID INT;
    DECLARE v_GirisTarihi DATETIME;
    DECLARE v_ToplamDakika INT;
    DECLARE v_Ucret DECIMAL(10,2);
    DECLARE v_MusteriID INT;
    DECLARE v_AbonelikVarMi INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Çıkış işlemi yapılamadı!' AS Mesaj;
    END;
    
    START TRANSACTION;
    
    SELECT gc.IslemID, gc.ParkYeriID, gc.GirisTarihi, a.MusteriID
    INTO v_IslemID, v_ParkYeriID, v_GirisTarihi, v_MusteriID
    FROM GIRIS_CIKIS gc
    JOIN ARAC a ON gc.AracID = a.AracID
    WHERE a.Plaka = p_Plaka AND gc.CikisTarihi IS NULL
    ORDER BY gc.GirisTarihi DESC LIMIT 1;
    
    IF v_IslemID IS NULL THEN
        SELECT 'Hata: Bu araç için açık giriş kaydı bulunamadı!' AS Mesaj;
        ROLLBACK;
    ELSE
        SET v_ToplamDakika = TIMESTAMPDIFF(MINUTE, v_GirisTarihi, NOW());
        
        SELECT COUNT(*) INTO v_AbonelikVarMi
        FROM ABONELIK
        WHERE MusteriID = v_MusteriID 
        AND Durum = 'Aktif' 
        AND CURDATE() BETWEEN BaslangicTarihi AND BitisTarihi;
        
        IF v_AbonelikVarMi > 0 THEN
            SET v_Ucret = 0;
        ELSE
            SET v_Ucret = CEILING(v_ToplamDakika / 60) * 25;
            IF v_Ucret > 150 THEN
                SET v_Ucret = 150;
            END IF;
        END IF;
        
        UPDATE GIRIS_CIKIS 
        SET CikisTarihi = NOW(), ToplamSure = v_ToplamDakika, Ucret = v_Ucret
        WHERE IslemID = v_IslemID;
        
        UPDATE PARK_YERI SET Durum = 'Boş' WHERE ParkYeriID = v_ParkYeriID;
        
        COMMIT;
        SELECT 'Çıkış işlemi başarılı!' AS Mesaj, v_Ucret AS OdenecekTutar, v_ToplamDakika AS Sure;
    END IF;
END //

-- Ödeme İşlemi
CREATE PROCEDURE sp_OdemeYap(
    IN p_IslemID INT,
    IN p_OdemeTipi VARCHAR(20)
)
BEGIN
    DECLARE v_Ucret DECIMAL(10,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Ödeme yapılamadı!' AS Mesaj;
    END;
    
    START TRANSACTION;
    
    SELECT Ucret INTO v_Ucret FROM GIRIS_CIKIS WHERE IslemID = p_IslemID;
    
    IF v_Ucret IS NULL THEN
        SELECT 'Hata: İşlem bulunamadı!' AS Mesaj;
        ROLLBACK;
    ELSE
        INSERT INTO ODEME (IslemID, OdemeTipi, Tutar, OdemeDurumu)
        VALUES (p_IslemID, p_OdemeTipi, v_Ucret, 'Ödendi');
        
        COMMIT;
        SELECT 'Ödeme başarıyla alındı!' AS Mesaj, v_Ucret AS OdenenTutar;
    END IF;
END //

-- Personel Ekleme
CREATE PROCEDURE sp_PersonelEkle(
    IN p_Ad VARCHAR(50),
    IN p_Soyad VARCHAR(50),
    IN p_TCKimlikNo CHAR(11),
    IN p_Telefon VARCHAR(15),
    IN p_Pozisyon VARCHAR(20),
    IN p_Maas DECIMAL(10,2)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Personel eklenemedi!' AS Mesaj;
    END;
    
    START TRANSACTION;
    INSERT INTO PERSONEL (Ad, Soyad, TCKimlikNo, Telefon, Pozisyon, Maas, IseGirisTarihi)
    VALUES (p_Ad, p_Soyad, p_TCKimlikNo, p_Telefon, p_Pozisyon, p_Maas, CURDATE());
    COMMIT;
    SELECT 'Personel başarıyla eklendi!' AS Mesaj, LAST_INSERT_ID() AS PersonelID;
END //

-- Vardiya Ekleme
CREATE PROCEDURE sp_VardiyaEkle(
    IN p_PersonelID INT,
    IN p_VardiyaTarihi DATE,
    IN p_VardiyaTipi VARCHAR(10)
)
BEGIN
    DECLARE v_BaslangicSaati TIME;
    DECLARE v_BitisSaati TIME;
    
    IF p_VardiyaTipi = 'Sabah' THEN
        SET v_BaslangicSaati = '08:00:00';
        SET v_BitisSaati = '16:00:00';
    ELSEIF p_VardiyaTipi = 'Öğle' THEN
        SET v_BaslangicSaati = '16:00:00';
        SET v_BitisSaati = '00:00:00';
    ELSE
        SET v_BaslangicSaati = '00:00:00';
        SET v_BitisSaati = '08:00:00';
    END IF;
    
    INSERT INTO VARDIYA (PersonelID, VardiyaTarihi, BaslangicSaati, BitisSaati, VardiyaTipi)
    VALUES (p_PersonelID, p_VardiyaTarihi, v_BaslangicSaati, v_BitisSaati, p_VardiyaTipi);
    
    SELECT 'Vardiya başarıyla eklendi!' AS Mesaj;
END //

-- ====================================
-- SAKLI YORDAMLAR - GÜNCELLEME
-- ====================================

-- Müşteri Güncelleme
CREATE PROCEDURE sp_MusteriGuncelle(
    IN p_MusteriID INT,
    IN p_Telefon VARCHAR(15),
    IN p_Email VARCHAR(100),
    IN p_Adres TEXT
)
BEGIN
    UPDATE MUSTERI 
    SET Telefon = p_Telefon, Email = p_Email, Adres = p_Adres
    WHERE MusteriID = p_MusteriID;
    
    SELECT 'Müşteri bilgileri güncellendi!' AS Mesaj;
END //

-- Park Yeri Durumu Güncelleme
CREATE PROCEDURE sp_ParkYeriDurumGuncelle(
    IN p_ParkYeriID INT,
    IN p_YeniDurum VARCHAR(20)
)
BEGIN
    UPDATE PARK_YERI SET Durum = p_YeniDurum WHERE ParkYeriID = p_ParkYeriID;
    SELECT 'Park yeri durumu güncellendi!' AS Mesaj;
END //

-- ====================================
-- SAKLI YORDAMLAR - SİLME
-- ====================================

-- Müşteri Silme
CREATE PROCEDURE sp_MusteriSil(
    IN p_MusteriID INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Hata: Müşteri silinemedi! İlişkili kayıtlar var.' AS Mesaj;
    END;
    
    START TRANSACTION;
    DELETE FROM MUSTERI WHERE MusteriID = p_MusteriID;
    COMMIT;
    SELECT 'Müşteri silindi!' AS Mesaj;
END //

-- Abonelik İptal
CREATE PROCEDURE sp_AbonelikIptal(
    IN p_AbonelikID INT
)
BEGIN
    UPDATE ABONELIK SET Durum = 'İptal' WHERE AbonelikID = p_AbonelikID;
    SELECT 'Abonelik iptal edildi!' AS Mesaj;
END //

-- ====================================
-- SAKLI YORDAMLAR - SORGULAMA
-- ====================================

-- Müşteri Sorgulama
CREATE PROCEDURE sp_MusteriAra(
    IN p_AramaTerimi VARCHAR(100)
)
BEGIN
    SELECT * FROM MUSTERI 
    WHERE Ad LIKE CONCAT('%', p_AramaTerimi, '%') 
    OR Soyad LIKE CONCAT('%', p_AramaTerimi, '%')
    OR TCKimlikNo LIKE CONCAT('%', p_AramaTerimi, '%')
    OR Telefon LIKE CONCAT('%', p_AramaTerimi, '%');
END //

-- Boş Park Yerleri
CREATE PROCEDURE sp_BosParkYerleri()
BEGIN
    SELECT * FROM PARK_YERI WHERE Durum = 'Boş' ORDER BY KatNo, YerNumarasi;
END //

-- Günlük Gelir Raporu
CREATE PROCEDURE sp_GunlukGelir(
    IN p_Tarih DATE
)
BEGIN
    SELECT 
        COUNT(*) AS ToplamIslem,
        SUM(o.Tutar) AS ToplamGelir,
        AVG(o.Tutar) AS OrtalamaUcret
    FROM ODEME o
    JOIN GIRIS_CIKIS gc ON o.IslemID = gc.IslemID
    WHERE DATE(o.OdemeTarihi) = p_Tarih AND o.OdemeDurumu = 'Ödendi';
END //

-- Aylık Gelir Raporu
CREATE PROCEDURE sp_AylikGelir(
    IN p_Yil INT,
    IN p_Ay INT
)
BEGIN
    SELECT 
        DATE(o.OdemeTarihi) AS Gun,
        COUNT(*) AS IslemSayisi,
        SUM(o.Tutar) AS GunlukGelir
    FROM ODEME o
    WHERE YEAR(o.OdemeTarihi) = p_Yil 
    AND MONTH(o.OdemeTarihi) = p_Ay
    AND o.OdemeDurumu = 'Ödendi'
    GROUP BY DATE(o.OdemeTarihi)
    ORDER BY Gun;
END //

-- Doluluk Oranı
CREATE PROCEDURE sp_DolulukOrani()
BEGIN
    SELECT 
        COUNT(*) AS ToplamYer,
        SUM(CASE WHEN Durum = 'Dolu' THEN 1 ELSE 0 END) AS DoluYer,
        SUM(CASE WHEN Durum = 'Boş' THEN 1 ELSE 0 END) AS BosYer,
        ROUND((SUM(CASE WHEN Durum = 'Dolu' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS DolulukYuzdesi
    FROM PARK_YERI;
END //

-- Aktif Araçlar
CREATE PROCEDURE sp_AktifAraclar()
BEGIN
    SELECT 
        gc.IslemID,
        a.Plaka,
        m.Ad,
        m.Soyad,
        m.Telefon,
        p.KatNo,
        p.YerNumarasi,
        gc.GirisTarihi,
        TIMESTAMPDIFF(MINUTE, gc.GirisTarihi, NOW()) AS GecenSure
    FROM GIRIS_CIKIS gc
    JOIN ARAC a ON gc.AracID = a.AracID
    JOIN MUSTERI m ON a.MusteriID = m.MusteriID
    JOIN PARK_YERI p ON gc.ParkYeriID = p.ParkYeriID
    WHERE gc.CikisTarihi IS NULL
    ORDER BY gc.GirisTarihi DESC;
END //

-- ====================================
-- KULLANICI TANIMLI FONKSİYONLAR
-- ====================================

-- Ücret Hesaplama Fonksiyonu
CREATE FUNCTION fn_UcretHesapla(p_Dakika INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_Ucret DECIMAL(10,2);
    SET v_Ucret = CEILING(p_Dakika / 60) * 25;
    IF v_Ucret > 150 THEN
        SET v_Ucret = 150;
    END IF;
    RETURN v_Ucret;
END //

-- Abonelik Kontrol Fonksiyonu
CREATE FUNCTION fn_AbonelikKontrol(p_MusteriID INT) 
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    DECLARE v_Durum VARCHAR(10);
    SELECT 
        CASE 
            WHEN COUNT(*) > 0 THEN 'Aktif'
            ELSE 'Yok'
        END INTO v_Durum
    FROM ABONELIK
    WHERE MusteriID = p_MusteriID 
    AND Durum = 'Aktif' 
    AND CURDATE() BETWEEN BaslangicTarihi AND BitisTarihi;
    
    RETURN v_Durum;
END //

-- Müşteri Toplam Harcama
CREATE FUNCTION fn_MusteriToplamHarcama(p_MusteriID INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_ToplamHarcama DECIMAL(10,2);
    
    SELECT COALESCE(SUM(o.Tutar), 0) INTO v_ToplamHarcama
    FROM ODEME o
    JOIN GIRIS_CIKIS gc ON o.IslemID = gc.IslemID
    JOIN ARAC a ON gc.AracID = a.AracID
    WHERE a.MusteriID = p_MusteriID AND o.OdemeDurumu = 'Ödendi';
    
    RETURN v_ToplamHarcama;
END //

-- ====================================
-- TETİKLEYİCİLER (TRIGGERS)
-- ====================================

-- Abonelik Sona Erme Kontrolü
CREATE TRIGGER trg_AbonelikKontrol
BEFORE UPDATE ON ABONELIK
FOR EACH ROW
BEGIN
    IF NEW.BitisTarihi < CURDATE() AND NEW.Durum = 'Aktif' THEN
        SET NEW.Durum = 'Pasif';
    END IF;
END //

-- Ödeme Sonrası Log
CREATE TRIGGER trg_OdemeLog
AFTER INSERT ON ODEME
FOR EACH ROW
BEGIN
    IF NEW.Tutar > 100 THEN
        UPDATE GIRIS_CIKIS SET Ucret = NEW.Tutar WHERE IslemID = NEW.IslemID;
    END IF;
END //

-- Park Yeri Durumu Değişim Kontrolü
CREATE TRIGGER trg_ParkYeriDegisim
BEFORE UPDATE ON PARK_YERI
FOR EACH ROW
BEGIN
    IF OLD.Durum = 'Bakımda' AND NEW.Durum = 'Boş' THEN
        SET NEW.Durum = 'Boş';
    END IF;
    
    IF OLD.Durum = 'Dolu' AND NEW.Durum = 'Boş' THEN
        SET NEW.Durum = 'Boş';
    END IF;
END //

DELIMITER ;
