"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { toPng } from "html-to-image";

// ─── Canvas dimensions ────────────────────────────────────────────────────────
const IPHONE_W = 1320;
const IPHONE_H = 2868;
const IPAD_W = 2064;
const IPAD_H = 2752;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

const IPAD_SIZES = [
  { label: '13" iPad', w: 2064, h: 2752 },
  { label: '12.9" iPad Pro', w: 2048, h: 2732 },
] as const;

// ─── Phone mockup offsets (pre-measured) ─────────────────────────────────────
const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

// ─── Themes ───────────────────────────────────────────────────────────────────
const THEMES = {
  "dark-epic": {
    bg: "#0D0D0F",
    bg2: "#1A1A20",
    fg: "#F5F5F5",
    accent: "#FFD700",
    muted: "#A0A0B0",
    glow: "rgba(255, 215, 0, 0.22)",
    pillBorder: "rgba(255,215,0,0.22)",
    pillBg: "rgba(255,215,0,0.07)",
  },
  "gold-warmth": {
    bg: "#130C00",
    bg2: "#1F1500",
    fg: "#F5F0E0",
    accent: "#FFD700",
    muted: "#C4A050",
    glow: "rgba(255, 200, 0, 0.3)",
    pillBorder: "rgba(255,215,0,0.3)",
    pillBg: "rgba(255,215,0,0.1)",
  },
} as const;
type ThemeId = keyof typeof THEMES;
type Theme = (typeof THEMES)[ThemeId];

// ─── Screenshot paths ─────────────────────────────────────────────────────────
const IPHONE = {
  mainDark: "/screenshots/iphone/main_dark.png",
  mainLight: "/screenshots/iphone/main_light.png",
  buildingsDark: "/screenshots/iphone/buildings_dark.png",
  buildingsLight: "/screenshots/iphone/buildings_light.png",
  offlineDark: "/screenshots/iphone/offline_dark.png",
  offlineLight: "/screenshots/iphone/offline_light.png",
  achievementsDark: "/screenshots/iphone/achievements_dark.png",
  achievementsLight: "/screenshots/iphone/achievements_light.png",
};

const IPAD = {
  mainDark: "/screenshots/ipad/main_dark.png",
  mainLight: "/screenshots/ipad/main_light.png",
  achievementsDark: "/screenshots/ipad/achievements_dark.png",
  achievementsLight: "/screenshots/ipad/achievements_light.png",
};

// ─── Phone mockup ─────────────────────────────────────────────────────────────
function Phone({ src, alt, style }: { src: string; alt: string; style?: React.CSSProperties }) {
  return (
    <div style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/mockup.png" alt="" style={{ display: "block", width: "100%", height: "100%" }} draggable={false} />
      <div style={{
        position: "absolute", zIndex: 10, overflow: "hidden",
        left: `${SC_L}%`, top: `${SC_T}%`,
        width: `${SC_W}%`, height: `${SC_H}%`,
        borderRadius: `${SC_RX}% / ${SC_RY}%`,
      }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={alt} style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} draggable={false} />
      </div>
    </div>
  );
}

// ─── iPad mockup (CSS-only) ───────────────────────────────────────────────────
function IPad({ src, alt, style }: { src: string; alt: string; style?: React.CSSProperties }) {
  return (
    <div style={{ position: "relative", aspectRatio: "770/1000", ...style }}>
      <div style={{
        width: "100%", height: "100%",
        borderRadius: "5% / 3.6%",
        background: "linear-gradient(180deg,#2C2C2E 0%,#1C1C1E 100%)",
        position: "relative", overflow: "hidden",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 40px rgba(0,0,0,0.6)",
      }}>
        <div style={{ position: "absolute", top: "1.2%", left: "50%", transform: "translateX(-50%)", width: "0.9%", height: "0.65%", borderRadius: "50%", background: "#111113", border: "1px solid rgba(255,255,255,0.08)", zIndex: 20 }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: "5% / 3.6%", border: "1px solid rgba(255,255,255,0.06)", pointerEvents: "none", zIndex: 15 }} />
        <div style={{ position: "absolute", left: "4%", top: "2.8%", width: "92%", height: "94.4%", borderRadius: "2.2% / 1.6%", overflow: "hidden", background: "#000" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={src} alt={alt} style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} draggable={false} />
        </div>
      </div>
    </div>
  );
}

// ─── Caption ──────────────────────────────────────────────────────────────────
function Caption({ label, headline, sub, canvasW, theme, align = "left" }: {
  label: string;
  headline: React.ReactNode;
  sub?: string;
  canvasW: number;
  theme: Theme;
  align?: "left" | "center";
}) {
  return (
    <div style={{ textAlign: align }}>
      <div style={{
        fontFamily: "var(--font-inter), sans-serif",
        fontSize: canvasW * 0.027,
        fontWeight: 600,
        letterSpacing: "0.13em",
        textTransform: "uppercase",
        color: theme.accent,
        marginBottom: canvasW * 0.016,
      }}>{label}</div>
      <div style={{
        fontFamily: "var(--font-playfair), Georgia, serif",
        fontSize: canvasW * 0.093,
        fontWeight: 700,
        lineHeight: 1.0,
        color: theme.fg,
      }}>{headline}</div>
      {sub && (
        <div style={{
          fontFamily: "var(--font-inter), sans-serif",
          fontSize: canvasW * 0.031,
          color: theme.muted,
          marginTop: canvasW * 0.028,
          lineHeight: 1.5,
        }}>{sub}</div>
      )}
    </div>
  );
}

// ─── Glow orb ─────────────────────────────────────────────────────────────────
function Glow({ x, y, size, color, blur = 80, opacity = 1 }: {
  x: string; y: string; size: string; color: string; blur?: number; opacity?: number;
}) {
  return (
    <div style={{
      position: "absolute", left: x, top: y, width: size, height: size,
      borderRadius: "50%", background: color, opacity,
      filter: `blur(${blur}px)`, pointerEvents: "none",
    }} />
  );
}

// ─── Slide props ──────────────────────────────────────────────────────────────
type SlideProps = { W: number; H: number; theme: Theme; device: "iphone" | "ipad" };

// ─── SLIDE 1: Hero ────────────────────────────────────────────────────────────
function Slide1({ W, H, theme, device }: SlideProps) {
  const src = device === "ipad" ? IPAD.mainDark : IPHONE.mainDark;
  const phoneW = device === "ipad" ? W * 0.60 : W * 0.84;

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `radial-gradient(ellipse at 50% 110%, #2a1800 0%, ${theme.bg} 60%)` }}>
      <Glow x="5%" y="50%" size={`${W * 0.9}px`} color="#7a4500" opacity={0.25} />
      <Glow x="25%" y="70%" size={`${W * 0.4}px`} color="#FFD700" opacity={0.08} />

      {/* App icon + name */}
      <div style={{ display: "flex", alignItems: "center", gap: W * 0.036,
        padding: `${H * 0.072}px ${W * 0.1}px 0` }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/app-icon.png" alt="" style={{
          width: W * 0.13, height: W * 0.13,
          borderRadius: W * 0.026,
          boxShadow: `0 0 ${W * 0.05}px ${theme.glow}`,
        }} draggable={false} />
        <div>
          <div style={{ fontFamily: "var(--font-playfair), serif", fontSize: W * 0.046,
            fontWeight: 700, color: theme.fg, lineHeight: 1.1 }}>Idle Civilizations</div>
          <div style={{ fontFamily: "var(--font-inter), sans-serif", fontSize: W * 0.024,
            color: theme.accent, letterSpacing: "0.08em", textTransform: "uppercase",
            marginTop: W * 0.008 }}>Build History. Earn Gold.</div>
        </div>
      </div>

      {/* Headline */}
      <div style={{ padding: `${H * 0.055}px ${W * 0.1}px 0` }}>
        <Caption label="Idle Strategy Game"
          headline={<>Build History.<br />Earn Gold.</>}
          canvasW={W} theme={theme} />
      </div>

      {/* Phone */}
      <div style={{ position: "absolute", bottom: 0, left: "50%",
        transform: "translateX(-50%) translateY(12%)", width: phoneW }}>
        {device === "ipad" ? <IPad src={src} alt="Gameplay" /> : <Phone src={src} alt="Gameplay" />}
      </div>
    </div>
  );
}

// ─── SLIDE 2: Offline income ──────────────────────────────────────────────────
function Slide2({ W, H, theme, device }: SlideProps) {
  const src = device === "ipad" ? IPAD.mainLight : IPHONE.offlineDark;
  const phoneW = device === "ipad" ? W * 0.60 : W * 0.84;

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `radial-gradient(ellipse at 50% -10%, #201200 0%, ${theme.bg} 55%)` }}>
      <Glow x="0%" y="-15%" size={`${W * 0.9}px`} color="#b06000" opacity={0.2} />
      <Glow x="30%" y="10%" size={`${W * 0.35}px`} color="#FFD700" opacity={0.07} />

      <div style={{ position: "absolute", top: H * 0.08, left: W * 0.1, right: W * 0.1, textAlign: "center" }}>
        <Caption label="Idle Income"
          headline={<>Earn Gold.<br />Even Offline.</>}
          sub={"Your empire never stops.\nCome back to mountains of gold."}
          canvasW={W} theme={theme} align="center" />
      </div>

      <div style={{ position: "absolute", bottom: 0, left: "50%",
        transform: "translateX(-50%) translateY(14%)", width: phoneW }}>
        {device === "ipad" ? <IPad src={src} alt="Offline income" /> : <Phone src={src} alt="Offline income" />}
      </div>
    </div>
  );
}

// ─── SLIDE 3: Buildings ───────────────────────────────────────────────────────
function Slide3({ W, H, theme, device }: SlideProps) {
  const src = device === "ipad" ? IPAD.mainDark : IPHONE.buildingsDark;
  const phoneW = device === "ipad" ? W * 0.58 : W * 0.80;

  const eras = ["Stone Age", "Bronze Age", "Classical World", "Medieval Era",
    "Renaissance", "Industrial Revolution", "Space Age", "+ More"];

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `linear-gradient(155deg, #080c14 0%, ${theme.bg} 50%, #0f0800 100%)` }}>
      <Glow x="-10%" y="30%" size={`${W * 0.65}px`} color="#001860" opacity={0.45} />
      <Glow x="55%" y="65%" size={`${W * 0.45}px`} color="#b87900" opacity={0.15} />

      {/* Caption left */}
      <div style={{ padding: `${H * 0.09}px ${W * 0.1}px 0` }}>
        <Caption label="8 Historical Eras"
          headline={<>40+ Buildings.<br />One Empire.</>}
          canvasW={W} theme={theme} />

        {/* Era chips */}
        <div style={{ display: "flex", flexWrap: "wrap", gap: W * 0.018, marginTop: H * 0.038 }}>
          {eras.map(era => (
            <div key={era} style={{
              fontFamily: "var(--font-inter), sans-serif",
              fontSize: W * 0.026,
              color: era === "+ More" ? theme.accent : theme.muted,
              background: era === "+ More" ? theme.pillBg : "rgba(255,255,255,0.05)",
              border: `1px solid ${era === "+ More" ? theme.pillBorder : "rgba(255,255,255,0.1)"}`,
              borderRadius: W * 0.05,
              padding: `${W * 0.013}px ${W * 0.027}px`,
            }}>{era}</div>
          ))}
        </div>
      </div>

      {/* Phone right */}
      <div style={{ position: "absolute", bottom: 0, right: `-${W * 0.02}px`,
        transform: "translateY(10%)", width: phoneW }}>
        {device === "ipad" ? <IPad src={src} alt="Buildings" /> : <Phone src={src} alt="Buildings" />}
      </div>
    </div>
  );
}

// ─── SLIDE 4: Achievements (contrast — lighter bg) ────────────────────────────
function Slide4({ W, H, theme, device }: SlideProps) {
  const src = device === "ipad" ? IPAD.achievementsDark : IPHONE.achievementsDark;
  const phoneW = device === "ipad" ? W * 0.60 : W * 0.84;

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `radial-gradient(ellipse at 50% 105%, #0f1a00 0%, #080808 65%)` }}>
      <Glow x="10%" y="60%" size={`${W * 0.7}px`} color="#3a6600" opacity={0.2} />
      <Glow x="50%" y="80%" size={`${W * 0.3}px`} color="#FFD700" opacity={0.07} />

      <div style={{ position: "absolute", top: H * 0.08, left: W * 0.1, right: W * 0.1, textAlign: "center" }}>
        <Caption label="Achievements"
          headline={<>30 Milestones.<br />Unlock Them All.</>}
          sub="Track every accomplishment. Prove your legacy."
          canvasW={W} theme={theme} align="center" />
      </div>

      <div style={{ position: "absolute", bottom: 0, left: "50%",
        transform: "translateX(-50%) translateY(13%)", width: phoneW }}>
        {device === "ipad" ? <IPad src={src} alt="Achievements" /> : <Phone src={src} alt="Achievements" />}
      </div>
    </div>
  );
}

// ─── SLIDE 5: Two phones – dark & light ───────────────────────────────────────
function Slide5({ W, H, theme, device }: SlideProps) {
  const darkSrc = device === "ipad" ? IPAD.mainDark : IPHONE.buildingsDark;
  const lightSrc = device === "ipad" ? IPAD.achievementsLight : IPHONE.achievementsLight;
  const backW = device === "ipad" ? W * 0.42 : W * 0.60;
  const frontW = device === "ipad" ? W * 0.56 : W * 0.78;

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `linear-gradient(135deg, #000010 0%, ${theme.bg} 60%, #100500 100%)` }}>
      <Glow x="-5%" y="20%" size={`${W * 0.6}px`} color="#000080" opacity={0.4} />
      <Glow x="55%" y="55%" size={`${W * 0.5}px`} color="#b87900" opacity={0.12} />

      <div style={{ padding: `${H * 0.09}px ${W * 0.1}px 0` }}>
        <Caption label="Dark & Light Mode"
          headline={<>Play Your Way.</>}
          sub="Two beautiful themes. One legendary game."
          canvasW={W} theme={theme} />
      </div>

      {/* Two phones layered */}
      {device === "ipad" ? (
        <>
          <IPad src={lightSrc} alt="Light mode" style={{
            position: "absolute", bottom: 0, left: `-${W * 0.02}px`,
            width: backW, opacity: 0.55, transform: "rotate(-4deg)",
          }} />
          <IPad src={darkSrc} alt="Dark mode" style={{
            position: "absolute", bottom: 0, right: `-${W * 0.02}px`,
            width: frontW, transform: "translateY(9%)",
          }} />
        </>
      ) : (
        <>
          <Phone src={lightSrc} alt="Light mode" style={{
            position: "absolute", bottom: 0, left: `-${W * 0.06}px`,
            width: backW, opacity: 0.55, transform: "rotate(-4deg)",
          }} />
          <Phone src={darkSrc} alt="Dark mode" style={{
            position: "absolute", bottom: 0, right: `-${W * 0.04}px`,
            width: frontW, transform: "translateY(10%)",
          }} />
        </>
      )}
    </div>
  );
}

// ─── SLIDE 6: More features pill slide ────────────────────────────────────────
function Slide6({ W, H, theme }: SlideProps) {
  const features = [
    "Prestige System", "Legacy Tokens", "World Wonders",
    "Legendary Leaders", "Weekly Leaderboard", "Offline Income",
    "Era Upgrades", "Cloud Save", "Light & Dark Mode",
  ];
  const coming = ["New Eras", "Seasonal Events", "Guilds"];

  return (
    <div style={{ width: W, height: H, position: "relative", overflow: "hidden",
      background: `radial-gradient(ellipse at 50% 50%, #0f0b00 0%, #060606 70%)`,
      display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
      padding: `0 ${W * 0.12}px` }}>
      <Glow x="20%" y="15%" size={`${W * 0.7}px`} color="#b87900" opacity={0.12} />
      <Glow x="50%" y="70%" size={`${W * 0.5}px`} color="#001060" opacity={0.3} />

      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/app-icon.png" alt="" style={{
        width: W * 0.2, height: W * 0.2,
        borderRadius: W * 0.04,
        boxShadow: `0 0 ${W * 0.06}px ${theme.glow}`,
        marginBottom: H * 0.04,
      }} draggable={false} />

      <div style={{
        fontFamily: "var(--font-playfair), serif",
        fontSize: W * 0.088,
        fontWeight: 700,
        color: theme.fg,
        textAlign: "center",
        lineHeight: 1.0,
        marginBottom: H * 0.045,
      }}>And So Much More.</div>

      <div style={{ display: "flex", flexWrap: "wrap", gap: W * 0.022,
        justifyContent: "center", marginBottom: H * 0.04 }}>
        {features.map(f => (
          <div key={f} style={{
            fontFamily: "var(--font-inter), sans-serif",
            fontSize: W * 0.03,
            color: theme.fg,
            background: theme.pillBg,
            border: `1px solid ${theme.pillBorder}`,
            borderRadius: W * 0.06,
            padding: `${W * 0.016}px ${W * 0.034}px`,
          }}>{f}</div>
        ))}
      </div>

      <div style={{
        fontFamily: "var(--font-inter), sans-serif",
        fontSize: W * 0.026,
        color: theme.muted,
        letterSpacing: "0.1em",
        textTransform: "uppercase",
        marginBottom: W * 0.016,
      }}>Coming Soon</div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: W * 0.018, justifyContent: "center" }}>
        {coming.map(f => (
          <div key={f} style={{
            fontFamily: "var(--font-inter), sans-serif",
            fontSize: W * 0.028,
            color: theme.muted,
            background: "rgba(255,255,255,0.04)",
            border: "1px solid rgba(255,255,255,0.1)",
            borderRadius: W * 0.06,
            padding: `${W * 0.014}px ${W * 0.03}px`,
          }}>{f}</div>
        ))}
      </div>
    </div>
  );
}

// ─── Slide registry ───────────────────────────────────────────────────────────
const SLIDES = [
  { id: "hero",         label: "01 – Hero",          Component: Slide1 },
  { id: "offline",      label: "02 – Offline",        Component: Slide2 },
  { id: "buildings",    label: "03 – Buildings",      Component: Slide3 },
  { id: "achievements", label: "04 – Achievements",   Component: Slide4 },
  { id: "modes",        label: "05 – Dark & Light",   Component: Slide5 },
  { id: "more",         label: "06 – More Features",  Component: Slide6 },
] as const;

// ─── Preview card (scales to fit grid cell) ───────────────────────────────────
function PreviewCard({
  slide,
  themeId,
  device,
  exportRef,
}: {
  slide: (typeof SLIDES)[number];
  themeId: ThemeId;
  device: "iphone" | "ipad";
  exportRef: React.RefObject<HTMLDivElement | null>;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.2);
  const W = device === "ipad" ? IPAD_W : IPHONE_W;
  const H = device === "ipad" ? IPAD_H : IPHONE_H;
  const theme = THEMES[themeId];
  const { Component } = slide;

  useEffect(() => {
    if (!containerRef.current) return;
    const obs = new ResizeObserver(([e]) => {
      const { width, height } = e.contentRect;
      setScale(Math.min(width / W, height / H));
    });
    obs.observe(containerRef.current);
    return () => obs.disconnect();
  }, [W, H]);

  return (
    <div ref={containerRef} style={{
      position: "relative", overflow: "hidden",
      borderRadius: 12, border: "1px solid rgba(255,255,255,0.1)",
      background: "#000",
      aspectRatio: `${W}/${H}`,
    }}>
      {/* Scaled preview */}
      <div style={{
        position: "absolute", top: 0, left: 0,
        width: W, height: H,
        transform: `scale(${scale})`, transformOrigin: "top left",
        pointerEvents: "none",
      }}>
        <Component W={W} H={H} theme={theme} device={device} />
      </div>

      {/* Offscreen export canvas */}
      <div ref={exportRef} style={{
        position: "absolute", left: "-9999px", top: 0,
        width: W, height: H, opacity: 0,
      }}>
        <Component W={W} H={H} theme={theme} device={device} />
      </div>
    </div>
  );
}

// ─── Export a single slide ────────────────────────────────────────────────────
// Captures at design resolution (canvasW×canvasH), then resizes to targetW×targetH.
async function exportSlide(
  el: HTMLDivElement,
  canvasW: number,
  canvasH: number,
  targetW: number,
  targetH: number,
  filename: string,
) {
  el.style.left = "0px";
  el.style.opacity = "1";
  el.style.zIndex = "-1";
  const opts = { width: canvasW, height: canvasH, pixelRatio: 1, cacheBust: true };
  await toPng(el, opts); // warm-up fonts/images
  const dataUrl = await toPng(el, opts);
  el.style.left = "-9999px";
  el.style.opacity = "0";
  el.style.zIndex = "";

  // Resize to target dimensions via canvas
  const img = new Image();
  await new Promise<void>(resolve => { img.onload = () => resolve(); img.src = dataUrl; });
  const canvas = document.createElement("canvas");
  canvas.width = targetW;
  canvas.height = targetH;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#000000"; // flatten alpha — App Store requires no transparency
  ctx.fillRect(0, 0, targetW, targetH);
  ctx.drawImage(img, 0, 0, targetW, targetH);
  const resized = canvas.toDataURL("image/png");

  const a = document.createElement("a");
  a.href = resized;
  a.download = filename;
  a.click();
}

// ─── Main page ────────────────────────────────────────────────────────────────
export default function ScreenshotsPage() {
  const [themeId, setThemeId] = useState<ThemeId>("dark-epic");
  const [device, setDevice] = useState<"iphone" | "ipad">("iphone");
  const [sizeIdx, setSizeIdx] = useState(0);
  const [exporting, setExporting] = useState<string | null>(null);

  const sizes = device === "ipad" ? IPAD_SIZES : IPHONE_SIZES;
  const { w: targetW, h: targetH } = sizes[sizeIdx];
  const canvasW = device === "ipad" ? IPAD_W : IPHONE_W;
  const canvasH = device === "ipad" ? IPAD_H : IPHONE_H;

  const refs = useRef(SLIDES.map(() => ({ current: null as HTMLDivElement | null })));

  const exportOne = useCallback(async (idx: number) => {
    const el = refs.current[idx].current;
    if (!el) return;
    const { id } = SLIDES[idx];
    const name = `${String(idx + 1).padStart(2, "0")}-${id}-${themeId}-${device}-${targetW}x${targetH}.png`;
    setExporting(name);
    try { await exportSlide(el, canvasW, canvasH, targetW, targetH, name); }
    finally { setExporting(null); }
  }, [themeId, device, targetW, targetH, canvasW, canvasH]);

  const exportAll = useCallback(async () => {
    for (let i = 0; i < SLIDES.length; i++) {
      const el = refs.current[i].current;
      if (!el) continue;
      const { id } = SLIDES[i];
      const name = `${String(i + 1).padStart(2, "0")}-${id}-${themeId}-${device}-${targetW}x${targetH}.png`;
      setExporting(name);
      await exportSlide(el, canvasW, canvasH, targetW, targetH, name);
      await new Promise(r => setTimeout(r, 300));
    }
    setExporting(null);
  }, [themeId, device, targetW, targetH, canvasW, canvasH]);

  return (
    <div style={{ minHeight: "100vh", background: "#0a0a0a", color: "#f5f5f5",
      fontFamily: "var(--font-inter), sans-serif" }}>

      {/* ── Toolbar ── */}
      <div style={{
        position: "sticky", top: 0, zIndex: 100,
        background: "rgba(10,10,10,0.96)", backdropFilter: "blur(14px)",
        borderBottom: "1px solid rgba(255,255,255,0.08)",
        padding: "12px 24px",
        display: "flex", alignItems: "center", gap: 12, flexWrap: "wrap",
      }}>
        <span style={{ fontFamily: "var(--font-playfair), serif", fontWeight: 700, fontSize: 15, color: "#FFD700", marginRight: 4 }}>
          Idle Civilizations
        </span>

        {/* Device */}
        {(["iphone", "ipad"] as const).map(d => (
          <button key={d} onClick={() => { setDevice(d); setSizeIdx(0); }} style={{
            padding: "5px 13px", borderRadius: 6,
            border: "1px solid rgba(255,255,255,0.15)",
            background: device === d ? "#FFD700" : "transparent",
            color: device === d ? "#000" : "#f5f5f5",
            fontSize: 12, fontWeight: 600, cursor: "pointer",
            textTransform: "capitalize",
          }}>{d === "iphone" ? "iPhone" : "iPad"}</button>
        ))}

        {/* Size */}
        <select value={sizeIdx} onChange={e => setSizeIdx(+e.target.value)} style={{
          background: "#1a1a1a", border: "1px solid rgba(255,255,255,0.15)",
          color: "#f5f5f5", borderRadius: 6, padding: "5px 10px", fontSize: 12,
        }}>
          {sizes.map((s, i) => (
            <option key={s.label} value={i}>{s.label} – {s.w}×{s.h}</option>
          ))}
        </select>

        {/* Theme */}
        <select value={themeId} onChange={e => setThemeId(e.target.value as ThemeId)} style={{
          background: "#1a1a1a", border: "1px solid rgba(255,255,255,0.15)",
          color: "#f5f5f5", borderRadius: 6, padding: "5px 10px", fontSize: 12,
        }}>
          {(Object.keys(THEMES) as ThemeId[]).map(t => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>

        {/* Export all */}
        <button onClick={exportAll} disabled={!!exporting} style={{
          marginLeft: "auto", padding: "6px 18px", borderRadius: 6,
          background: exporting ? "#555" : "#FFD700",
          color: "#000", fontSize: 13, fontWeight: 700,
          border: "none", cursor: exporting ? "not-allowed" : "pointer",
        }}>
          {exporting ? "Exporting…" : "Export All"}
        </button>
      </div>

      {/* ── Export status ── */}
      {exporting && (
        <div style={{ background: "#FFD70015", borderBottom: "1px solid #FFD70030",
          padding: "8px 24px", fontSize: 12, color: "#FFD700" }}>
          ⬇ {exporting}
        </div>
      )}

      {/* ── Grid ── */}
      <div style={{
        display: "grid",
        gridTemplateColumns: "repeat(auto-fill, minmax(260px, 1fr))",
        gap: 24, padding: 24,
      }}>
        {SLIDES.map((slide, idx) => (
          <div key={slide.id}>
            <PreviewCard
              slide={slide}
              themeId={themeId}
              device={device}
              exportRef={refs.current[idx] as React.RefObject<HTMLDivElement | null>}
            />
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 8 }}>
              <span style={{ fontSize: 12, color: "#777" }}>{slide.label}</span>
              <button onClick={() => exportOne(idx)} disabled={!!exporting} style={{
                fontSize: 12, padding: "4px 12px", borderRadius: 4,
                background: "transparent",
                border: "1px solid rgba(255,215,0,0.35)",
                color: "#FFD700", cursor: "pointer",
              }}>Export</button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
