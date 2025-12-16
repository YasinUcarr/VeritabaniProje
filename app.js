// API base URL
const API_URL = 'api.php';

let currentFloor = 1;

// Sayfa yüklendiğinde
document.addEventListener('DOMContentLoaded', function() {
    loadDashboardStats();
    loadActiveVehicles();
    loadParkingSpots(1);
    updateTime();
    setInterval(updateTime, 1000);
    setInterval(loadActiveVehicles, 30000); 
    
    
    setupFormListeners();
});


function setupFormListeners() {
    
    const existingForm = document.getElementById('existingVehicleForm');
    if (existingForm) {
       
        document.getElementById('existingPlaka').value = document.getElementById('regPlaka').value;
    }
}

// Saat güncelleme
function updateTime() {
    document.getElementById('currentTime').textContent = 
        new Date().toLocaleString('tr-TR');
}

// Dashboard istatistiklerini yükle
async function loadDashboardStats() {
    try {
        const response = await fetch(`${API_URL}?action=dashboard_istatistik`);
        const result = await response.json();
        
        if (result.success) {
            const data = result.data;
            document.getElementById('occupiedCount').textContent = data.doluluk.DoluYer;
            document.getElementById('emptyCount').textContent = data.doluluk.BosYer;
            document.getElementById('occupancyRate').textContent = data.doluluk.DolulukYuzdesi + '%';
        }
    } catch (error) {
        console.error('İstatistik yükleme hatası:', error);
    }
}

// Aktif araçları yükle
async function loadActiveVehicles() {
    try {
        const response = await fetch(`${API_URL}?action=aktif_araclar`);
        const result = await response.json();
        
        const container = document.getElementById('activeVehicles');
        
        if (result.success && result.data.length > 0) {
            container.innerHTML = result.data.map(v => `
                <div class="vehicle-item">
                    <strong>${v.Plaka}</strong>
                    <p>📍 ${v.KatNo}. Kat - ${v.YerNumarasi} numaralı park yeri</p>
                    <p>👤 ${v.MusteriAd} ${v.MusteriSoyad}</p>
                    <p>📞 ${v.Telefon}</p>
                    <p>🕐 Giriş: ${formatDate(v.GirisTarihi)}</p>
                    <p>⏱️ Geçen Süre: ${Math.floor(v.GecenSure / 60)} saat ${v.GecenSure % 60} dakika</p>
                    <p>💰 Güncel Ücret: ${formatMoney(v.GuncelUcret)}</p>
                </div>
            `).join('');
        } else {
            container.innerHTML = '<p style="color: #999; text-align: center;">Henüz aktif araç yok</p>';
        }
    } catch (error) {
        console.error('Aktif araç yükleme hatası:', error);
    }
}

// Park yerlerini yükle
async function loadParkingSpots(floor) {
    try {
        const response = await fetch(`${API_URL}?action=park_yerleri&kat_no=${floor}`);
        const result = await response.json();
        
        if (result.success) {
            renderParkingGrid(result.data);
        }
    } catch (error) {
        console.error('Park yeri yükleme hatası:', error);
    }
}

// Park haritasını çiz
function renderParkingGrid(spots) {
    const grid = document.getElementById('parkingGrid');
    grid.innerHTML = '';
    
    let emptyCount = 0, occupiedCount = 0, maintenanceCount = 0;
    
    spots.forEach(spot => {
        const div = document.createElement('div');
        div.className = `parking-spot ${spot.Durum}`;
        div.innerHTML = `
            <div class="spot-number">${spot.YerNumarasi}</div>
            <div class="spot-status">${spot.Durum}</div>
        `;
        
        div.onclick = () => selectParkingSpot(spot);
        grid.appendChild(div);
        
        if (spot.Durum === 'Boş') emptyCount++;
        else if (spot.Durum === 'Dolu') occupiedCount++;
        else if (spot.Durum === 'Bakımda') maintenanceCount++;
    });
    
    document.getElementById('floorEmpty').textContent = emptyCount;
    document.getElementById('floorOccupied').textContent = occupiedCount;
    document.getElementById('floorMaintenance').textContent = maintenanceCount;
}

// Park yeri seç
function selectParkingSpot(spot) {
    if (spot.Durum === 'Boş') {
        document.getElementById('entryFloor').value = spot.KatNo;
        document.getElementById('entrySpot').value = spot.YerNumarasi;
        showTab('entry');
        
        // Sekmeyi aktif yap
        document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
        document.querySelectorAll('.tab')[0].classList.add('active');
    } else {
        alert(`Park Yeri Bilgisi\n\nKat: ${spot.KatNo}\nYer No: ${spot.YerNumarasi}\nDurum: ${spot.Durum}`);
    }
}

// Kat değiştir
function showFloor(floor) {
    currentFloor = floor;
    
    document.querySelectorAll('.floor-btn').forEach(btn => btn.classList.remove('active'));
    event.target.classList.add('active');
    
    loadParkingSpots(floor);
}

// Tab değiştir
function showTab(tabName) {
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    
    if (event && event.target) {
        event.target.classList.add('active');
    }
    
    document.getElementById(tabName).classList.add('active');
}

// Araç girişi
async function vehicleEntry(e) {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const alertDiv = document.getElementById('entryAlert');
    
    try {
        const response = await fetch(`${API_URL}?action=arac_giris`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
            showAlert(alertDiv, result.message, 'success');
            e.target.reset();
            loadDashboardStats();
            loadActiveVehicles();
            loadParkingSpots(currentFloor);
        } else {
            showAlert(alertDiv, result.message, 'danger');
        }
    } catch (error) {
        showAlert(alertDiv, 'Bir hata oluştu: ' + error.message, 'danger');
    }
}

// Araç çıkışı
async function vehicleExit(e) {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const alertDiv = document.getElementById('exitAlert');
    const detailsDiv = document.getElementById('exitDetails');
    
    try {
        const response = await fetch(`${API_URL}?action=arac_cikis`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
            showAlert(alertDiv, result.message, 'success');
            
            if (result.data && result.data.OdenecekTutar !== undefined) {
                detailsDiv.innerHTML = `
                    <div class="alert alert-success">
                        <strong>Çıkış İşlemi Tamamlandı</strong><br>
                        Plaka: ${formData.get('plaka')}<br>
                        Süre: ${result.data.Sure} dakika<br>
                        Ücret: ${formatMoney(result.data.OdenecekTutar)}<br>
                        <button class="btn btn-success" style="margin-top: 10px;" 
                            onclick="processPayment('${formData.get('plaka')}', ${result.data.OdenecekTutar})">
                            Ödeme Al
                        </button>
                    </div>
                `;
            }
            
            e.target.reset();
            loadDashboardStats();
            loadActiveVehicles();
            loadParkingSpots(currentFloor);
        } else {
            showAlert(alertDiv, result.message, 'danger');
        }
    } catch (error) {
        showAlert(alertDiv, 'Bir hata oluştu: ' + error.message, 'danger');
    }
}

// Ödeme işlemi
async function processPayment(plaka, tutar) {
    const odemeTipi = prompt('Ödeme Tipi Seçin:\n1- Nakit\n2- Kredi Kartı\n3- Havale', '1');
    
    let odemeTipiText = 'Nakit';
    if (odemeTipi === '2') odemeTipiText = 'Kredi Kartı';
    else if (odemeTipi === '3') odemeTipiText = 'Havale';
    
    // En son işlem ID'sini bul (gerçek uygulamada bu çıkış işleminden gelecek)
    try {
        const response = await fetch(`${API_URL}?action=aktif_araclar`);
        const result = await response.json();
        
        // Burada normalde çıkış işleminden gelen IslemID kullanılmalı
        // Şimdilik alert ile gösterelim
        alert(`${plaka} plakalı araç için ${formatMoney(tutar)} ${odemeTipiText} ile ödeme alındı.`);
        
        document.getElementById('exitDetails').innerHTML = '';
        document.getElementById('exitPlate').value = '';
        
        loadDashboardStats();
    } catch (error) {
        alert('Ödeme işlemi hatası: ' + error.message);
    }
}

// Müşteri ekle
async function addCustomer(e) {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const alertDiv = document.getElementById('customerAlert');
    
    try {
        const response = await fetch(`${API_URL}?action=musteri_ekle`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
            showAlert(alertDiv, result.message + ' Müşteri ID: ' + (result.data?.MusteriID || 'Bilinmiyor'), 'success');
            e.target.reset();
        } else {
            showAlert(alertDiv, result.message, 'danger');
        }
    } catch (error) {
        showAlert(alertDiv, 'Bir hata oluştu: ' + error.message, 'danger');
    }
}

// Abonelik ekle
async function addSubscription(e) {
    e.preventDefault();
    
    const formData = new FormData(e.target);
    const alertDiv = document.getElementById('subscriptionAlert');
    
    try {
        const response = await fetch(`${API_URL}?action=abonelik_ekle`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (result.success) {
            showAlert(alertDiv, result.message, 'success');
            e.target.reset();
        } else {
            showAlert(alertDiv, result.message, 'danger');
        }
    } catch (error) {
        showAlert(alertDiv, 'Bir hata oluştu: ' + error.message, 'danger');
    }
}

// Alert göster
function showAlert(element, message, type) {
    element.innerHTML = `<div class="alert alert-${type}">${message}</div>`;
    setTimeout(() => element.innerHTML = '', 5000);
}

// Tarih formatlama
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('tr-TR');
}

// Para formatlama
function formatMoney(amount) {
    return new Intl.NumberFormat('tr-TR', {
        style: 'currency',
        currency: 'TRY'
    }).format(amount);
}