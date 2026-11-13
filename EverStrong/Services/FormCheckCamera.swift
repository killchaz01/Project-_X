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
    private typealias Joints = [VNHumanBodyPoseObservation.JointName: CGPoint]

    var status: Status = .idle
    var pose = PoseFrame()
    /// Reps, or best balance hold in seconds.
    var count = 0
    var countLabel = "reps"
    /// A small live read-out, e.g. "Knee angle 95°".
    var metricText: String?
    var message = ""
    var messageIsPositive = true
    var bodyVisible = false

    let session = AVCaptureSession()
    private let processor = PoseProcessor()
    @ObservationIgnored private var kind: FormCheckKind = .squat
    @ObservationIgnored private var reps = RepAnalyzer()
    @ObservationIgnored private var balance = BalanceAnalyzer()
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var lastSpoken = Date.distantPast
    @ObservationIgnored private var lastVisibleWarning = Date.distantPast

    func start(kind: FormCheckKind) async {
        self.kind = kind
        countLabel = kind.countLabel
        message = kind.startHint
        messageIsPositive = true
        count = 0
        metricText = nil
        switch kind {
        case .squat: reps = .squat
        case .lunge: reps = .lunge
        case .pushUp: reps = .pushUp
        case .balance: balance.reset()
        }

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
        processor.onFrame = { [weak self] frame in
            Task { @MainActor in self?.handle(frame) }
        }
        let session = self.session
        await Task.detached { session.startRunning() }.value
        status = .running
        SpeechCoach.shared.say("Form check started. \(kind.startHint)", interrupt: true)
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

    // MARK: Per-frame analysis

    private func handle(_ frame: PoseFrame) {
        pose = frame
        let j = frame.joints
        var feedback: RepAnalyzer.Feedback?
        let visible: Bool

        switch kind {
        case .squat:
            if let leg = Self.leg(j, left: true) ?? Self.leg(j, left: false) {
                visible = true
                metricText = "Knee angle \(Int(leg.kneeAngle))°"
                feedback = reps.update(kneeAngle: leg.kneeAngle, torsoLean: Self.torsoLean(j))
                count = reps.reps
            } else { visible = false }
        case .lunge:
            // Use whichever knee is bent more: that is the working leg.
            let legs = [Self.leg(j, left: true), Self.leg(j, left: false)].compactMap { $0 }
            if let angle = legs.map(\.kneeAngle).min() {
                visible = true
                metricText = "Knee angle \(Int(angle))°"
                feedback = reps.update(kneeAngle: angle, torsoLean: Self.torsoLean(j))
                count = reps.reps
            } else { visible = false }
        case .pushUp:
            if let arm = Self.arm(j, left: true) ?? Self.arm(j, left: false) {
                visible = true
                metricText = "Elbow angle \(Int(arm.elbowAngle))°"
                feedback = reps.update(kneeAngle: arm.elbowAngle, torsoLean: arm.bodySag)
                count = reps.reps
            } else { visible = false }
        case .balance:
            if let l = Self.leg(j, left: true), let r = Self.leg(j, left: false) {
                visible = true
                let lifted = BalanceAnalyzer.isFootLifted(leftAnkle: l.ankle, rightAnkle: r.ankle,
                                                          legLength: max(l.length, r.length),
                                                          threshold: balance.liftThreshold)
                feedback = balance.update(lifted: lifted, time: Date.now.timeIntervalSinceReferenceDate)
                count = balance.best
                metricText = balance.currentHold > 0 ? "Holding \(balance.currentHold) s" : "Lift one foot"
            } else { visible = false }
        }

        bodyVisible = visible
        guard visible else {
            metricText = nil
            if Date.now.timeIntervalSince(lastVisibleWarning) > 6 {
                lastVisibleWarning = .now
                message = kind.notVisibleHint
                messageIsPositive = false
            }
            return
        }
        if let feedback {
            message = feedback.message
            messageIsPositive = feedback.isPositive
            if Date.now.timeIntervalSince(lastSpoken) > 1.2 {
                lastSpoken = .now
                SpeechCoach.shared.say(feedback.message, interrupt: true)
            }
        }
    }

    private struct Leg {
        let hip: CGPoint, knee: CGPoint, ankle: CGPoint
        var kneeAngle: Double { PoseMath.angle(hip, knee, ankle) }
        var length: Double {
            Double(hypot(hip.x - knee.x, hip.y - knee.y) + hypot(knee.x - ankle.x, knee.y - ankle.y))
        }
    }

    private struct Arm {
        let elbowAngle: Double
        /// How far the shoulder–hip–ankle line is from straight, if the camera can see it.
        let bodySag: Double?
    }

    private static func leg(_ j: Joints, left: Bool) -> Leg? {
        guard let hip = j[left ? .leftHip : .rightHip],
              let knee = j[left ? .leftKnee : .rightKnee],
              let ankle = j[left ? .leftAnkle : .rightAnkle] else { return nil }
        return Leg(hip: hip, knee: knee, ankle: ankle)
    }

    private static func arm(_ j: Joints, left: Bool) -> Arm? {
        guard let shoulder = j[left ? .leftShoulder : .rightShoulder],
              let elbow = j[left ? .leftElbow : .rightElbow],
              let wrist = j[left ? .leftWrist : .rightWrist] else { return nil }
        var sag: Double?
        if let hip = j[left ? .leftHip : .rightHip], let ankle = j[left ? .leftAnkle : .rightAnkle] {
            sag = 180 - PoseMath.angle(shoulder, hip, ankle)
        }
        return Arm(elbowAngle: PoseMath.angle(shoulder, elbow, wrist), bodySag: sag)
    }

    private static func torsoLean(_ j: Joints) -> Double? {
        if let hip = j[.leftHip], let shoulder = j[.leftShoulder] {
            return PoseMath.leanFromVertical(hip: hip, shoulder: shoulder)
        }
        if let hip = j[.rightHip], let shoulder = j[.rightShoulder] {
            return PoseMath.leanFromVertical(hip: hip, shoulder: shoulder)
        }
        return nil
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
