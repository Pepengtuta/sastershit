document.addEventListener("DOMContentLoaded", function() {
    
    // 1. Generate empty rows for Family Members (6 rows)
    const familyBody = document.getElementById('familyMembersBody');
    let memberCount = 0;

    function addFamilyRow() {
        memberCount++;
        const i = memberCount;
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td><input type="text" name="member_${i}_name"></td>
            <td><input type="text" name="member_${i}_relation" style="width: 100%;"></td>
            <td><input type="text" name="member_${i}_age" id="member_${i}_age" class="table-age"></td>
            <td><input type="text" name="member_${i}_sex"></td>
            <td><input type="text" name="member_${i}_education"></td>
            <td><input type="text" name="member_${i}_skills"></td>
            <td><input type="text" name="member_${i}_remarks"></td>
        `;
        familyBody.appendChild(tr);
    }

    for (let i = 1; i <= 6; i++) {
        addFamilyRow();
    }

    // Bind Add Row Button
    const btnAddFamilyRow = document.getElementById('btnAddFamilyRow');
    if (btnAddFamilyRow) {
        btnAddFamilyRow.addEventListener('click', () => {
            addFamilyRow();
        });
    }

    // 2. Generate empty rows for Assistance (3 rows)
    const assistBody = document.getElementById('assistanceBody');
    let assistCount = 0;

    function addAssistanceRow() {
        assistCount++;
        const i = assistCount;
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td><input type="date" name="assist_${i}_date" class="table-date"></td>
            <td><input type="text" name="assist_${i}_member"></td>
            <td><input type="text" name="assist_${i}_type"></td>
            <td><input type="number" name="assist_${i}_qty"></td>
            <td><input type="number" name="assist_${i}_cost" placeholder="₱"></td>
            <td><input type="text" name="assist_${i}_provider"></td>
            <td></td>
        `;
        assistBody.appendChild(tr);
    }

    for (let i = 1; i <= 3; i++) {
        addAssistanceRow();
    }

    // Bind Add Assistance Row Button
    const btnAddAssistanceRow = document.getElementById('btnAddAssistanceRow');
    if (btnAddAssistanceRow) {
        btnAddAssistanceRow.addEventListener('click', () => {
            addAssistanceRow();
        });
    }

    // 3. Auto-calculate Age function
    function calculateAge(dobInput, ageInputId) {
        if (!dobInput.value) {
            document.getElementById(ageInputId).value = '';
            return;
        }
        
        const dob = new Date(dobInput.value);
        const today = new Date();
        let age = today.getFullYear() - dob.getFullYear();
        const m = today.getMonth() - dob.getMonth();
        
        if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) {
            age--;
        }
        
        document.getElementById(ageInputId).value = age >= 0 ? age : '';
    }

    // Bind age calculation to Head of Family DOB
    const headDob = document.getElementById('head_dob');
    headDob.addEventListener('change', function() {
        calculateAge(this, 'head_age');
    });

    // (Family members age calculation removed since DOB was removed)

    // 4. Button Actions
    const form = document.getElementById('dafacForm');
    
    function validateForm() {
        if (!form.checkValidity()) {
            form.reportValidity();
            return false;
        }
        return true;
    }

    function showNotification(msg) {
        const notif = document.getElementById('saveNotification');
        notif.textContent = msg;
        notif.style.display = 'block';
        setTimeout(() => {
            notif.style.display = 'none';
        }, 3000);
    }

    document.getElementById('btnSave').addEventListener('click', () => {
        if (validateForm()) {
            showNotification("Form Data Saved Locally!");
            console.log("Saving form data...");
        }
    });

    document.getElementById('btnNext').addEventListener('click', () => {
        if (validateForm()) {
            showNotification("Saved! Loading next form...");
            setTimeout(() => {
                form.reset();
                window.scrollTo(0,0);
            }, 1000);
        }
    });

    document.getElementById('btnPrint').addEventListener('click', () => {
        if (validateForm()) {
            window.print();
        }
    });

    document.getElementById('btnCancel').addEventListener('click', () => {
        if(confirm("Are you sure you want to cancel? Unsaved data will be lost.")) {
            form.reset();
            window.scrollTo(0,0);
        }
    });

    // Simulated Auto-save every 30 seconds if form is dirty
    let isDirty = false;
    form.addEventListener('change', () => isDirty = true);
    
    setInterval(() => {
        if (isDirty) {
            console.log("Auto-saving...");
            // Simulate saving to local storage or backend
            isDirty = false;
        }
    }, 30000);
});
