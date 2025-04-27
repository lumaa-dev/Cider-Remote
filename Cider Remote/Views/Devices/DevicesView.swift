// Made by Lumaa

import SwiftUI

struct DevicesView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    @EnvironmentObject private var viewModel: DeviceListViewModel

    @AppStorage("autoRefresh") private var autoRefresh: Bool = true

    @State private var scannedCode: String?
    @State private var isShowingScanner = false
    @State private var isShowingGuide = false

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                ForEach(viewModel.devices) { device in
                    if device.isActive {
                        NavigationLink(value: device) {
                            DeviceRowView(device: device)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteDevice(device: device)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        if autoRefresh {
                            DeviceRowView(device: device)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        viewModel.deleteDevice(device: device)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        } else {
                            Button {
                                Task {
                                    await viewModel.refreshDevice(device)
                                }
                            } label: {
                                HStack {
                                    DeviceRowView(device: device)

                                    Spacer()

                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(Color(uiColor: UIColor.tertiaryLabel))
                                }
                            }
                            .tint(Color(uiColor: UIColor.label))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteDevice(device: device)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                AddDeviceView(isShowingScanner: $isShowingScanner, scannedCode: $scannedCode, viewModel: viewModel)

                Button(action: {
                    isShowingGuide = true
                }) {
                    Label("Connection Guide", systemImage: "questionmark.circle")
                }
            }
            .listStyle(InsetGroupedListStyle())
            .task {
                await viewModel.refreshDevices()
            }
            .refreshable {
                await viewModel.refreshDevices()
            }
#if DEBUG
            Label("This is a DEBUG version.", systemImage: "gearshape.2.fill")
                .foregroundStyle(.orange)
                .accessibility(label: Text("Debug software"))
#else
            Label("This software is in BETA.", systemImage: "hammer.circle.fill")
                .foregroundStyle(.gray)
                .accessibility(label: Text("Beta software"))
#endif
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Device.self) { device in
            LazyView(MusicPlayerView(device: device))
        }
        .sheet(isPresented: $isShowingGuide) {
            ConnectionGuideView()
        }
        .onAppear {
            viewModel.startActivityChecking()
        }
        .onDisappear {
            viewModel.stopActivityChecking()
        }
    }

    var header: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)

            Text("Cider Devices")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Material.ultraThick)
    }
}
