import SwiftUI
import RealityKit
import UIKit

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

    var body: some View {
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
    }

    private func makeDragon(stage: DragonStage) -> Entity {
        let root = Entity()
        let scale: Float = stage == .hatchling ? 0.78 : stage == .guardian ? 1.12 : 0.95
        root.scale = [scale, scale, scale]
        root.position = [0, -0.1, 0]

        let body = ModelEntity(mesh: .generateSphere(radius: 0.72), materials: [material(dragonColor)])
        body.scale = [1.0, 0.82, 1.15]
        body.position = [0, 0, 0]
        root.addChild(body)

        let head = ModelEntity(mesh: .generateSphere(radius: 0.48), materials: [material(dragonColor)])
        head.position = [0, 0.62, -0.08]
        root.addChild(head)

        let snout = ModelEntity(mesh: .generateSphere(radius: 0.24), materials: [material(dragonColor)])
        snout.scale = [1.0, 0.72, 0.78]
        snout.position = [0, 0.52, 0.38]
        root.addChild(snout)

        for x in [-0.18, 0.18] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.075), materials: [material(DragonTheme.gold)])
            eye.position = [Float(x), 0.74, 0.42]
            root.addChild(eye)
        }

        for x in [-0.23, 0.23] {
            let horn = ModelEntity(mesh: .generateCone(height: 0.32, radius: 0.11), materials: [material(wingColor)])
            horn.position = [Float(x), 1.02, -0.04]
            horn.orientation = simd_quatf(angle: x < 0 ? -0.3 : 0.3, axis: [0, 0, 1])
            root.addChild(horn)
        }

        for x in [-0.82, 0.82] {
            let wing = ModelEntity(mesh: .generateCone(height: 0.9, radius: 0.52), materials: [material(wingColor)])
            wing.position = [Float(x), 0.38, 0.12]
            wing.scale = [0.8, 0.35, 1.0]
            wing.orientation = simd_quatf(angle: x < 0 ? -0.55 : 0.55, axis: [0, 0, 1])
            root.addChild(wing)
        }

        let tail = ModelEntity(mesh: .generateCone(height: 1.15, radius: 0.25), materials: [material(dragonColor)])
        tail.position = [0, -0.05, -0.95]
        tail.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        root.addChild(tail)
        return root
    }

    private func material(_ color: Color) -> SimpleMaterial {
        SimpleMaterial(color: UIColor(color), roughness: 0.68, isMetallic: false)
    }
}
