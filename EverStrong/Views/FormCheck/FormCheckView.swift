import SwiftUI
import AVFoundation

struct FormCheckView: View {
    @State private var exercise: Exercise = ExerciseLibrary.withFormCheck.first!
    @State private var checking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your iPhone watches your movement, counts for you and gives you tips as you go, out loud and on screen.")
                        .font(.title3)

                    Text("Choose an exercise").font(.title2.bold())
                    ForEach(ExerciseLibrary.withFormCheck) { option in
                        Button { exercise = option } label: {
                            HStack {
                                Image(systemName: option.symbol).font(.title).frame(width: 44)
                                Text(option.name).font(.title3.bold())
                                Spacer()
                                Image(systemName: option == exercise ? "checkmark.circle.fill" : "circle").font(.title2)
                            }
                            .padding(16)
                            .foregroundStyle(option == exercise ? Color.white : Color.primary)
                            .background(option == exercise ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Card {
                        Text("How to set up").font(.title3.bold())
                        ForEach(exercise.formCheck?.setupSteps ?? [], id: \.text) { step in
                            Label(step.text, systemImage: step.symbol)
                        }
                    }
                    .font(.body)

                    BigButton(title: "Start form check", symbol: "camera.fill") { checking = true }

                    Text(Disclaimers.formCheck).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Form Check")
            .fullScreenCover(isPresented: $checking) { LiveFormCheckView(exercise: exercise) }
        }
    }
}

struct LiveFormCheckView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = FormCheckModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.status {
            case .needsPermission: permissionView
            case .unavailable: messageView("The camera isn't available on this device.")
            default: cameraView
            }
        }
        .task { await model.start(kind: exercise.formCheck ?? .squat) }
        .onDisappear { model.stop() }
    }

    private var cameraView: some View {
        ZStack {
            CameraPreview(session: model.session).ignoresSafeArea()
            SkeletonOverlay(pose: model.pose).ignoresSafeArea()
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text(exercise.name).font(.title2.bold())
                        if let metric = model.metricText {
                            Text(metric).font(.headline).monospacedDigit()
                        }
                    }
                    Spacer()
                    VStack {
                        Text("\(model.count)").font(.system(size: 64, weight: .heavy, design: .rounded)).monospacedDigit()
                        Text(model.countLabel).font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(model.count) \(model.countLabel)")
                }
                .padding(20)
                .foregroundStyle(.white)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))

                Spacer()

                Text(model.message)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .background((model.messageIsPositive ? Color.green : Color.orange).opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityAddTraits(.updatesFrequently)

                BigButton(title: "Finish", symbol: "checkmark", color: .white, foreground: .black) { dismiss() }
            }
            .padding(16)
        }
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill").font(.system(size: 64))
            Text("EverStrong needs camera access to check your form. Video never leaves your phone.")
                .font(.title3).multilineTextAlignment(.center)
            BigButton(title: "Open Settings", symbol: "gearshape.fill") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Close") { dismiss() }.font(.title3)
        }
        .foregroundStyle(.white)
        .padding(24)
    }

    private func messageView(_ text: String) -> some View {
        VStack(spacing: 20) {
            Text(text).font(.title3).multilineTextAlignment(.center)
            BigButton(title: "Close", symbol: "xmark") { dismiss() }
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

/// Shows the live camera feed.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection, connection.isVideoRotationAngleSupported(90),
           connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }
}

/// Draws the detected joints and bones over the camera feed, matching aspect-fill cropping.
struct SkeletonOverlay: View {
    let pose: PoseFrame

    var body: some View {
        Canvas { context, size in
            guard pose.imageSize.width > 0 else { return }
            let scale = max(size.width / pose.imageSize.width, size.height / pose.imageSize.height)
            let drawn = CGSize(width: pose.imageSize.width * scale, height: pose.imageSize.height * scale)
            let offset = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: offset.x + p.x * drawn.width, y: offset.y + p.y * drawn.height)
            }
            var bones = Path()
            for (a, b) in PoseFrame.bones {
                if let pa = pose.joints[a], let pb = pose.joints[b] {
                    bones.move(to: map(pa))
                    bones.addLine(to: map(pb))
                }
            }
            context.stroke(bones, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            for point in pose.joints.values {
                let p = map(point)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16)), with: .color(.green))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
