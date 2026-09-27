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

const revealShaderLoading = () => {
    document.querySelector(".shader-loading")?.classList.add("is-ready");
};

const setupCloudShader = async () => {
    let hasFinishedLoading = false;
    const loadingTimeout = window.setTimeout(revealShaderLoading, 6000);
    const finishLoading = () => {
        if (hasFinishedLoading) {
            return;
        }

        hasFinishedLoading = true;
        window.clearTimeout(loadingTimeout);
        window.requestAnimationFrame(revealShaderLoading);
    };
    const canvas = document.querySelector(".cloud-shader");

    if (!canvas) {
        finishLoading();
        return;
    }

    const response = await fetch("./res/cloud-shader.glsl");

    if (!response.ok) {
        finishLoading();
        return;
    }

    const fragmentSource = await response.text();
    const gl = canvas.getContext("webgl", {
        alpha: true,
        antialias: false,
        depth: false,
        premultipliedAlpha: false,
        stencil: false,
    });

    if (!gl) {
        finishLoading();
        return;
    }

    const compileShader = (type, source) => {
        const shader = gl.createShader(type);
        gl.shaderSource(shader, source);
        gl.compileShader(shader);

        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            gl.deleteShader(shader);
            return null;
        }

        return shader;
    };

    const vertexShader = compileShader(
        gl.VERTEX_SHADER,
        `attribute vec2 a_position;

void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
}`,
    );
    const fragmentShader = compileShader(gl.FRAGMENT_SHADER, fragmentSource);

    if (!vertexShader || !fragmentShader) {
        finishLoading();
        return;
    }

    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        finishLoading();
        return;
    }

    const positionLocation = gl.getAttribLocation(program, "a_position");
    const resolutionLocation = gl.getUniformLocation(program, "iResolution");
    const timeLocation = gl.getUniformLocation(program, "iTime");
    const positionBuffer = gl.createBuffer();

    gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
        gl.STATIC_DRAW,
    );
    gl.useProgram(program);
    gl.enableVertexAttribArray(positionLocation);
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);
    gl.clearColor(0, 0, 0, 0);

    const resizeCanvas = () => {
        const area = Math.max(1, canvas.clientWidth * canvas.clientHeight);
        const pixelRatio = Math.min(window.devicePixelRatio || 1, 0.35, Math.sqrt(200000 / area));
        const width = Math.max(1, Math.round(canvas.clientWidth * pixelRatio));
        const height = Math.max(1, Math.round(canvas.clientHeight * pixelRatio));

        if (canvas.width === width && canvas.height === height) {
            return;
        }

        canvas.width = width;
        canvas.height = height;
        gl.viewport(0, 0, width, height);
    };

    const render = (time) => {
        resizeCanvas();
        gl.uniform2f(resolutionLocation, canvas.width, canvas.height);
        gl.uniform1f(timeLocation, time);
        gl.drawArrays(gl.TRIANGLES, 0, 6);
    };

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        render(0);
        finishLoading();
        window.addEventListener("resize", () => render(0));
        return;
    }

    const frameInterval = 1000 / 24;
    let animationFrame;
    let lastRenderTime;
    let startTime;
    const animate = (timestamp) => {
        if (lastRenderTime === undefined || timestamp - lastRenderTime >= frameInterval) {
            startTime ??= timestamp;
            render((timestamp - startTime) / 1000);
            finishLoading();
            lastRenderTime = timestamp;
        }

        animationFrame = window.requestAnimationFrame(animate);
    };

    const startAnimation = () => {
        if (animationFrame === undefined) {
            animationFrame = window.requestAnimationFrame(animate);
        }
    };

    const stopAnimation = () => {
        if (animationFrame === undefined) {
            return;
        }

        window.cancelAnimationFrame(animationFrame);
        animationFrame = undefined;
    };

    document.addEventListener("visibilitychange", () => {
        if (document.hidden) {
            stopAnimation();
            return;
        }

        startTime = undefined;
        lastRenderTime = undefined;
        startAnimation();
    });
    startAnimation();
};

setupCloudShader().catch(() => revealShaderLoading());

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
