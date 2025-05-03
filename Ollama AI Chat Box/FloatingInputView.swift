import SwiftUI

struct FloatingInputView: View {
    @Binding var text: String
    var onSend: () -> Void
    @Binding var textEditorHeight: CGFloat

    var body: some View {
        HStack {
            CustomTextEditor(
                text: $text,
                height: textEditorHeight,
                onHeightChange: { _ in }
            )
            .frame(maxWidth: 400)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .onKeyPress(.return, phases: .down) { press in
                if press.modifiers.contains(.shift) {
                    text += "\n"
                    return .handled
                } else {
                    onSend()
                    return .handled
                }
            }

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(28)
        .shadow(radius: 20)
    }
}
