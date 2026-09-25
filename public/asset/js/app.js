document.addEventListener('DOMContentLoaded', function () {
  const evacuationNeeded = document.getElementById('evacuationNeeded');
  const evacuationCenterBox = document.getElementById('evacuationCenterBox');

  function toggleEvacuationCenter() {
    if (!evacuationNeeded || !evacuationCenterBox) return;
    evacuationCenterBox.style.opacity = evacuationNeeded.value === 'Yes' ? '1' : '.55';
  }

  if (evacuationNeeded) {
    evacuationNeeded.addEventListener('change', toggleEvacuationCenter);
    toggleEvacuationCenter();
  }
});


/* Password show/hide */
document.addEventListener('DOMContentLoaded', function () {
  document.querySelectorAll('.password-toggle-btn').forEach(function (button) {
    button.addEventListener('click', function () {
      const targetId = button.getAttribute('data-target');
      const input = document.getElementById(targetId);
      if (!input) return;

      if (input.type === 'password') {
        input.type = 'text';
        button.textContent = '🙈';
      } else {
        input.type = 'password';
        button.textContent = '👁';
      }
    });
  });
});

