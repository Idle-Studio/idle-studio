#!/usr/bin/env swift
/// Generate all Idle Civilizations game assets into the Xcode asset catalog.
/// Uses AppKit for pixel-perfect Apple emoji rendering.
///
/// Usage:
///   swift tools/generate_assets.swift
///
import AppKit
import Foundation

// MARK: - Config

let SIZE: CGFloat = 512
let EMOJI_SIZE: CGFloat = 300

let repoRoot = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
let xcassets  = repoRoot
    .appendingPathComponent("apps/IdleCivilizations/Resources/Assets.xcassets")

// MARK: - Era color palettes

let eraColors: [String: (NSColor, NSColor)] = [
    "stone_age":             (hex("8B7355"), hex("4A3520")),
    "bronze_age":            (hex("CD7F32"), hex("7A3E10")),
    "ancient_empires":       (hex("C4A44D"), hex("6B4A08")),
    "classical_world":       (hex("5B8DB8"), hex("1E4A70")),
    "medieval_era":          (hex("6B4F7C"), hex("2E1A40")),
    "renaissance":           (hex("C44B24"), hex("6A1A08")),
    "industrial_revolution": (hex("607080"), hex("252E38")),
    "space_age":             (hex("1E4A7E"), hex("050E20")),
]

// MARK: - Asset list  (name, emoji, era)

let assets: [(String, String, String)] = [
    // Stone Age
    ("unit_campfire",              "🔥", "stone_age"),
    ("unit_berry_gatherer",        "🍇", "stone_age"),
    ("unit_fishing_spot",          "🎣", "stone_age"),
    ("unit_hunting_lodge",         "🏹", "stone_age"),
    ("unit_tribal_elder",          "🧙", "stone_age"),
    // Bronze Age
    ("unit_mine",                  "⛏️", "bronze_age"),
    ("unit_smelter",               "🔨", "bronze_age"),
    ("unit_marketplace",           "🏪", "bronze_age"),
    ("unit_warship",               "⚓", "bronze_age"),
    ("unit_bronze_palace",         "🏛️", "bronze_age"),
    // Ancient Empires
    ("unit_grain_farm",            "🌾", "ancient_empires"),
    ("unit_aqueduct",              "🌊", "ancient_empires"),
    ("unit_amphitheatre",          "🎭", "ancient_empires"),
    ("unit_army_barracks",         "⚔️", "ancient_empires"),
    ("unit_great_pyramid",         "🔺", "ancient_empires"),
    // Classical World
    ("unit_forum",                 "📜", "classical_world"),
    ("unit_colosseum",             "🏟️", "classical_world"),
    ("unit_temple",                "🕌", "classical_world"),
    ("unit_silk_road_bazaar",      "🧣", "classical_world"),
    ("unit_roman_legions",         "🛡️", "classical_world"),
    // Medieval Era
    ("unit_mill",                  "🌾", "medieval_era"),
    ("unit_castle",                "🏰", "medieval_era"),
    ("unit_cathedral",             "⛪", "medieval_era"),
    ("unit_knights_order",         "🗡️", "medieval_era"),
    ("unit_black_prince",          "👑", "medieval_era"),
    // Renaissance
    ("unit_printing_press",        "📖", "renaissance"),
    ("unit_university",            "🎓", "renaissance"),
    ("unit_art_studio",            "🎨", "renaissance"),
    ("unit_shipyard",              "⛵", "renaissance"),
    ("unit_da_vinci_workshop",     "✏️", "renaissance"),
    // Industrial Revolution
    ("unit_coal_mine",             "🏭", "industrial_revolution"),
    ("unit_steam_engine",          "🚂", "industrial_revolution"),
    ("unit_railway_line",          "🛤️", "industrial_revolution"),
    ("unit_factory",               "🔧", "industrial_revolution"),
    ("unit_power_station",         "⚡", "industrial_revolution"),
    // Space Age
    ("unit_radio_tower",           "📡", "space_age"),
    ("unit_computer_lab",          "💻", "space_age"),
    ("unit_satellite",             "🛰️", "space_age"),
    ("unit_space_rocket",          "🚀", "space_age"),
    ("unit_lunar_base",            "🌕", "space_age"),
    // Milestones
    ("ms_lascaux_cave",            "🦬", "stone_age"),
    ("ms_stonehenge",              "🗿", "bronze_age"),
    ("ms_great_library",           "📚", "ancient_empires"),
    ("ms_parthenon",               "🏛️", "classical_world"),
    ("ms_notre_dame",              "⛪", "medieval_era"),
    ("ms_sistine_chapel",          "🖼️", "renaissance"),
    ("ms_crystal_palace",          "🔮", "industrial_revolution"),
    ("ms_international_space_station", "🛸", "space_age"),
    // Character portraits
    ("char_og_the_elder",          "👴", "stone_age"),
    ("char_hammurabi",             "📜", "bronze_age"),
    ("char_julius_caesar",         "⚔️", "classical_world"),
    ("char_da_vinci",              "🎨", "renaissance"),
    ("char_nikola_tesla",          "⚡", "industrial_revolution"),
]

// MARK: - Helpers

func hex(_ h: String) -> NSColor {
    let s = h.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var rgb: UInt64 = 0
    Scanner(string: s).scanHexInt64(&rgb)
    return NSColor(
        red:   CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >>  8) & 0xFF) / 255,
        blue:  CGFloat( rgb        & 0xFF) / 255,
        alpha: 1
    )
}

/// Draw a vertical gradient (top → bottom) into the current NSGraphicsContext.
func drawGradient(top: NSColor, bottom: NSColor, rect: CGRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let colors = [top.cgColor, bottom.cgColor] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: rect.midX, y: rect.maxY),
                           end:   CGPoint(x: rect.midX, y: rect.minY),
                           options: [])
}

/// Draw a dark radial vignette inside `rect`.
func drawVignette(rect: CGRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = rect.width * 0.72
    let colors = [
        CGColor(gray: 0, alpha: 0),
        CGColor(gray: 0, alpha: 0.55),
    ] as CFArray
    let space = CGColorSpaceCreateDeviceGray()
    guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0.35, 1.0]) else { return }
    ctx.drawRadialGradient(gradient,
                           startCenter: center, startRadius: 0,
                           endCenter:   center, endRadius:   radius,
                           options: [.drawsAfterEndLocation])
}

func generateIcon(name: String, emoji: String, era: String) {
    guard let (topColor, botColor) = eraColors[era] else {
        print("  ❌ Unknown era '\(era)' for \(name)")
        return
    }

    let s = Int(SIZE)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: s, pixelsHigh: s,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current = ctx

    let rect = CGRect(origin: .zero, size: CGSize(width: SIZE, height: SIZE))

    // 1. Background gradient
    drawGradient(top: topColor, bottom: botColor, rect: rect)

    // 2. Emoji centered
    let attr: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Apple Color Emoji", size: EMOJI_SIZE) ?? NSFont.systemFont(ofSize: EMOJI_SIZE)
    ]
    let str = NSAttributedString(string: emoji, attributes: attr)
    let strSize = str.size()
    let x = (SIZE - strSize.width)  / 2
    let y = (SIZE - strSize.height) / 2 + SIZE * 0.02   // slight upward bias
    str.draw(at: CGPoint(x: x, y: y))

    // 3. Vignette on top
    drawVignette(rect: rect)

    NSGraphicsContext.restoreGraphicsState()

    // Write .imageset
    let imagesetDir = xcassets
        .appendingPathComponent("\(name).imageset")
    try? FileManager.default.createDirectory(at: imagesetDir, withIntermediateDirectories: true)

    let pngData = rep.representation(using: .png, properties: [:])!
    try? pngData.write(to: imagesetDir.appendingPathComponent("\(name).png"))

    let contents: [String: Any] = [
        "images": [["filename": "\(name).png", "idiom": "universal", "scale": "1x"]],
        "info":   ["author": "generate_assets.swift", "version": 1]
    ]
    let json = try! JSONSerialization.data(withJSONObject: contents, options: .prettyPrinted)
    try? json.write(to: imagesetDir.appendingPathComponent("Contents.json"))

    print("  ✓  \(name)  \(emoji)")
}

// MARK: - Main

print("Generating \(assets.count) assets → \(xcassets.path)\n")
for (name, emoji, era) in assets {
    generateIcon(name: name, emoji: emoji, era: era)
}
print("\n✅  Done — \(assets.count) assets written.")
