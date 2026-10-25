const d = document;
const $q = (s) => [...d.querySelectorAll(s)];
const $g = d.querySelector.bind(d);
const $prev = $g(".prev");
const $next = $g(".next");
let auto;

const getItems = () => $q(".carousel__item");

const getActiveIndex = () => {
    const items = getItems();
    return items.findIndex(el => el.hasAttribute("data-active"));
};

const activateSlide = (index) => {
    const items = getItems();
    const total = items.length;
    const i = ((index % total) + total) % total;
    items.forEach(el => el.removeAttribute("data-active"));
    items[i].setAttribute("data-active", true);
    items[i].focus();
};

const nextSlide = () => activateSlide(getActiveIndex() + 1);
const prevSlide = () => activateSlide(getActiveIndex() - 1);

const pauseAuto = () => clearInterval(auto);

const handleNextClick = () => { pauseAuto(); nextSlide(); };
const handlePrevClick = () => { pauseAuto(); prevSlide(); };

const handleSlideClick = (e) => {
    const $slide = e.target.closest(".carousel__item");
    if (!$slide) return;
    pauseAuto();
    const index = getItems().indexOf($slide);
    activateSlide(index);
};

const handleSlideKey = (e) => {
    if ([37, 65].includes(e.keyCode)) handlePrevClick();
    if ([39, 68].includes(e.keyCode)) handleNextClick();
};

const startAuto = () => { auto = setInterval(nextSlide, 3000); };

startAuto();

$next.addEventListener("click", handleNextClick);
$prev.addEventListener("click", handlePrevClick);
$g(".carousel__list").addEventListener("click", handleSlideClick);
d.addEventListener("keyup", handleSlideKey);

// ── Music toggle on GENERALS click ──
const audio = d.getElementById("bg-music");
const hint  = d.getElementById("music-hint");
const heading = d.getElementById("generals-heading");

heading.addEventListener("click", () => {
    if (audio.paused) {
        audio.play();
        hint.textContent = "♪ now playing — click to pause";
        hint.classList.add("playing");
    } else {
        audio.pause();
        hint.textContent = "♪ click to play";
        hint.classList.remove("playing");
    }
});
