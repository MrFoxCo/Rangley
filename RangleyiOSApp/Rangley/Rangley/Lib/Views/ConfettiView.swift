//
//  ConfettiView.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/16/25.
//

import UIKit
import SwiftUI
import CoreLocation
import QuartzCore // for confetti supports the CA_* stuff

struct ConfettiBurst: UIViewRepresentable
{
    var color: UIColor = .systemPink
    var duration: TimeInterval = 1.0
    var intensity: CGFloat = 1.0

    func makeUIView(context: Context) -> ConfettiUIView {
        let v = ConfettiUIView()
        v.emit(color: color, duration: duration, intensity: intensity)
        return v
    }
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView
{
    private var emitter: CAEmitterLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter?.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func emit(color: UIColor, duration: TimeInterval, intensity: CGFloat) {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .point
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.beginTime = CACurrentMediaTime()

        let cell = CAEmitterCell()
        cell.contents = particleImage(color: color).cgImage
        cell.birthRate = 400 * Float(intensity)   // big burst
        cell.lifetime = 2.0
        cell.velocity = 280 * intensity
        cell.velocityRange = 120 * intensity
        cell.emissionRange = .pi * 2              // 360 degrees
        cell.scale = 0.9
        cell.scaleRange = 0.5
        cell.spin = 2.5
        cell.spinRange = 4.0
        cell.alphaSpeed = -0.8
        cell.yAcceleration = 340                  // gravity drop

        emitter.emitterCells = [cell]
        layer.addSublayer(emitter)
        self.emitter = emitter

        // Stop birthing quickly so it feels like an explosion, not a stream
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            emitter.birthRate = 0
        }
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            emitter.removeFromSuperlayer()
        }
    }

    private func particleImage(color: UIColor) -> UIImage {
        // small rounded-rect “confetti”
        let size: CGFloat = 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
            color.setFill()
            path.fill()
        }
    }
}
