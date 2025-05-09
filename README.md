# JSONModelGenerator

**JSONModelGenerator** 是一款专为开发者打造的 macOS 应用程序，用于将 JSON 字符串快速转换为多种编程语言的数据模型代码，帮助提升开发效率，减少手动编码错误。

## ✨ 功能特色

- 🚀 一键生成模型代码  
- 🧠 自动识别数据结构与类型  
- 🛠 支持多种主流语言  
- 💻 macOS 原生应用，流畅稳定  

## 💡 支持语言

JSONModelGenerator 当前支持以下语言的数据模型生成：

- Swift  
- Objective-C  
- C++  
- PHP  
- Python  
- TypeScript  
- Java  
- Ruby  
- Rust  
- Kotlin  

## 📦 安装方式

你可以直接通过 **Mac App Store** 安装本应用：

👉 [点击前往 Mac App Store 下载](https://apps.apple.com/cn/app/json%E8%BD%AC%E6%A8%A1%E5%9E%8B/id6744920149?mt=12)

或者在 Mac 上打开 App Store，搜索 `JSON转模型` 即可。

## 🛠 使用方法

1. 打开应用程序。  
2. 粘贴或输入你的 JSON 字符串。  
3. 选择目标语言。  
4. 点击“生成”，即可复制或导出对应的模型代码。  

## 📂 示例

输入 JSON：

```json
{
  "id": 123,
  "name": "Alice",
  "isActive": true
}
```
选择 Swift，输出：
```
struct Model: Codable {
    let id: Int
    let name: String
    let isActive: Bool
}
```

🙌 反馈与支持

如果你在使用过程中有任何建议或遇到问题，欢迎在 GitHub 提交 Issue，或在 App Store 留下你的评价与建议。

📄 许可证

本项目采用 MIT License。
