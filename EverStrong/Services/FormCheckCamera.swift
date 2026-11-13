import AVFoundation
import Observation
import UIKit
import Vision

/// Body joints we draw and use, in normalised image coordinates (0–1, origin top-left, already mirrored).
struct PoseFrame {
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    var imageSize: CGSize = .zero

    static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]
}

/// Runs the front camera and Apple's on-device body-pose model. Nothing is recorded or uploaded.
@MainActor
@Observable
final class FormCheckModel {
    enum Status: Equatable { case idle, needsPermission, running, unavailable }

    var status: Status = .idle
    var pose = PoseFrame()
    var reps = 0
    var kneeAngle: Double?
    var message = "Stand side-on to the camera so your whole body is in view."
    var messageIsPositive = true
    var bodyVisible = false

    let session = AVCaptureSession()
    private let processor = PoseProcessor()
    @ObservationIgnored private var analyzer = SquatAnalyzer()
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var lastSpoken = Date.distantPast
    @ObservationIgnored private var lastVisibleWarning = Date.distantPast

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .needsPermission; return }
        default:
            status = .needsPermission
            return
        }
        if !configured {
            guard configure() else { status = .unavailable; return }
            configured = true
        }
        analyzer.reset()
        reps = 0
        processor.onFrame = { [weak self] frame in
            Task { @MainActor in self?.handle(frame) }
        }
        let session = self.session
        await Task.detached { session.startRunning() }.value
        status = .running
        SpeechCoach.shared.say("Form check started. Stand side on so I can see your whole body.", interrupt: true)
    }

    func stop() {
        processor.onFrame = nil
        let session = self.session
        Task.detached { session.stopRunning() }
        if status == .running { status = .idle }
    }

    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(processor, queue: processor.queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = (device.position == .front)
            }
        }
        return true
    }

    private func handle(_ frame: PoseFrame) {
        pose = frame
        guard let side = Self.bestSide(frame) else {
            bodyVisible = false
            kneeAngle = nil
            if Date.now.timeIntervalSince(lastVisibleWarning) > 6 {
                lastVisibleWarning = .now
                message = "Step back until your head, hips, knees and feet are all on screen."
                messageIsPositive = false
            }
            return
        }
        bodyVisible = true
        let angle = PoseMath.angle(side.hip, side.knee, side.ankle)
        kneeAngle = angle
        let lean = side.shoulder.map { PoseMath.leanFromVertical(hip: side.hip, shoulder: $0) }
        if let feedback = analyzer.update(kneeAngle: angle, torsoLean: lean) {
            reps = analyzer.reps
            message = feedback.message
            messageIsPositive = feedback.isPositive
            if Date.now.timeIntervalSince(lastSpoken) > 1.2 {
                lastSpoken = .now
                SpeechCoach.shared.say(feedback.message, interrupt: true)
            }
        }
    }

    private struct Side { let shoulder: CGPoint?; let hip: CGPoint; let knee: CGPoint; let ankle: CGPoint }

    /// Use whichever leg the camera can see best.
    private static func bestSide(_ frame: PoseFrame) -> Side? {
        let j = frame.joints
        let left = zip3(j[.leftHip], j[.leftKnee], j[.leftAnkle]).map {
            Side(shoulder: j[.leftShoulder], hip: $0.0, knee: $0.1, ankle: $0.2)
        }
        let right = zip3(j[.rightHip], j[.rightKnee], j[.rightAnkle]).map {
            Side(shoulder: j[.rightShoulder], hip: $0.0, knee: $0.1, ankle: $0.2)
        }
        return left ?? right
    }

    private static func zip3<A, B, C>(_ a: A?, _ b: B?, _ c: C?) -> (A, B, C)? {
        guard let a, let b, let c else { return nil }
        return (a, b, c)
    }
}

/// Receives camera frames on a background queue and runs Vision.
final class PoseProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "everstrong.pose", qos: .userInitiated)
    var onFrame: ((PoseFrame) -> Void)?
    private let request = VNDetectHumanBodyPoseRequest()
    private let minConfidence: Float = 0.3

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        var frame = PoseFrame(imageSize: size)
        if (try? handler.perform([request])) != nil,
           let observation = request.results?.first,
           let points = try? observation.recognizedPoints(.all) {
            for (name, point) in points where point.confidence >= minConfidence {
                // Vision uses a bottom-left origin; flip to top-left for drawing.
                frame.joints[name] = CGPoint(x: point.location.x, y: 1 - point.location.y)
            }
        }
        onFrame?(frame)
    }
}
