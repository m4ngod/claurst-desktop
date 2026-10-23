import SwiftUI
#if SWIFT_PACKAGE
import DesktopCore
#endif

struct UserQuestionView: View {
    let question: UserQuestion
    let submit: (String) -> Void
    @State private var answer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.isPending ? "需要你的回答" : "助手提问").font(.headline)
            Text(question.question).textSelection(.enabled)
            if question.isPending {
                ForEach(Array(question.options.enumerated()), id: \.offset) { _, option in
                    Button(option) { submit(option) }.buttonStyle(.bordered)
                }
                TextField("输入你的回答", text: $answer).textFieldStyle(.roundedBorder)
                Button("提交回答") { submit(answer) }.buttonStyle(.borderedProminent)
                    .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Text(question.answer.map { "你的回答：" + $0 } ?? "问题已结束，未提交回答。")
                    .foregroundColor(.secondary).textSelection(.enabled)
            }
        }.padding(14).background(Color.black.opacity(0.04)).cornerRadius(10)
    }
}
