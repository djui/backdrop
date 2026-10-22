(() => {
  document.documentElement.classList.add("js");

  const SPEEDS = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2];
  const FALLBACK = {
    tag: "v1.1.0",
    zip: "https://github.com/djui/backdrop/releases/download/v1.1.0/Backdrop-1.1.0.zip",
    name: "Backdrop-1.1.0.zip",
  };

  const mountainSVG = `
<svg viewBox="0 0 1600 900" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
  <path class="l1" d="M0 620 L180 480 L310 560 L480 390 L640 520 L820 340 L980 500 L1180 300 L1380 470 L1600 380 L1600 900 L0 900 Z"/>
  <path class="l2" d="M0 680 L220 540 L400 620 L560 470 L760 610 L960 430 L1160 580 L1360 450 L1600 540 L1600 900 L0 900 Z"/>
  <path class="l3" d="M0 760 L260 620 L480 720 L700 560 L940 700 L1180 580 L1420 680 L1600 620 L1600 900 L0 900 Z"/>
  <path class="l4" d="M0 820 L300 720 L540 800 L820 680 L1100 790 L1400 720 L1600 760 L1600 900 L0 900 Z"/>
</svg>`;

  document.querySelectorAll(".scene").forEach((scene) => {
    if (!scene.querySelector("svg")) {
      scene.insertAdjacentHTML("beforeend", mountainSVG);
    }
    const stars = scene.querySelector(".scene__stars");
    if (stars && !stars.children.length) {
      const count = scene.classList.contains("scene--hero") ? 48 : 22;
      for (let i = 0; i < count; i++) {
        const s = document.createElement("i");
        s.style.left = `${Math.random() * 100}%`;
        s.style.top = `${Math.random() * 100}%`;
        s.style.setProperty("--t", `${3 + Math.random() * 4}s`);
        s.style.setProperty("--delay", `${Math.random() * 4}s`);
        stars.appendChild(s);
      }
    }
  });

  const clock = document.getElementById("clock");
  function tick() {
    if (!clock) return;
    clock.textContent = new Date().toLocaleTimeString([], {
      hour: "numeric",
      minute: "2-digit",
    });
  }
  tick();
  setInterval(tick, 15_000);

  const toggle = document.getElementById("menuToggle");
  const popover = document.getElementById("menuPopover");
  const playPause = document.getElementById("heroPlayPause");

  function closePopover() {
    if (!popover || !toggle) return;
    popover.hidden = true;
    toggle.setAttribute("aria-expanded", "false");
  }

  toggle?.addEventListener("click", (e) => {
    e.stopPropagation();
    const open = popover.hidden;
    popover.hidden = !open;
    toggle.setAttribute("aria-expanded", String(open));
  });

  document.addEventListener("click", (e) => {
    if (!popover || popover.hidden) return;
    if (!popover.contains(e.target) && e.target !== toggle) closePopover();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closePopover();
  });

  let heroPlaying = true;
  playPause?.addEventListener("click", () => {
    heroPlaying = !heroPlaying;
    playPause.textContent = heroPlaying ? "Pause" : "Play";
    document.querySelectorAll(".scene").forEach((s) => {
      s.classList.toggle("is-paused", !heroPlaying);
    });
    closePopover();
  });

  const speed = document.getElementById("speed");
  const speedOut = document.getElementById("speedOut");

  function applySpeed(index) {
    const rate = SPEEDS[index] ?? 1;
    if (speedOut) speedOut.textContent = `${rate}×`;
    if (speed) {
      speed.setAttribute("aria-valuetext", `${rate}×`);
      speed.style.setProperty("--p", `${(index / (SPEEDS.length - 1)) * 100}%`);
    }
    document.querySelectorAll(".scene__stars i").forEach((star) => {
      const base = parseFloat(star.style.getPropertyValue("--t")) || 4;
      star.style.animationDuration = `${base / Math.max(rate, 0.25)}s`;
    });
  }

  speed?.addEventListener("input", () => applySpeed(Number(speed.value)));
  applySpeed(Number(speed?.value ?? 3));

  const clips = document.getElementById("clips");
  clips?.addEventListener("click", (e) => {
    const item = e.target.closest("[role=option]");
    if (!item) return;
    selectClip(item);
  });
  clips?.addEventListener("keydown", (e) => {
    const items = [...clips.querySelectorAll("[role=option]")];
    const current = clips.querySelector('[aria-selected="true"]');
    const i = items.indexOf(current);
    if (e.key === "ArrowDown" || e.key === "ArrowRight") {
      e.preventDefault();
      selectClip(items[(i + 1) % items.length]);
    } else if (e.key === "ArrowUp" || e.key === "ArrowLeft") {
      e.preventDefault();
      selectClip(items[(i - 1 + items.length) % items.length]);
    } else if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      if (current) selectClip(current);
    }
  });

  function selectClip(item) {
    clips.querySelectorAll("[role=option]").forEach((el) => {
      el.setAttribute("aria-selected", String(el === item));
      el.tabIndex = el === item ? 0 : -1;
    });
    item.focus({ preventScroll: true });
    const palette = item.dataset.palette;
    document.querySelectorAll("[data-scene]").forEach((scene) => {
      if (scene.dataset.scene === "pace" || scene.dataset.scene === "rest") return;
      scene.dataset.palette = palette;
    });
    const library = document.querySelector('[data-scene="library"]');
    if (library) library.dataset.palette = palette;
  }

  const restScene = document.querySelector('[data-scene="rest"]');
  const restBadge = document.getElementById("restBadge");
  const pauseBattery = document.getElementById("pauseBattery");
  const lowPower = document.getElementById("lowPower");
  let onBattery = false;

  document.querySelectorAll("[data-power]").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-power]").forEach((b) => {
        b.setAttribute("aria-checked", String(b === btn));
      });
      onBattery = btn.dataset.power === "battery";
      updateRest();
    });
  });
  pauseBattery?.addEventListener("change", updateRest);
  lowPower?.addEventListener("change", updateRest);

  function updateRest() {
    const shouldPause =
      (pauseBattery?.checked && onBattery) || Boolean(lowPower?.checked);
    restScene?.classList.toggle("is-paused", shouldPause);
    if (restBadge) restBadge.hidden = !shouldPause;
  }

  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-in"));
  }

  document.querySelectorAll("[data-copy]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const target = document.querySelector(btn.getAttribute("data-copy"));
      if (!target) return;
      try {
        await navigator.clipboard.writeText(target.textContent.trim());
        const prev = btn.textContent;
        btn.textContent = "Copied";
        setTimeout(() => {
          btn.textContent = prev;
        }, 1400);
      } catch {
        /* ignore */
      }
    });
  });

  function applyRelease(info) {
    document.querySelectorAll("[data-version]").forEach((el) => {
      el.textContent = info.tag;
    });
    document.querySelectorAll("[data-asset]").forEach((el) => {
      el.textContent = info.name;
    });
    document.querySelectorAll("[data-download]").forEach((el) => {
      el.setAttribute("href", info.zip);
    });
  }

  applyRelease(FALLBACK);

  fetch("https://api.github.com/repos/djui/backdrop/releases/latest")
    .then((r) => (r.ok ? r.json() : Promise.reject()))
    .then((data) => {
      const zip = (data.assets || []).find((a) =>
        /\.zip$/i.test(a.name || "")
      );
      if (!zip) return;
      applyRelease({
        tag: data.tag_name,
        zip: zip.browser_download_url,
        name: zip.name,
      });
    })
    .catch(() => {});
})();
