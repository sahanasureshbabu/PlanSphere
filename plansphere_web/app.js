// PlanSphere Web - Core Logic Engine (Advanced Edition)

// ── DATABASE INITIALIZATION & MOCK DATA ───────────────────────
function initializeDatabase() {
    // 1. Initialise users if empty
    if (!localStorage.getItem('plansphere_users')) {
        const defaultUsers = [{ email: "admin@plansphere.com", password: "admin123", name: "Administrator" }];
        localStorage.setItem('plansphere_users', JSON.stringify(defaultUsers));
    }

    // 2. Initialise bills if empty
    const existingBills = localStorage.getItem('plansphere_bills');
    if (!existingBills) {
        const today = new Date();
        
        const futureDate = new Date();
        futureDate.setMonth(today.getMonth() + 10); // 10 months from now
        
        const nearExpiryDate = new Date();
        nearExpiryDate.setDate(today.getDate() + 12); // 12 days from now
        
        const pastDate = new Date();
        pastDate.setMonth(today.getMonth() - 4); // Expired 4 months ago
        
        const mockBills = [
            {
                id: 'bill-1',
                productName: 'MacBook Pro M3 Max',
                category: 'Electronics',
                type: 'Warranty Bill',
                amount: 249999,
                purchaseDate: today.toISOString().split('T')[0],
                expiryDate: futureDate.toISOString().split('T')[0],
                storeName: 'Apple Store BKC',
                image: '',
                fileType: 'image'
            },
            {
                id: 'bill-2',
                productName: 'iPhone 17 Pro',
                category: 'Electronics',
                type: 'Warranty Bill',
                amount: 139900,
                purchaseDate: today.toISOString().split('T')[0],
                expiryDate: nearExpiryDate.toISOString().split('T')[0],
                storeName: 'Reliance Digital',
                image: '',
                fileType: 'image'
            },
            {
                id: 'bill-3',
                productName: 'Apollo Pharmacy Health Checkup',
                category: 'Health',
                type: 'Medical Bill',
                amount: 3499,
                purchaseDate: '2025-05-15',
                expiryDate: pastDate.toISOString().split('T')[0],
                storeName: 'Apollo Pharmacy',
                image: '',
                fileType: 'pdf'
            },
            {
                id: 'bill-4',
                productName: 'LIC Term Insurance Policy',
                category: 'Insurance',
                type: 'Insurance',
                amount: 18500,
                purchaseDate: '2026-01-10',
                expiryDate: '2027-01-10',
                storeName: 'LIC India',
                image: '',
                fileType: 'pdf'
            }
        ];
        localStorage.setItem('plansphere_bills', JSON.stringify(mockBills));
    }

    // 3. Initialise documents if empty
    if (!localStorage.getItem('plansphere_documents')) {
        const mockDocs = [
            {
                id: 'doc-1',
                name: 'Aadhaar Card E-Copy',
                category: 'Aadhaar',
                uploadDate: '2026-03-01',
                fileSize: '412 KB',
                image: '',
                fileType: 'pdf'
            },
            {
                id: 'doc-2',
                name: 'PAN Card Copy',
                category: 'PAN',
                uploadDate: '2026-04-15',
                fileSize: '150 KB',
                image: '',
                fileType: 'image'
            },
            {
                id: 'doc-3',
                name: 'Graduation Degree Certificate',
                category: 'Certificates',
                uploadDate: '2026-02-10',
                fileSize: '1.2 MB',
                image: '',
                fileType: 'pdf'
            }
        ];
        localStorage.setItem('plansphere_documents', JSON.stringify(mockDocs));
    }

    // 4. Initialise settings if empty
    if (!localStorage.getItem('plansphere_settings')) {
        const defaultSettings = {
            theme: 'dark',
            language: 'en',
            notifications_enabled: true,
            backup_frequency: 'weekly',
            security_lock: false
        };
        localStorage.setItem('plansphere_settings', JSON.stringify(defaultSettings));
    }

    // 5. Initialise notifications if empty
    if (!localStorage.getItem('plansphere_notifications')) {
        const mockNotifs = [
            {
                id: 'notif-1',
                title: 'Welcome to PlanSphere Vault! 🛡️',
                message: 'Start securing your bills, warranties, and official identity documents.',
                timestamp: new Date().toISOString(),
                read: false
            }
        ];
        localStorage.setItem('plansphere_notifications', JSON.stringify(mockNotifs));
    }
}

// Run immediately
initializeDatabase();

// ── GENERAL DATABASE READ/WRITES ─────────────────────────────
function getBills() {
    return JSON.parse(localStorage.getItem('plansphere_bills') || '[]');
}

function saveBill(bill) {
    const bills = getBills();
    
    // Auto-detect duplicate logic
    const duplicate = detectDuplicateBill(bill.image, bill.productName, bill.amount, bill.purchaseDate);
    if (duplicate) {
        showToast('⚠️ Duplicate bill pattern detected!', 'error');
    }
    
    bills.push(bill);
    localStorage.setItem('plansphere_bills', JSON.stringify(bills));
    
    // Add Notification
    addNotification({
        title: 'New Bill Uploaded',
        message: `Successfully uploaded bill for ${bill.productName} (${bill.type})`,
        read: false
    });
}

function deleteBill(id) {
    let bills = getBills();
    const bill = bills.find(b => b.id === id);
    bills = bills.filter(b => b.id !== id);
    localStorage.setItem('plansphere_bills', JSON.stringify(bills));
    if (bill) {
        addNotification({
            title: 'Bill Removed',
            message: `Deleted bill record for ${bill.productName}`,
            read: true
        });
    }
}

function updateBill(updatedBill) {
    let bills = getBills();
    bills = bills.map(b => b.id === updatedBill.id ? updatedBill : b);
    localStorage.setItem('plansphere_bills', JSON.stringify(bills));
}

// ── DOCUMENT VAULT OPERATIONS ───────────────────────────────
function getDocuments() {
    return JSON.parse(localStorage.getItem('plansphere_documents') || '[]');
}

function saveDocument(doc) {
    const docs = getDocuments();
    docs.push(doc);
    localStorage.setItem('plansphere_documents', JSON.stringify(docs));
    addNotification({
        title: 'Document Saved',
        message: `Secured file "${doc.name}" in category "${doc.category}"`,
        read: false
    });
}

function deleteDocument(id) {
    let docs = getDocuments();
    const doc = docs.find(d => d.id === id);
    docs = docs.filter(d => d.id !== id);
    localStorage.setItem('plansphere_documents', JSON.stringify(docs));
    if (doc) {
        addNotification({
            title: 'Document Removed',
            message: `Removed ${doc.name} from vault`,
            read: true
        });
    }
}

// ── NOTIFICATIONS MANAGEMENT ─────────────────────────────────
function getNotifications() {
    return JSON.parse(localStorage.getItem('plansphere_notifications') || '[]');
}

function addNotification(notif) {
    const notifs = getNotifications();
    notif.id = 'notif-' + Date.now();
    notif.timestamp = new Date().toISOString();
    notifs.unshift(notif); // Add to top
    localStorage.setItem('plansphere_notifications', JSON.stringify(notifs));
}

function markAllNotificationsRead() {
    const notifs = getNotifications();
    notifs.forEach(n => n.read = true);
    localStorage.setItem('plansphere_notifications', JSON.stringify(notifs));
}

function clearAllNotifications() {
    localStorage.setItem('plansphere_notifications', JSON.stringify([]));
}

// ── SETTINGS OPERATIONS ──────────────────────────────────────
function getSystemSettings() {
    return JSON.parse(localStorage.getItem('plansphere_settings') || '{}');
}

function saveSystemSettings(settings) {
    localStorage.setItem('plansphere_settings', JSON.stringify(settings));
    // Apply styling dynamic properties (e.g. theme)
    applySystemTheme(settings.theme);
}

function applySystemTheme(theme) {
    if (theme === 'light') {
        document.documentElement.classList.add('light-mode');
    } else {
        document.documentElement.classList.remove('light-mode');
    }
}

// Run theme check immediately
(function() {
    const settings = JSON.parse(localStorage.getItem('plansphere_settings') || '{}');
    if (settings.theme === 'light') {
        document.documentElement.classList.add('light-mode');
    }
})();

// ── AUTHENTICATION UTILITIES ─────────────────────────────────
function checkAuth() {
    const session = localStorage.getItem('plansphere_session');
    if (!session) {
        window.location.href = 'index.html';
        return null;
    }
    return JSON.parse(session);
}

function loginUser(email, password) {
    const users = JSON.parse(localStorage.getItem('plansphere_users') || '[]');
    const match = users.find(u => u.email.trim().toLowerCase() === email.trim().toLowerCase() && u.password === password);
    if (match) {
        localStorage.setItem('plansphere_session', JSON.stringify({
            email: match.email,
            name: match.name || 'User',
            token: 'session-' + Date.now()
        }));
        return { success: true };
    }
    return { success: false, message: 'Invalid email or password.' };
}

function registerUser(name, email, password) {
    const users = JSON.parse(localStorage.getItem('plansphere_users') || '[]');
    const exists = users.find(u => u.email.trim().toLowerCase() === email.trim().toLowerCase());
    if (exists) {
        return { success: false, message: 'Email already registered.' };
    }
    users.push({ name, email: email.trim().toLowerCase(), password });
    localStorage.setItem('plansphere_users', JSON.stringify(users));
    return { success: true };
}

function logout() {
    localStorage.removeItem('plansphere_session');
    window.location.href = 'index.html';
}

// ── SMART FEATURES ───────────────────────────────────────────

// 1. DUPLICATE BILL DETECTION
function detectDuplicateBill(fileBase64, name, amount, date) {
    const bills = getBills();
    
    // Hash check if file contents are identical
    if (fileBase64 && fileBase64.length > 50) {
        const fileHash = fileBase64.slice(100, 1000); // Simple segment comparator as local hash
        const hashMatch = bills.find(b => b.image && b.image.slice(100, 1000) === fileHash);
        if (hashMatch) return true;
    }
    
    // Meta pattern match: Same amount, purchase date and similar name
    const metaMatch = bills.find(b => {
        const isSameAmount = parseFloat(b.amount) === parseFloat(amount);
        const isSameDate   = b.purchaseDate === date;
        const nameSimilarity = b.productName.toLowerCase().includes(name.toLowerCase()) || 
                               name.toLowerCase().includes(b.productName.toLowerCase());
        return isSameAmount && isSameDate && nameSimilarity;
    });
    
    return !!metaMatch;
}

// 2. SMART CATEGORIZATION
function autoCategorize(title) {
    const lowercase = (title || '').toLowerCase();
    
    // Mapping keywords to type & categories
    if (lowercase.includes('rent') || lowercase.includes('bill') && (lowercase.includes('electric') || lowercase.includes('water') || lowercase.includes('power') || lowercase.includes('gas') || lowercase.includes('internet') || lowercase.includes('wifi') || lowercase.includes('broadband'))) {
        return { category: 'Utilities', type: 'Utility Bill' };
    }
    if (lowercase.includes('hospital') || lowercase.includes('medical') || lowercase.includes('pharmacy') || lowercase.includes('doctor') || lowercase.includes('medicine') || lowercase.includes('checkup') || lowercase.includes('apollo')) {
        return { category: 'Health', type: 'Medical Bill' };
    }
    if (lowercase.includes('insurance') || lowercase.includes('lic') || lowercase.includes('policy') || lowercase.includes('premium')) {
        return { category: 'Insurance', type: 'Insurance' };
    }
    if (lowercase.includes('aadhaar') || lowercase.includes('pan card') || lowercase.includes('passport') || lowercase.includes('id') || lowercase.includes('visa') || lowercase.includes('license')) {
        return { category: 'Personal ID', type: 'Certificate' };
    }
    if (lowercase.includes('degree') || lowercase.includes('certificate') || lowercase.includes('education') || lowercase.includes('diploma') || lowercase.includes('marksheet')) {
        return { category: 'Education', type: 'Certificate' };
    }
    
    // Default
    return { category: 'Electronics', type: 'Warranty Bill' };
}

// 3. SMART QUERY PARSING (Natural Language Search)
function parseSmartSearch(query) {
    const tokens = query.toLowerCase().split(/\s+/);
    const bills  = getBills();
    const docs   = getDocuments();
    
    let filteredBills = [...bills];
    let filteredDocs  = [...docs];

    // Threshold check (e.g. "above 10000" or "below 500")
    const aboveIdx = tokens.indexOf('above');
    const overIdx  = tokens.indexOf('over');
    const belowIdx = tokens.indexOf('below');
    const underIdx = tokens.indexOf('under');
    
    const getNum = (str) => {
        if (!str) return null;
        return parseFloat(str.replace(/[^0-9.]/g, ''));
    };

    if (aboveIdx !== -1 || overIdx !== -1) {
        const nextVal = getNum(tokens[Math.max(aboveIdx, overIdx) + 1]);
        if (nextVal !== null) {
            filteredBills = filteredBills.filter(b => b.amount >= nextVal);
        }
    } else if (belowIdx !== -1 || underIdx !== -1) {
        const nextVal = getNum(tokens[Math.max(belowIdx, underIdx) + 1]);
        if (nextVal !== null) {
            filteredBills = filteredBills.filter(b => b.amount <= nextVal);
        }
    }

    // Date filters (e.g. "2025" or "2026")
    tokens.forEach(tok => {
        if (/^\d{4}$/.test(tok)) {
            const yr = parseInt(tok);
            filteredBills = filteredBills.filter(b => new Date(b.purchaseDate).getFullYear() === yr);
            filteredDocs  = filteredDocs.filter(d => new Date(d.uploadDate).getFullYear() === yr);
        }
    });

    // Expiry / Warranty status shortcuts
    if (tokens.includes('expired')) {
        filteredBills = filteredBills.filter(b => getWarrantyStatus(b.expiryDate).status === 'expired');
    } else if (tokens.includes('warning') || tokens.includes('near')) {
        filteredBills = filteredBills.filter(b => getWarrantyStatus(b.expiryDate).status === 'warning');
    } else if (tokens.includes('protected') || tokens.includes('active')) {
        filteredBills = filteredBills.filter(b => getWarrantyStatus(b.expiryDate).status === 'protected');
    }

    // Text token matching (non-keywords matching title/category/store)
    const keywords = ['above', 'over', 'below', 'under', 'expired', 'warning', 'near', 'protected', 'active', 'bills', 'documents', 'bills:', 'docs:'];
    const textTokens = tokens.filter(t => !keywords.includes(t) && !/^\d+$/.test(t) && t.length > 1);

    if (textTokens.length > 0) {
        filteredBills = filteredBills.filter(b => {
            return textTokens.some(tok => 
                b.productName.toLowerCase().includes(tok) || 
                b.category.toLowerCase().includes(tok) || 
                (b.storeName || '').toLowerCase().includes(tok) ||
                b.type.toLowerCase().includes(tok)
            );
        });
        filteredDocs = filteredDocs.filter(d => {
            return textTokens.some(tok => 
                d.name.toLowerCase().includes(tok) || 
                d.category.toLowerCase().includes(tok)
            );
        });
    }

    return { bills: filteredBills, documents: filteredDocs };
}

// 4. CLIENT-SIDE PDF COMPILATION
// Inject jsPDF script library dynamically if it isn't loaded yet
function ensureJsPdfLoaded(callback) {
    if (typeof window.jspdf !== 'undefined') {
        callback();
        return;
    }
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js';
    script.onload = () => {
        setTimeout(callback, 200);
    };
    document.head.appendChild(script);
}

function downloadBillPDF(bill) {
    ensureJsPdfLoaded(() => {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        
        // ── Typography & Layout ──
        doc.setFillColor(15, 23, 42); // slate 900 background for top banner
        doc.rect(0, 0, 210, 40, 'F');
        
        // Header Banner
        doc.setTextColor(255, 255, 255);
        doc.setFont("Helvetica", "bold");
        doc.setFontSize(22);
        doc.text("PlanSphere Digital Vault", 15, 25);
        
        doc.setFont("Helvetica", "normal");
        doc.setFontSize(9);
        doc.text("Auto-Compiled Invoice Receipt", 150, 25);
        
        // Body Details
        doc.setTextColor(51, 65, 85); // slate 700 text color
        doc.setFontSize(11);
        
        let y = 60;
        const addRow = (label, val) => {
            doc.setFont("Helvetica", "bold");
            doc.text(label, 15, y);
            doc.setFont("Helvetica", "normal");
            doc.text(String(val || '—'), 75, y);
            y += 10;
        };
        
        addRow("Product Name:", bill.productName);
        addRow("Bill Number:", bill.billNumber);
        addRow("Category:", bill.category);
        addRow("Bill Type:", bill.type);
        addRow("Store / Vendor:", bill.storeName);
        addRow("Amount:", "INR " + parseFloat(bill.amount || 0).toLocaleString('en-IN'));
        addRow("Purchase Date:", bill.purchaseDate);
        
        const ws = getWarrantyStatus(bill.expiryDate);
        addRow("Warranty Expiry:", bill.expiryDate + ` (${ws.label})`);
        addRow("Days Remaining:", String(ws.daysLeft));
        
        // Attachment section
        if (bill.image && bill.image.startsWith("data:image")) {
            y += 10;
            doc.setFont("Helvetica", "bold");
            doc.text("Attached Receipt Preview:", 15, y);
            y += 10;
            try {
                // Render attached image onto the PDF
                doc.addImage(bill.image, 'JPEG', 15, y, 100, 75);
            } catch (e) {
                doc.setFont("Helvetica", "italic");
                doc.text("[Image preview compression failed - base64 source retained]", 15, y);
            }
        } else if (bill.image) {
            y += 10;
            doc.setFont("Helvetica", "italic");
            doc.text("PDF or file binary attachment was linked to this bill record.", 15, y);
        }
        
        // Save action
        doc.save(`PlanSphere_${bill.productName.replace(/\s+/g, '_')}_Bill.pdf`);
        showToast("PDF Download Complete!", "success");
    });
}

// ── WARRANTY CALCULATOR UTILS ────────────────────────────────
function getWarrantyStatus(expiryDateStr) {
    if (!expiryDateStr) return { status: 'none', label: 'No Warranty', daysLeft: 0, class: 'badge-muted', textClass: 'muted' };
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const expiry = new Date(expiryDateStr);
    expiry.setHours(0, 0, 0, 0);
    
    const diffTime = expiry - today;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays < 0) {
        return {
            status: 'expired',
            label: 'Expired',
            daysLeft: Math.abs(diffDays),
            class: 'badge-expired',
            textClass: 'expired'
        };
    } else if (diffDays <= 30) {
        return {
            status: 'warning',
            label: 'Near Expiry',
            daysLeft: diffDays,
            class: 'badge-warning',
            textClass: 'warning'
        };
    } else {
        return {
            status: 'protected',
            label: 'Protected',
            daysLeft: diffDays,
            class: 'badge-protected',
            textClass: 'protected'
        };
    }
}

// ── TOAST NOTIFICATIONS ───────────────────────────────────────
function showToast(message, type = 'success') {
    let toast = document.getElementById('app-toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'app-toast';
        document.body.appendChild(toast);
    }
    
    toast.className = `toast ${type} show`;
    toast.innerText = message;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// ── DYNAMIC SYSTEM ALERT CHECK ────────────────────────────────
function runSystemHealthChecks() {
    const bills = getBills();
    const today = new Date().toISOString().split('T')[0];
    
    // Find expiring soon warranties that do not have notifications yet
    bills.forEach(bill => {
        const ws = getWarrantyStatus(bill.expiryDate);
        if (ws.status === 'warning') {
            const notifs = getNotifications();
            const alreadyNotified = notifs.some(n => n.message.includes(bill.productName) && n.title.includes('Expiry'));
            if (!alreadyNotified) {
                addNotification({
                    title: '⚠️ Warranty Expiration Notice',
                    message: `Warranty for "${bill.productName}" is expiring in ${ws.daysLeft} days. Click details to check details.`,
                    read: false
                });
            }
        }
    });
}

// Run health alerts check after 1s
setTimeout(runSystemHealthChecks, 1000);
