import SwiftUI
import RealityKit
import UIKit

private func dragonMaterial(hex: String, roughness: Float) -> any RealityKit.Material {
    let value = UInt64(hex, radix: 16) ?? 0xE85D4A
    let color = UIColor(
        red: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
    )
    #if targetEnvironment(simulator)
    // iOS 27's simulator PBR renderer can crash while binding its tone-map
    // lookup textures. UnlitMaterial keeps the procedural 3D geometry visible
    // in the simulator; physical shading remains enabled on a real iPhone.
    return UnlitMaterial(color: color, applyPostProcessToneMap: false)
    #else
    return SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: false)
    #endif
}

struct DragonSceneView: View {
    let stage: DragonStage
    var colorHex: String = "E85D4A"
    var speciesID: String = "ruby"

    private var dragonColor: Color { Color(hex: colorHex) }
    private var wingColor: Color {
        switch speciesID {
        case "azure": return Color(red: 0.05, green: 0.30, blue: 0.58)
        case "moss": return Color(red: 0.12, green: 0.35, blue: 0.20)
        case "sunstone": return Color(red: 0.82, green: 0.34, blue: 0.05)
        case "moon": return Color(red: 0.22, green: 0.12, blue: 0.42)
        case "crystal": return Color(red: 0.05, green: 0.42, blue: 0.43)
        default: return DragonTheme.coralDark
        }
    }
    private var wingHex: String {
        switch speciesID {
        case "azure": return "0D4C94"
        case "moss": return "1F5933"
        case "sunstone": return "D1570D"
        case "moon": return "381F6B"
        case "crystal": return "0D6B6E"
        default: return "921F24"
        }
    }

    var body: some View {
        #if targetEnvironment(simulator)
        DragonSimulatorPreview(
            speciesID: speciesID,
            stage: stage,
            colorHex: colorHex,
            size: 250,
            animated: true
        )
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(DragonTheme.sky)
        #else
        RealityView { content in
            content.add(makeDragon(stage: stage))
            let light = DirectionalLight()
            light.light.intensity = 900
            light.look(at: [0, 0, 0], from: [2, 3, 4], relativeTo: nil)
            content.add(light)
        } update: { content in
            content.entities.removeAll()
            content.add(makeDragon(stage: stage))
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(DragonTheme.sky)
        #endif
    }

    private func makeDragon(stage: DragonStage) -> Entity {
        let root = Entity()
        let scale: Float = stage == .hatchling ? 0.78 : stage == .guardian ? 1.12 : 0.95
        root.scale = [scale, scale, scale]
        root.position = [0, -0.1, 0]

        let body = ModelEntity(mesh: .generateSphere(radius: 0.72), materials: [dragonMaterial(hex: colorHex, roughness: 0.68)])
        body.scale = [1.0, 0.82, 1.15]
        body.position = [0, 0, 0]
        root.addChild(body)

        let head = ModelEntity(mesh: .generateSphere(radius: 0.48), materials: [dragonMaterial(hex: colorHex, roughness: 0.68)])
        head.position = [0, 0.62, -0.08]
        root.addChild(head)

        let snout = ModelEntity(mesh: .generateSphere(radius: 0.24), materials: [dragonMaterial(hex: colorHex, roughness: 0.68)])
        snout.scale = [1.0, 0.72, 0.78]
        snout.position = [0, 0.52, 0.38]
        root.addChild(snout)

        for x in [-0.18, 0.18] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.075), materials: [dragonMaterial(hex: "F0AD3D", roughness: 0.35)])
            eye.position = [Float(x), 0.74, 0.42]
            root.addChild(eye)
        }

        for x in [-0.23, 0.23] {
            let horn = ModelEntity(mesh: .generateCone(height: 0.32, radius: 0.11), materials: [dragonMaterial(hex: wingHex, roughness: 0.58)])
            horn.position = [Float(x), 1.02, -0.04]
            horn.orientation = simd_quatf(angle: x < 0 ? -0.3 : 0.3, axis: [0, 0, 1])
            root.addChild(horn)
        }

        for x in [-0.82, 0.82] {
            let wing = ModelEntity(mesh: .generateCone(height: 0.9, radius: 0.52), materials: [dragonMaterial(hex: wingHex, roughness: 0.58)])
            wing.position = [Float(x), 0.38, 0.12]
            wing.scale = [0.8, 0.35, 1.0]
            wing.orientation = simd_quatf(angle: x < 0 ? -0.55 : 0.55, axis: [0, 0, 1])
            root.addChild(wing)
        }

        let tail = ModelEntity(mesh: .generateCone(height: 1.15, radius: 0.25), materials: [dragonMaterial(hex: colorHex, roughness: 0.68)])
        tail.position = [0, -0.05, -0.95]
        tail.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        root.addChild(tail)
        return root
    }

}

struct DragonMiniSceneView: View {
    let speciesID: String
    let stage: DragonStage
    let colorHex: String
    let size: CGFloat
    let animated: Bool
    @State private var isAlive = false

    private var dragonColor: Color { Color(hex: colorHex) }
    private var wingColor: Color {
        switch speciesID {
        case "azure": return Color(red: 0.05, green: 0.30, blue: 0.58)
        case "moss": return Color(red: 0.12, green: 0.35, blue: 0.20)
        case "sunstone": return Color(red: 0.82, green: 0.34, blue: 0.05)
        case "moon": return Color(red: 0.22, green: 0.12, blue: 0.42)
        case "crystal": return Color(red: 0.05, green: 0.42, blue: 0.43)
        default: return DragonTheme.coralDark
        }
    }
    private var wingHex: String {
        switch speciesID {
        case "azure": return "0D4C94"
        case "moss": return "1F5933"
        case "sunstone": return "D1570D"
        case "moon": return "381F6B"
        case "crystal": return "0D6B6E"
        default: return "921F24"
        }
    }

    var body: some View {
        #if targetEnvironment(simulator)
        DragonSimulatorPreview(
            speciesID: speciesID,
            stage: stage,
            colorHex: colorHex,
            size: size,
            animated: animated
        )
        #else
        RealityView { content in
            content.add(makeDragon())
            let light = DirectionalLight()
            light.light.intensity = 850
            light.look(at: [0, 0, 0], from: [2, 3, 4], relativeTo: nil)
            content.add(light)
        } update: { content in
            content.entities.removeAll()
            content.add(makeDragon())
        }
        .frame(width: size, height: size)
        .offset(y: animated && isAlive ? -3 : 3)
        .rotation3DEffect(.degrees(animated && isAlive ? 2 : -2), axis: (x: 0, y: 1, z: 0))
        .animation(animated ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true) : nil, value: isAlive)
        .onAppear { if animated { isAlive = true } }
        .allowsHitTesting(false)
        #endif
    }

    private func makeDragon() -> Entity {
        let root = Entity()
        let scale: Float = stage == .hatchling ? 0.72 : stage == .guardian ? 1.06 : 0.9
        root.scale = [scale, scale, scale]
        root.position = [0, -0.12, 0]

        let body = ModelEntity(mesh: .generateSphere(radius: 0.70), materials: [dragonMaterial(hex: colorHex, roughness: 0.52)])
        body.scale = [1.0, 0.84, 1.1]
        root.addChild(body)

        let head = ModelEntity(mesh: .generateSphere(radius: 0.46), materials: [dragonMaterial(hex: colorHex, roughness: 0.52)])
        head.position = [0, 0.58, -0.05]
        root.addChild(head)

        let snout = ModelEntity(mesh: .generateSphere(radius: 0.22), materials: [dragonMaterial(hex: colorHex, roughness: 0.52)])
        snout.scale = [1.0, 0.72, 0.82]
        snout.position = [0, 0.48, 0.36]
        root.addChild(snout)

        for x in [-0.17, 0.17] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [dragonMaterial(hex: "F0AD3D", roughness: 0.35)])
            eye.position = [Float(x), 0.70, 0.40]
            root.addChild(eye)
        }

        for x in [-0.22, 0.22] {
            let horn = ModelEntity(mesh: .generateCone(height: 0.30, radius: 0.10), materials: [dragonMaterial(hex: wingHex, roughness: 0.45)])
            horn.position = [Float(x), 0.98, -0.03]
            horn.orientation = simd_quatf(angle: x < 0 ? -0.3 : 0.3, axis: [0, 0, 1])
            root.addChild(horn)
        }

        for x in [-0.80, 0.80] {
            let wing = ModelEntity(mesh: .generateCone(height: 0.86, radius: 0.50), materials: [dragonMaterial(hex: wingHex, roughness: 0.45)])
            wing.position = [Float(x), 0.34, 0.10]
            wing.scale = [0.8, 0.34, 1.0]
            wing.orientation = simd_quatf(angle: x < 0 ? -0.55 : 0.55, axis: [0, 0, 1])
            root.addChild(wing)
        }

        let tail = ModelEntity(mesh: .generateCone(height: 1.05, radius: 0.23), materials: [dragonMaterial(hex: colorHex, roughness: 0.52)])
        tail.position = [0, -0.05, -0.90]
        tail.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        root.addChild(tail)
        return root
    }

}

/// A stable simulator-only preview. iOS 27's simulator Metal validation can
/// crash RealityKit's render pipeline, so the simulator gets a layered,
/// shaded SwiftUI dragon while a real iPhone uses the RealityKit scene above.
private struct DragonSimulatorPreview: View {
    let speciesID: String
    let stage: DragonStage
    let colorHex: String
    let size: CGFloat
    let animated: Bool
    @State private var floating = false

    private var baseColor: Color { Color(hex: colorHex) }
    private var wingColor: Color {
        switch speciesID {
        case "azure": return Color(hex: "0D4C94")
        case "moss": return Color(hex: "1F5933")
        case "sunstone": return Color(hex: "D1570D")
        case "moon": return Color(hex: "381F6B")
        case "crystal": return Color(hex: "0D6B6E")
        default: return Color(hex: "921F24")
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [baseColor.opacity(0.30), .clear], center: .center, startRadius: 3, endRadius: size * 0.48))
                .frame(width: size * 0.96, height: size * 0.96)

            DragonSimulatorWingShape()
                .fill(LinearGradient(colors: [wingColor.opacity(0.96), wingColor.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.48, height: size * 0.34)
                .rotationEffect(.degrees(-8))
                .offset(x: -size * 0.29, y: size * 0.02)

            DragonSimulatorWingShape()
                .fill(LinearGradient(colors: [wingColor.opacity(0.96), wingColor.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.48, height: size * 0.34)
                .scaleEffect(x: -1, y: 1)
                .rotationEffect(.degrees(-8))
                .offset(x: size * 0.29, y: size * 0.02)

            Ellipse()
                .fill(LinearGradient(colors: [baseColor.opacity(0.98), baseColor.opacity(0.64)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.52, height: size * 0.48)
                .overlay {
                    Ellipse()
                        .stroke(.white.opacity(0.16), lineWidth: max(1, size * 0.012))
                }
                .offset(y: size * 0.10)

            Circle()
                .fill(LinearGradient(colors: [baseColor.opacity(1), baseColor.opacity(0.68)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.37, height: size * 0.37)
                .overlay {
                    Circle().stroke(.white.opacity(0.18), lineWidth: max(1, size * 0.012))
                }
                .offset(y: -size * 0.18)

            Capsule()
                .fill(baseColor.opacity(0.86))
                .frame(width: size * 0.21, height: size * 0.12)
                .offset(y: -size * 0.10)

            HStack(spacing: size * 0.075) {
                DragonSimulatorEye()
                DragonSimulatorEye()
            }
            .offset(y: -size * 0.22)

            HStack(spacing: size * 0.13) {
                DragonSimulatorHorn().fill(wingColor)
                DragonSimulatorHorn().fill(wingColor)
            }
            .offset(y: -size * 0.38)

            Ellipse()
                .fill(.black.opacity(0.20))
                .frame(width: size * 0.35, height: size * 0.055)
                .blur(radius: size * 0.02)
                .offset(y: size * 0.36)
        }
        .frame(width: size, height: size)
        .scaleEffect(stage == .hatchling ? 0.78 : stage == .guardian ? 1.08 : 0.94)
        .offset(y: animated && floating ? -3 : 3)
        .rotation3DEffect(.degrees(animated && floating ? 2 : -2), axis: (x: 0, y: 1, z: 0))
        .animation(animated ? .easeInOut(duration: 2.2).repeatForever(autoreverses: true) : nil, value: floating)
        .onAppear { if animated { floating = true } }
        .allowsHitTesting(false)
    }
}

private struct DragonSimulatorEye: View {
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().fill(.black).frame(width: 6, height: 6).offset(x: 1, y: 1))
    }
}

private struct DragonSimulatorHorn: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DragonSimulatorWingShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX * 0.55, y: rect.minY * 0.4))
        path.addQuadCurve(to: CGPoint(x: rect.maxX * 0.78, y: rect.maxY), control: CGPoint(x: rect.maxX * 0.94, y: rect.maxY * 0.75))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.74))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
