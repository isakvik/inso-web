const setupSectionNavigation = ({ sectionSelector, linkSelector, sectionClassPrefix, defaultSection }) => {
    const contentSections = [...document.querySelectorAll(sectionSelector)];

    if (!contentSections.length) {
        return;
    }

    const links = [...document.querySelectorAll(linkSelector)];
    const contentTransitionDuration = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? 0 : 180;
    let currentSection;
    let enterFrame;
    let hideTimer;

    const hideSection = (section) => {
        section.hidden = true;
        section.classList.remove("is-entering", "is-leaving");
    };

    const updateActiveLink = (name) => {
        for (const link of links) {
            if (link.hash.slice(1) === name) {
                link.setAttribute("aria-current", "page");
            } else {
                link.removeAttribute("aria-current");
            }
        }
    };

    const showSection = (name) => {
        const activeClass = `${sectionClassPrefix}-${name}`;
        const nextSection = contentSections.find((section) => section.classList.contains(activeClass)) || contentSections[0];

        if (nextSection === currentSection) {
            updateActiveLink(nextSection.className.split(" ").find((className) => className.startsWith(`${sectionClassPrefix}-`)).slice(sectionClassPrefix.length + 1));
            return;
        }

        const previousSection = currentSection;
        const nextName = nextSection.className.split(" ").find((className) => className.startsWith(`${sectionClassPrefix}-`)).slice(sectionClassPrefix.length + 1);
        currentSection = nextSection;
        window.clearTimeout(hideTimer);
        window.cancelAnimationFrame(enterFrame);
        updateActiveLink(nextName);

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
        showSection(window.location.hash.slice(1) || defaultSection);
    };

    for (const link of links) {
        link.addEventListener("click", (event) => {
            const name = link.hash.slice(1);
            const targetClass = `${sectionClassPrefix}-${name}`;

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
};

setupSectionNavigation({
    sectionSelector: ".main-content-views > div",
    linkSelector: '.nav-link[href^="#"]',
    sectionClassPrefix: "main-content",
    defaultSection: "home",
});

const setupDocsTreeHighlight = () => {
    const tree = document.querySelector(".docs-tree-nav");

    if (!tree) {
        return;
    }

    const links = [...tree.querySelectorAll(".docs-nav-link")];
    const rootList = tree.querySelector("ul");

    const getLinkMidpoint = (link) => Math.round(link.offsetTop + link.offsetHeight / 2);

    const setLinkIndents = () => {
        for (const link of links) {
            let indent = 0;
            let list = link.closest("ul");

            while (list && list !== rootList) {
                const padding = Number.parseFloat(window.getComputedStyle(list).paddingLeft);
                if (Number.isFinite(padding)) {
                    indent += padding;
                }
                list = list.parentElement ? list.parentElement.closest("ul") : null;
            }

            link.style.setProperty("--docs-tree-indent", `${indent}px`);
        }
    };

    const setActiveHighlight = () => {
        const link = tree.querySelector('a[aria-current="page"]');
        const height = link ? getLinkMidpoint(link) : 0;
        tree.style.setProperty("--docs-tree-active-height", `${height}px`);
    };

    const setHoverHighlight = (link) => {
        const height = link ? getLinkMidpoint(link) : 0;
        tree.style.setProperty("--docs-tree-hover-height", `${height}px`);
    };

    for (const link of links) {
        link.addEventListener("pointerenter", () => setHoverHighlight(link));
        link.addEventListener("focus", () => setHoverHighlight(link));
        link.addEventListener("pointerleave", (event) => {
            const isEnteringLink = event.relatedTarget instanceof Element && links.some((otherLink) => otherLink.contains(event.relatedTarget));

            if (!isEnteringLink) {
                setHoverHighlight(null);
            }
        });
    }

    tree.addEventListener("pointerleave", () => setHoverHighlight(null));
    tree.addEventListener("focusout", (event) => {
        if (!tree.contains(event.relatedTarget)) {
            setHoverHighlight(null);
        }
    });

    window.addEventListener("resize", () => {
        setLinkIndents();
        setActiveHighlight();
    });
    setLinkIndents();
    setActiveHighlight();
};

setupDocsTreeHighlight();
