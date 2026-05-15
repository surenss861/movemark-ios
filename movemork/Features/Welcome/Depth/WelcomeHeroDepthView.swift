//
//  WelcomeHeroDepthView.swift
//  movemork
//
//  SceneKit hero depth — layered proof planes with gentle parallax.
//

import SceneKit
import SwiftUI
import UIKit

struct WelcomeHeroDepthView: UIViewRepresentable {
    var isActive: Bool
    var revealProgress: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.rendersContinuously = isActive
        view.autoenablesDefaultLighting = false
        context.coordinator.attach(view: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.revealProgress = Float(revealProgress)
        uiView.rendersContinuously = isActive
        if !isActive {
            uiView.scene?.isPaused = true
        } else {
            uiView.scene?.isPaused = false
        }
    }

    final class Coordinator: NSObject {
        let scene = SCNScene()
        private weak var scnView: SCNView?
        private let cameraNode = SCNNode()
        private let paperNode = SCNNode()
        private let depositNode = SCNNode()
        private let proofNode = SCNNode()
        var revealProgress: Float = 0

        override init() {
            super.init()
            setupCamera()
            setupLights()
            setupPlanes()
        }

        func attach(view: SCNView) {
            scnView = view
            view.scene = scene
            view.delegate = self
        }

        private func setupCamera() {
            let camera = SCNCamera()
            camera.fieldOfView = 42
            camera.zNear = 0.1
            camera.zFar = 20
            cameraNode.camera = camera
            cameraNode.position = SCNVector3(0, 0.05, 4.2)
            scene.rootNode.addChildNode(cameraNode)
        }

        private func setupLights() {
            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 450
            key.eulerAngles = SCNVector3(-0.6, 0.4, 0)
            scene.rootNode.addChildNode(key)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .ambient
            fill.light?.color = UIColor(red: 0.15, green: 0.35, blue: 0.22, alpha: 1)
            fill.light?.intensity = 280
            scene.rootNode.addChildNode(fill)
        }

        private func setupPlanes() {
            let paper = SCNPlane(width: 2.6, height: 1.5)
            paper.cornerRadius = 0.03
            let paperMat = SCNMaterial()
            paperMat.diffuse.contents = UIColor(white: 1, alpha: 0.08)
            paperMat.isDoubleSided = true
            paper.firstMaterial = paperMat
            paperNode.geometry = paper
            paperNode.position = SCNVector3(0.22, 0.12, -0.35)
            paperNode.eulerAngles = SCNVector3(0, -0.12, 0.06)
            scene.rootNode.addChildNode(paperNode)

            let deposit = SCNPlane(width: 1.9, height: 0.72)
            deposit.cornerRadius = 0.05
            let depositMat = SCNMaterial()
            depositMat.diffuse.contents = UIColor(red: 0.078, green: 0.208, blue: 0.145, alpha: 0.85)
            depositMat.emission.contents = UIColor(red: 0.09, green: 0.25, blue: 0.16, alpha: 0.2)
            deposit.firstMaterial = depositMat
            depositNode.geometry = deposit
            depositNode.position = SCNVector3(-0.35, -0.55, 0.25)
            depositNode.eulerAngles = SCNVector3(0, 0.08, -0.04)
            scene.rootNode.addChildNode(depositNode)

            let proof = SCNPlane(width: 2.2, height: 1.1)
            proof.cornerRadius = 0.05
            let proofMat = SCNMaterial()
            proofMat.diffuse.contents = UIColor(red: 0.063, green: 0.161, blue: 0.114, alpha: 0.75)
            proof.firstMaterial = proofMat
            proofNode.geometry = proof
            proofNode.position = SCNVector3(0.1, -0.35, 0.18)
            proofNode.eulerAngles = SCNVector3(0, -0.05, 0.03)
            scene.rootNode.addChildNode(proofNode)
        }

        func updateTransforms(time: TimeInterval) {
            let reveal = revealProgress
            let drift = isActiveParallax ? Float(sin(time * 0.35) * 0.018) : 0
            let driftY = isActiveParallax ? Float(cos(time * 0.28) * 0.012) : 0

            paperNode.position = SCNVector3(0.22 + drift, 0.12 + driftY, -0.35 + (1 - reveal) * 0.4)
            depositNode.position = SCNVector3(-0.35 + drift * 0.6, -0.55 + (1 - reveal) * 0.25, 0.25)
            proofNode.position = SCNVector3(0.1 + drift * 0.4, -0.35 + (1 - reveal) * 0.2, 0.18)
        }

        private var isActiveParallax: Bool {
            scnView?.rendersContinuously == true
        }
    }
}

extension WelcomeHeroDepthView.Coordinator: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateTransforms(time: time)
    }
}
