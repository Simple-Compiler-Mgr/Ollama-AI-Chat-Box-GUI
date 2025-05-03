# Ollama AI Chat Box

一个基于 SwiftUI 的 macOS 聊天应用，支持多会话历史、灵动岛风格输入框，并集成本地 Ollama AI（如 deepseek-r1）模型，实现本地大模型对话体验。

---

## 功能特性

- 支持多会话历史记录，侧边栏切换
- 聊天区消息气泡美观
- 灵动岛风格输入框，支持回车发送
- 发送按钮为黑色圆形
- 集成本地 Ollama AI，支持 deepseek-r1 等模型
- Ollama 回复自动追加到当前会话

---

## 技术难点与高级说明

- **SwiftUI 多会话数据结构与切换**：采用 `@State` + `Binding` 精确管理每个会话的消息，避免切换会话时消息重复或丢失。
- **灵动岛输入框实现**：通过 ZStack+HStack+圆角+毛玻璃，兼容多种输入法，支持回车发送与按钮发送。
- **Ollama 流式接口解析**：Ollama 的 `/api/chat` 返回多行 JSON，需拼接所有片段，正确还原完整回复。
- **本地网络权限与 Info.plist 配置**：macOS App 需配置 Info.plist 允许本地网络访问，否则无法请求 Ollama。
- **异步数据流与 UI 刷新**：通过 `DispatchQueue.main.async` 保证回车发送和按钮发送行为一致，避免 UI 不同步。
- **网络环境适配**：需确保本地 11434 端口可用，且无 VPN、代理、杀毒软件、系统防火墙等影响本地回环网络。
- **API 错误与调试**：对 Ollama API 的所有返回内容做健壮解析，支持流式和非流式返回，便于调试和扩展。

---

## Ollama API 接口说明

- **接口地址**：`http://localhost:11434/api/chat`
- **请求方式**：POST
- **请求体示例**：

```json
{
  "model": "deepseek-r1",
  "messages": [
    {"role": "user", "content": "你好"}
  ]
}
```

- **返回格式**：流式多行 JSON，每行一个片段，需拼接所有 `message.content` 字段。

---

## 运行前准备

1. **安装 Ollama 并拉取模型**
   ```sh
   ollama pull deepseek-r1
   ollama serve
   ```

2. **确保本地 11434 端口可访问**
   ```sh
   curl http://localhost:11434
   ```
   - 若 curl 无法访问，需检查 Ollama 是否启动、端口是否被占用。

3. **Info.plist 配置**
   - 必须包含如下内容，允许本地网络请求：
     ```xml
     <key>NSAppTransportSecurity</key>
     <dict>
         <key>NSAllowsArbitraryLoads</key>
         <true/>
     </dict>
     ```

4. **网络环境注意事项**
   - 关闭所有 VPN、代理、杀毒软件、系统防火墙等可能影响本地回环（127.0.0.1/localhost）访问的工具。
   - 若端口被占用，请更换 Ollama 端口并同步修改代码。
   - 若 App 首次访问本地网络，macOS 可能弹窗询问权限，请务必允许。

---

## 代码结构与作用

- `ContentView.swift`：主界面、会话管理、消息发送与接收、与输入框和 OllamaClient 的集成。
- `DynamicIslandInputView.swift`：灵动岛输入框 UI，负责输入和发送按钮的交互。
- `OllamaClient.swift`：Ollama API 网络请求与流式解析，负责与本地大模型通信。
- `Info.plist`：App 配置与本地网络权限。

---

## 关键代码片段与解析

### 1. OllamaClient.swift

```swift
class OllamaClient {
    static let shared = OllamaClient()
    let baseURL = URL(string: "http://localhost:11434/api/chat")!

    func chat(model: String, messages: [OllamaMessage], completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OllamaRequest(model: model, messages: messages)
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ollama 请求错误：\(error)")
            }
            guard let data, error == nil else {
                completion(nil)
                return
            }
            if let str = String(data: data, encoding: .utf8) {
                print("Ollama 返回内容：\(str)")
                let lines = str.split(separator: "\n")
                let allContents = lines.compactMap { line -> String? in
                    if let jsonData = line.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(OllamaResponse.self, from: jsonData) {
                        return decoded.message.content
                    }
                    return nil
                }
                completion(allContents.joined())
            } else {
                completion(nil)
            }
        }.resume()
    }
}
```

- **作用**：负责与 Ollama 本地 API 通信，自动拼接流式返回的所有片段。
- **调试**：如遇到问题，可通过控制台打印的 Ollama 返回内容定位。
- **修改**：如需更换端口或 API 路径，修改 `baseURL` 即可。

### 2. ContentView.swift 发送消息与调用 Ollama

```swift
func sendMessage() {
    let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    currentMessagesBinding.wrappedValue.append(
        Message(content: trimmed, isUser: true, timestamp: Date())
    )
    let userMsg = OllamaMessage(role: "user", content: trimmed)
    let history = currentMessagesBinding.wrappedValue.map {
        OllamaMessage(role: $0.isUser ? "user" : "assistant", content: $0.content)
    } + [userMsg]
    newMessage = ""

    OllamaClient.shared.chat(model: "deepseek-r1", messages: history) { reply in
        DispatchQueue.main.async {
            if let reply = reply {
                currentMessagesBinding.wrappedValue.append(
                    Message(content: reply, isUser: false, timestamp: Date())
                )
            } else {
                currentMessagesBinding.wrappedValue.append(
                    Message(content: "AI 回复失败", isUser: false, timestamp: Date())
                )
            }
        }
    }
}
```

- **作用**：用户发送消息后，自动调用 Ollama 并追加 AI 回复。
- **注意**：如需更换模型，修改 `model: "deepseek-r1"`。

### 3. DynamicIslandInputView.swift

```swift
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
```

- **作用**：灵动岛风格输入框，支持回车发送和按钮发送。
- **注意**：按钮样式防止出现方形遮罩。

---

## 运行和调试注意事项

- **本地网络权限**：首次运行请允许 App 访问本地网络。
- **端口冲突**：如 11434 端口被占用，需更换 Ollama 端口并同步修改代码。
- **VPN/代理/杀毒软件**：如遇到无法访问本地 API，请关闭所有 VPN、代理、杀毒软件和系统防火墙。
- **API 调试**：如遇到 AI 回复失败，请在控制台查看 Ollama 返回内容，便于定位问题。
- **模型名拼写**：确保模型名与 `ollama list` 输出一致。

---

## 常见问题与分析

### 1. **App 无法访问 Ollama，提示"服务器繁忙"或无响应**
- **原因**：Info.plist 未配置本地网络权限，Ollama 未启动/端口被占用，或被 VPN/代理/防火墙拦截。
- **解决**：确保 Info.plist 配置正确，Ollama 正常运行，11434 端口未被防火墙/VPN/代理占用。

### 2. **回车发送后输入框内容不清空/消息重复**
- **原因**：SwiftUI 的数据流未同步，或回车事件未正确触发。
- **解决**：用 `DispatchQueue.main.async` 包裹发送逻辑，确保 UI 刷新同步。

### 3. **Ollama 回复内容为空或不完整**
- **原因**：未正确拼接 Ollama 流式返回的多行 JSON。
- **解决**：解析所有返回行，拼接所有 `message.content` 字段。

### 4. **发送按钮有方形遮罩**
- **原因**：按钮外层有毛玻璃或系统高亮。
- **解决**：只给按钮本身加 `.background(Color.black).clipShape(Circle())`，并加 `.buttonStyle(.plain)`。

### 5. **App 无法联网或本地 API 无法访问**
- **原因**：本地网络权限未开启，或 macOS 拒绝了网络访问，或 VPN/代理/杀毒软件/防火墙拦截。
- **解决**：在"系统设置 > 安全性与隐私 > 隐私 > 本地网络"中允许 App 访问，关闭所有 VPN/代理/杀毒软件/防火墙。

### 6. **端口被占用或模型名错误**
- **原因**：Ollama 端口被占用或模型名拼写错误。
- **解决**：更换端口并同步修改代码，或用 `ollama list` 检查模型名。

---

## 贡献与反馈

欢迎 issue、PR 或建议！如遇到无法解决的问题，请贴出控制台日志和你的操作步骤，我会第一时间协助。

---

## License

Sompiler

