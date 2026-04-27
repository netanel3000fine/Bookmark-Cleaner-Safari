import SwiftUI

struct SettingsView: View {
    @AppStorage("isLiquidGlass") private var isLiquidGlass: Bool = false
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    
    var body: some View {
        ZStack {
            // High-Vibrancy Liquid Glass Background
            if isLiquidGlass {
                VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                if let color = themeColor.color {
                    color.opacity(0.12).ignoresSafeArea()
                }
                LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            } else {
                Color(NSColor.windowBackgroundColor)
            }
            
            // Centered Content Container
            VStack {
                Spacer().frame(height: 60)
                
                VStack(alignment: .leading, spacing: 30) {
                    Text("Appearance")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 25) {
                        HStack {
                            Text("Liquid Glass Transparent")
                                .font(.system(.body, design: .rounded).bold())
                                .foregroundStyle(.primary.opacity(0.9))
                            Spacer()
                            Toggle("", isOn: $isLiquidGlass)
                                .toggleStyle(.switch)
                        }
                        
                        Divider().opacity(0.1)
                        
                        VStack(alignment: .leading, spacing: 18) {
                            Text("Theme Color")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 16) {
                                ForEach(ThemeColor.allCases) { colorOption in
                                    Button {
                                        themeColor = colorOption
                                    } label: {
                                        ZStack {
                                            if colorOption == .default {
                                                Image(systemName: "circle.slash")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(themeColor == colorOption ? .primary : .secondary)
                                            } else {
                                                Circle()
                                                    .fill(colorOption.color ?? .clear)
                                                    .frame(width: 28, height: 28)
                                                    .shadow(color: (colorOption.color ?? .clear).opacity(0.5), radius: themeColor == colorOption ? 10 : 0)
                                            }
                                        }
                                        .frame(width: 50, height: 50)
                                        .background {
                                            ZStack {
                                                if themeColor == colorOption {
                                                    VisualEffectView(material: .selection, blendingMode: .withinWindow)
                                                        .clipShape(Circle())
                                                } else {
                                                    Circle().fill(Color.primary.opacity(0.08))
                                                }
                                            }
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(themeColor == colorOption ? (colorOption.color ?? .primary) : .primary.opacity(0.2), lineWidth: themeColor == colorOption ? 3 : 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .scaleEffect(themeColor == colorOption ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: themeColor)
                                    .help(colorOption.rawValue)
                                }
                            }
                        }
                    }
                    .padding(30)
                    .background {
                        ZStack {
                            VisualEffectView(material: .sidebar, blendingMode: .withinWindow)
                                .opacity(0.4)
                            
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.primary.opacity(0.02))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(LinearGradient(colors: [.white.opacity(0.35), .clear, .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                                }
                        }
                    }
                    .cornerRadius(24)
                }
                .frame(maxWidth: 550) // Constrain content width for focus and safety
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 750, height: 550) // Expansive window dimensions
        .background(WindowAccessor())
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = .floating
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
