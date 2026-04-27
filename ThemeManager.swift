import SwiftUI

enum ThemeColor: String, CaseIterable, Identifiable {
    case `default` = "Default"
    case grey = "Grey"
    case purple = "Purple"
    case yellow = "Yellow"
    case red = "Red"
    case blue = "Blue"
    case lightBlue = "Light Blue"
    case green = "Green"
    case orange = "Orange"
    
    var id: String { self.rawValue }
    
    var color: Color? {
        switch self {
        case .default: return nil
        case .grey: return .gray
        case .purple: return .purple
        case .yellow: return .yellow
        case .red: return .red
        case .blue: return .blue
        case .lightBlue: return .cyan
        case .green: return .green
        case .orange: return .orange
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
