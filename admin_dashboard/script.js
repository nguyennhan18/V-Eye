// Fetch Data từ Backend
async function fetchDashboardData() {
    try {
        const [statsRes, historyRes] = await Promise.all([
            fetch('/api/dashboard/stats'),
            fetch('/api/dashboard/history')
        ]);
        
        const stats = await statsRes.json();
        const history = await historyRes.json();
        
        updateStats(stats);
        updateHistoryTable(history);
        
    } catch (e) {
        console.error("Lỗi khi tải dữ liệu Dashboard:", e);
    }
}

function updateStats(stats) {
    // Cập nhật số lượng ảnh đã phân tích
    document.querySelector('.card:nth-child(1) h3').innerText = stats.total_images.toLocaleString();
    
    // Cập nhật tốc độ (ms)
    document.querySelector('.card:nth-child(2) h3').innerText = stats.avg_processing_time_ms + ' ms';
}

function updateHistoryTable(history) {
    const tbody = document.querySelector('.table-container tbody');
    tbody.innerHTML = ''; // Clear bảng cũ
    
    history.forEach(log => {
        const tr = document.createElement('tr');
        
        // Thời gian
        const date = new Date(log.timestamp + 'Z'); // UTC
        const timeStr = date.toLocaleString('vi-VN');
        
        // Cắt ngắn description
        let desc = log.description || "";
        if (desc.length > 50) desc = desc.substring(0, 50) + '...';
        
        tr.innerHTML = `
            <td>
                <div class="user-info">
                    <img src="/dataset/${log.image_filename}" alt="Image" style="width: 40px; height: 40px; border-radius: 8px; object-fit: cover;">
                    <div class="user-details">
                        <span class="user-name">${log.image_filename}</span>
                    </div>
                </div>
            </td>
            <td><span class="badge ${log.provider === 'openai' ? 'badge-purple' : 'badge-green'}">${log.provider.toUpperCase()}</span></td>
            <td>${timeStr}</td>
            <td style="max-width: 200px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${desc}</td>
            <td class="amount">${log.processing_time_ms} ms</td>
            <td>
                ${log.audio_url ? `<button class="btn-action" onclick="new Audio('${log.audio_url}').play()">▶</button>` : ''}
            </td>
        `;
        tbody.appendChild(tr);
    });
}

// Cấu hình chung cho Chart.js để hợp với Dark Mode
Chart.defaults.color = '#9CA3AF';
Chart.defaults.font.family = 'Inter, sans-serif';

// Dữ liệu chung
const labels7Days = ['17/05', '18/05', '19/05', '20/05', '21/05', '22/05', '23/05'];

// --- BIỂU ĐỒ LINE CHÍNH ---
const ctxLine = document.getElementById('lineChart').getContext('2d');
const gradientLine = ctxLine.createLinearGradient(0, 0, 0, 400);
gradientLine.addColorStop(0, 'rgba(59, 130, 246, 0.5)'); // Blue glow top
gradientLine.addColorStop(1, 'rgba(59, 130, 246, 0)');   // Fade out

new Chart(ctxLine, {
    type: 'line',
    data: {
        labels: labels7Days,
        datasets: [{
            label: 'Yêu cầu',
            data: [150, 260, 220, 310, 450, 300, 342],
            borderColor: '#3B82F6',
            backgroundColor: gradientLine,
            borderWidth: 3,
            tension: 0.4,
            fill: true,
            pointBackgroundColor: '#0B1120',
            pointBorderColor: '#3B82F6',
            pointBorderWidth: 2,
            pointRadius: 4,
            pointHoverRadius: 6
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false }
        },
        scales: {
            y: {
                beginAtZero: true,
                grid: {
                    color: 'rgba(255, 255, 255, 0.05)',
                    drawBorder: false,
                }
            },
            x: {
                grid: { display: false, drawBorder: false }
            }
        }
    }
});

// --- BIỂU ĐỒ DONUT ---
const ctxDonut = document.getElementById('donutChart').getContext('2d');
new Chart(ctxDonut, {
    type: 'doughnut',
    data: {
        labels: ['Phương tiện', 'Người', 'Đồ vật', 'Cảnh vật', 'Khác'],
        datasets: [{
            data: [32, 28, 20, 15, 5],
            backgroundColor: [
                '#3B82F6', // Blue
                '#8B5CF6', // Purple
                '#F59E0B', // Orange
                '#10B981', // Green
                '#4B5563'  // Grey
            ],
            borderWidth: 0,
            hoverOffset: 4
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '75%', // Tạo lỗ hổng lớn ở giữa
        plugins: {
            legend: { display: false }, // Đã custom legend bằng HTML
            tooltip: {
                backgroundColor: '#111827',
                padding: 10,
            }
        }
    }
});

// --- SPARKLINE CHARTS ---
function createSparkline(id, color, data) {
    const ctx = document.getElementById(id).getContext('2d');
    new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['1','2','3','4','5','6','7'],
            datasets: [{
                data: data,
                borderColor: color,
                borderWidth: 2,
                tension: 0.3,
                pointRadius: 0
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            scales: {
                x: { display: false },
                y: { display: false, min: 0 }
            },
            layout: { padding: 0 }
        }
    });
}

createSparkline('chart-spark-1', '#3B82F6', [10, 20, 15, 25, 22, 30, 28]);
createSparkline('chart-spark-2', '#10B981', [5, 15, 10, 20, 18, 25, 22]);
createSparkline('chart-spark-3', '#8B5CF6', [20, 18, 25, 22, 30, 28, 35]);
createSparkline('chart-spark-4', '#F59E0B', [30, 25, 28, 20, 22, 15, 10]);

// Bắt đầu fetch dữ liệu khi load trang
fetchDashboardData();
// Tự động load lại mỗi 10 giây
setInterval(fetchDashboardData, 10000);
