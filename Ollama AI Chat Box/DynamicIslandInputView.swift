import SwiftUI

struct DynamicIslandInputView: View {
    @Binding var text: String
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("请输入...", text: $text, onCommit: {
                DispatchQueue.main.async {
                    onSend()
                }
            })
            .textFieldStyle(PlainTextFieldStyle())
            .font(.title3)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
            .cornerRadius(24)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(32)
        .shadow(radius: 16)
    }
}

