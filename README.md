# Ollama AI Chat Box

一个基于 SwiftUI 的 macOS 聊天应用，支持多会话历史、灵动岛风格输入框，并集成本地 Ollama AI（如 deepseek-r1:14b）模型，实现本地大模型对话体验。

---

## 功能特性

- 支持多会话历史记录，侧边栏切换
- 聊天区消息气泡美观
- 灵动岛风格输入框，支持回车发送
- 发送按钮为黑色圆形
- 集成本地 Ollama AI，支持 deepseek-r1等模型
- Ollama 回复自动追加到当前会话

---

## 技术难点

- **SwiftUI 多会话数据结构与切换**：采用 `@State` + `Binding` 精确管理每个会话的消息，避免切换会话时消息重复或丢失。
- **灵动岛输入框实现**：通过 ZStack+HStack+圆角+毛玻璃，兼容多种输入法，支持回车发送与按钮发送。
- **Ollama 流式接口解析**：Ollama 的 `/api/chat` 返回多行 JSON，需拼接所有片段，正确还原完整回复。
- **本地网络权限与 Info.plist 配置**：macOS App 需配置 Info.plist 允许本地网络访问，否则无法请求 Ollama。
- **异步数据流与 UI 刷新**：通过 `DispatchQueue.main.async` 保证回车发送和按钮发送行为一致，避免 UI 不同步。

---

## Ollama API 接口说明

- **接口地址**：`http://localhost:11434/api/chat`
- **请求方式**：POST
- **请求体示例**：

```json
{
  "model": "deepseek-r1:14b",
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
   ollama pull deepseek-r1:14b
   ollama serve
   ```

2. **确保本地 11434 端口可访问**
   ```sh
   curl http://localhost:11434
   ```

3. **Info.plist 配置**
   - 必须包含如下内容，允许本地网络请求：
     ```xml
     <key>NSAppTransportSecurity</key>
     <dict>
         <key>NSAllowsArbitraryLoads</key>
         <true/>
     </dict>
     ```

---

## 常见问题与分析

### 1. **App 无法访问 Ollama，提示“服务器繁忙”或无响应**
- **原因**：Info.plist 未配置本地网络权限，或 Ollama 未启动/端口被占用。
- **解决**：确保 Info.plist 配置正确，Ollama 正常运行，11434 端口未被防火墙拦截。

### 2. **回车发送后输入框内容不清空/消息重复**
- **原因**：SwiftUI 的数据流未同步，或回车事件未正确触发。
- **解决**：用 `DispatchQueue.main.async` 包裹发送逻辑，确保 UI 刷新同步。

### 3. **Ollama 回复内容为空或不完整**
- **原因**：未正确拼接 Ollama 流式返回的多行 JSON。
- **解决**：解析所有返回行，拼接所有 `message.content` 字段。

### 4. **发送按钮有方形遮罩**
- **原因**：按钮外层有毛玻璃或系统高亮。
- **解决**：只给按钮本身加 `.background(Color.black).clipShape(Circle())`，并加 `.buttonStyle(.plain)`。

### 5. **App 无法联网**
- **原因**：本地网络权限未开启，或 macOS 拒绝了网络访问。
- **解决**：在“系统设置 > 安全性与隐私 > 隐私 > 本地网络”中允许 App 访问。

---

## 代码结构

- `ContentView.swift`：主界面、会话管理、消息发送与接收
- `DynamicIslandInputView.swift`：灵动岛输入框 UI
- `OllamaClient.swift`：Ollama API 网络请求与流式解析
- `Info.plist`：App 配置与本地网络权限

---

## 贡献与反馈

欢迎 issue、PR 或建议！如遇到无法解决的问题，请贴出控制台日志和你的操作步骤，我会第一时间协助。

---

## License

MIT
