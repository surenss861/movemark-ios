//
//  WelcomeEmeraldMetalView.swift
//  movemork
//
//  Metal emerald light field — Welcome atmosphere only.
//

import MetalKit
import SwiftUI

struct WelcomeEmeraldMetalView: UIViewRepresentable {
    var isAnimating: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.isPaused = !isAnimating
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30
        view.framebufferOnly = false
        view.isOpaque = true
        view.clearColor = MTLClearColor(red: 0.024, green: 0.071, blue: 0.051, alpha: 1)
        view.backgroundColor = UIColor(red: 0.024, green: 0.071, blue: 0.051, alpha: 1)
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.intensity = isAnimating ? 1 : 0.35
        uiView.isPaused = !isAnimating
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var startTime = CFAbsoluteTimeGetCurrent()
        var intensity: Float = 1
        private weak var mtkView: MTKView?

        override init() {
            device = MTLCreateSystemDefaultDevice()
            super.init()
            commandQueue = device?.makeCommandQueue()
            buildPipeline()
        }

        func attach(to view: MTKView) {
            mtkView = view
        }

        private func buildPipeline() {
            guard let device, let library = device.makeDefaultLibrary() else { return }
            guard
                let vertex = library.makeFunction(name: "emerald_vertex"),
                let fragment = library.makeFunction(name: "emerald_fragment")
            else { return }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard
                let pipeline,
                let drawable = view.currentDrawable,
                let pass = view.currentRenderPassDescriptor,
                let commandBuffer = commandQueue?.makeCommandBuffer(),
                let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
            else { return }

            let time = Float(CFAbsoluteTimeGetCurrent() - startTime)
            var timeUniform = time
            var intensityUniform = intensity

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&timeUniform, length: MemoryLayout<Float>.size, index: 0)
            encoder.setFragmentBytes(&intensityUniform, length: MemoryLayout<Float>.size, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
