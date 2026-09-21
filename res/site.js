const setupSectionNavigation = ({ sectionSelector, linkSelector, rootLinkSelector, sectionClassPrefix, defaultSection }) => {
    const contentSections = [...document.querySelectorAll(sectionSelector)];

    if (!contentSections.length) {
        return;
    }

    const links = [...document.querySelectorAll(linkSelector)];
    const rootLink = rootLinkSelector ? document.querySelector(rootLinkSelector) : null;
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

        if (rootLink) {
            if (name === defaultSection) {
                rootLink.setAttribute("aria-current", "page");
            } else {
                rootLink.removeAttribute("aria-current");
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

setupSectionNavigation({
    sectionSelector: ".docs-content-views > section",
    linkSelector: '.docs-nav-link[href^="#"]',
    rootLinkSelector: ".docs-tree-root",
    sectionClassPrefix: "docs-content",
    defaultSection: "overview",
});

const setupDocsBackLink = () => {
    const link = document.querySelector(".docs-back-top");
    const tree = document.querySelector(".docs-tree-nav");

    if (!link || !tree) {
        return;
    }

    const updateTarget = () => {
        const activeLink = tree.querySelector('a[aria-current="page"]');

        if (activeLink) {
            link.href = activeLink.hash;
        }
    };

    link.addEventListener("click", (event) => {
        const target = document.getElementById(link.hash.slice(1));

        if (!target) {
            return;
        }

        event.preventDefault();
        target.scrollIntoView({
            behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
            block: "start",
        });
    });

    const observer = new MutationObserver(updateTarget);
    observer.observe(tree, { subtree: true, attributes: true, attributeFilter: ["aria-current"] });
    updateTarget();
};

setupDocsBackLink();

const setupDocsTreeHighlight = () => {
    const tree = document.querySelector(".docs-tree-nav");

    if (!tree) {
        return;
    }

    const links = [...tree.querySelectorAll("a")];

    const getLinkMidpoint = (link) => Math.round(link.offsetTop + link.offsetHeight / 2);

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

    const observer = new MutationObserver(setActiveHighlight);
    observer.observe(tree, { subtree: true, attributes: true, attributeFilter: ["aria-current"] });
    window.addEventListener("resize", setActiveHighlight);
    setActiveHighlight();
};

setupDocsTreeHighlight();
