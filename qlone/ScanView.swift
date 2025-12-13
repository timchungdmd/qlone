import SwiftUI
import ARKit

struct ScanView: View {
    @ObservedObject var scanManager: ARScanManager

    // MARK: - Body

    var body: some View {
        ZStack {
            // AR camera background
            ARViewContainer(session: scanManager.arSession())
                .ignoresSafeArea()

            VStack {
                // TOP BAR: resolution gear on the right
                HStack {
                    Spacer()
                    resolutionMenu
                }
                .padding(.top, 20)
                .padding(.trailing, 16)

                Spacer()

                // BOTTOM HUD
                VStack(spacing: 12) {
                    // Status text
                    Text(scanManager.statusText)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 32) {

                        // Torch
                        Button {
                            scanManager.setTorch(enabled: !scanManager.isTorchOn)
                        } label: {
                            Image(systemName: scanManager.isTorchOn
                                  ? "flashlight.on.fill"
                                  : "flashlight.off.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                        }

                        // Main record / stop
                        Button {
                            if scanManager.isRunning {
                                scanManager.stop()
                            } else {
                                scanManager.start()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 78, height: 78)

                                Circle()
                                    .fill(scanManager.isRunning ? .red : .white)
                                    .frame(width: 58, height: 58)
                            }
                        }

                        // Manual shutter (for Manual mode)
                        Button {
                            scanManager.manualCapture()
                        } label: {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                        .disabled(scanManager.captureMode != .manual || !scanManager.isRunning)
                    }
                }
                .padding(.bottom, 30)
                .padding(.horizontal, 24)
            }
        }
        .onDisappear {
            scanManager.stop()
        }
    }

    // MARK: - Resolution menu (top-right gear)

    private var resolutionMenu: some View {
        Menu {
            Picker("AR Video Resolution",
                   selection: $scanManager.arVideoResolution) {
                ForEach(ARVideoResolutionPreset.allCases, id: \.self) { preset in
                    Text(preset.label).tag(preset)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)

                Image(systemName: "gearshape")
                    .foregroundColor(.white)
                    .imageScale(.large)
            }
        }
    }
}
