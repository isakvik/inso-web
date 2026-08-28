const contentSections = [...document.querySelectorAll(".main-content-views > div")];
const contentTransitionDuration = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 180;
let currentSection;
let enterFrame;
let hideTimer;

const hideSection = (section) => {
    section.hidden = true;
    section.classList.remove("is-entering", "is-leaving");
};

const showSection = (name) => {
    const activeClass = `main-content-${name}`;
    const nextSection = contentSections.find((section) => section.classList.contains(activeClass)) || contentSections[0];

    if (nextSection === currentSection) {
        return;
    }

    const previousSection = currentSection;
    currentSection = nextSection;
    window.clearTimeout(hideTimer);
    window.cancelAnimationFrame(enterFrame);

    for (const section of contentSections) {
        if (section !== previousSection && section !== nextSection) {
            hideSection(section);
        }
    }

    nextSection.classList.remove("is-entering", "is-leaving");

    if (!previousSection) {
        nextSection.hidden = false;
        return;
    }

    previousSection.classList.remove("is-entering");
    previousSection.classList.add("is-leaving");
    nextSection.classList.add("is-entering");
    nextSection.hidden = false;

    enterFrame = window.requestAnimationFrame(() => {
        if (currentSection === nextSection) {
            nextSection.classList.remove("is-entering");
        }
    });

    hideTimer = window.setTimeout(() => {
        if (currentSection === nextSection) {
            hideSection(previousSection);
        }
    }, contentTransitionDuration);
};

const showSectionFromHash = () => {
    showSection(window.location.hash.slice(1) || "home");
};

for (const link of document.querySelectorAll('.nav-link[href^="#"]')) {
    link.addEventListener("click", (event) => {
        const name = link.hash.slice(1);
        const targetClass = `main-content-${name}`;

        if (!contentSections.some((section) => section.classList.contains(targetClass))) {
            return;
        }

        event.preventDefault();
        if (window.location.hash !== link.hash) {
            window.history.pushState(null, "", link.hash);
        }
        showSection(name);
    });
}

window.addEventListener("hashchange", showSectionFromHash);
window.addEventListener("popstate", showSectionFromHash);
showSectionFromHash();
