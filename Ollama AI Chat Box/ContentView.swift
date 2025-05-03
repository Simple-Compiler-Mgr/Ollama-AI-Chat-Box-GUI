//
//  ContentView.swift
//  Ollama AI Chat Box
//
//  Created by zuole on 5/3/25.
//

import SwiftUI
import AppKit

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct Conversation: Identifiable {
    let id = UUID()
    let title: String
    var messages: [Message]
    let date: Date
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            Text(message.content)
                .padding()
                .background(
                    message.isUser ?
                    Color.blue.opacity(0.2) :
                    Color.gray.opacity(0.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
            
            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}

struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    var height: CGFloat
    var onHeightChange: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        
        // 只设置高度，不要设置宽度
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        
        textView.wantsLayer = true
        textView.layer?.cornerRadius = 16
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
        nsView.frame.size.height = height
        // 不要设置 nsView.frame.size.width
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

struct ContentView: View {
    @State private var newMessage: String = ""
    @State private var textEditorHeight: CGFloat = 32
    @State private var conversations: [Conversation] = [
        Conversation(title: "新对话", messages: [], date: Date())
    ]
    @State private var selectedConversation: Conversation.ID?

    var currentMessagesBinding: Binding<[Message]> {
        if let selected = selectedConversation,
           let idx = conversations.firstIndex(where: { $0.id == selected }) {
            return $conversations[idx].messages
        } else if !conversations.isEmpty {
            return $conversations[0].messages
        } else {
            return .constant([])
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack {
                Button(action: newConversation) {
                    Label("新建对话", systemImage: "plus")
                        .font(.headline)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 12)

                List(selection: $selectedConversation) {
                    ForEach(conversations) { conversation in
                        VStack(alignment: .leading) {
                            Text(conversation.title)
                                .font(.headline)
                            Text(conversation.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minWidth: 200)
            }
        } detail: {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // 聊天消息区
                    ScrollView {
                        LazyVStack {
                            ForEach(currentMessagesBinding.wrappedValue) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                // 灵动岛输入框悬浮在底部
                HStack {
                    Spacer()
                    DynamicIslandInputView(
                        text: $newMessage,
                        onSend: sendMessage
                    )
                    .frame(maxWidth: 420)
                    Spacer()
                }
                .padding(.bottom, 32)
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }

    func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 追加用户消息
        currentMessagesBinding.wrappedValue.append(
            Message(content: trimmed, isUser: true, timestamp: Date())
        )
        let userMsg = OllamaMessage(role: "user", content: trimmed)
        let history = currentMessagesBinding.wrappedValue.map {
            OllamaMessage(role: $0.isUser ? "user" : "assistant", content: $0.content)
        } + [userMsg]
        newMessage = ""

        // 调用 Ollama
        OllamaClient.shared.chat(model: "deepseek-r1:14b", messages: history) { reply in
            DispatchQueue.main.async {
                if let reply = reply {
                    currentMessagesBinding.wrappedValue.append(
                        Message(content: reply, isUser: false, timestamp: Date())
                    )
                } else {
                    currentMessagesBinding.wrappedValue.append(
                        Message(content: "服务器繁忙，请稍后再试", isUser: false, timestamp: Date())
                    )
                }
            }
        }
    }

    func newConversation() {
        let newConv = Conversation(title: "新对话", messages: [], date: Date())
        conversations.append(newConv)
        selectedConversation = newConv.id
        // 可选：自动切换到新会话
    }
}

#Preview {
    ContentView()
}
