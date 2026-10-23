import Foundation
import Combine

public struct ModelConfiguration: Equatable {
    public var endpoint: String
    public var model: String
    public var apiKey: String
    public var isTest: Bool
    public var imageInputEnabled: Bool
    public var webSearchEnabled: Bool
    public init(endpoint: String, model: String, apiKey: String, isTest: Bool = false, imageInputEnabled: Bool = false, webSearchEnabled: Bool = false) {
        self.endpoint = endpoint; self.model = model; self.apiKey = apiKey; self.isTest = isTest; self.imageInputEnabled = imageInputEnabled
        self.webSearchEnabled = webSearchEnabled
    }
    func usesSameService(as other: ModelConfiguration) -> Bool {
        endpoint == other.endpoint && model == other.model && apiKey == other.apiKey && isTest == other.isTest
    }
}

public enum TaskStatus: String, Codable {
    case ready = "待运行", preparing = "正在读取模型凭据", running = "运行中", waiting = "等待授权", answering = "等待回答", stopping = "正在停止", stopped = "已停止", failed = "失败", completed = "完成", elsewhere = "另一个窗口中"
    public var isActive: Bool { self == .preparing || self == .running || self == .waiting || self == .answering || self == .stopping }
}
public struct ChatMessage: Identifiable, Codable {
    public var id = UUID()
    public var role: String
    public var text: String
}
public struct DesktopTask: Identifiable, Codable {
    public var id = UUID()
    public var createdAt = Date()
    public var title = "新任务"
    public var workspace: URL
    public var workspaceIdentity: String?
    public var status: TaskStatus = .ready
    public var messages: [ChatMessage] = []
    public var error: String?
    public var controlNotice: String?
    public var recoveryWarnings: [String] = []
    public var requiresHistoryRecovery = false
    public var isTest = false
    public var modelName: String?
    public var endpoint: String?
    public var sources: [FileSource] = []
    // Optional storage preserves histories created before web reading existed.
    fileprivate var recordedWebSources: [WebSource]?
    public var webSources: [WebSource] {
        get { recordedWebSources ?? [] }
        set { recordedWebSources = newValue }
    }
    fileprivate var recordedLaTeXArtifacts: [LaTeXArtifact]?
    public var latexArtifacts: [LaTeXArtifact] {
        get { recordedLaTeXArtifacts ?? [] }
        set { recordedLaTeXArtifacts = newValue }
    }
    public var changes: [FileChange] = []
    public var tools: [ToolExecution] = []
    public var permissions: [PermissionQuestion] = []
    public var questions: [UserQuestion] = []
    public var requirements: [TaskRequirement] = []
}

public enum RequirementState: String, Codable { case received = "已收到", applied = "已应用" }
public struct TaskRequirement: Identifiable, Codable {
    public var id = UUID()
    public let text: String
    public var state: RequirementState = .received
}

public struct UserQuestion: Identifiable, Codable {
    public let id: UUID
    public let question: String
    public let options: [String]
    public var answer: String?
    public var isPending = true
}

public struct PermissionQuestion: Identifiable, Codable {
    public let id: UUID
    public let description: String
}

public struct DocumentLocation: Codable {
    public enum Unit: String, Codable { case page, paragraph, image }
    public let unit: Unit
    public let first: Int
    public let last: Int
    public let total: Int
    public var recognition: Bool?
    public var visual: Bool?
    public var label: String {
        let name = unit == .page ? "页" : (unit == .image ? "张" : "段")
        return "第 \(first)–\(last) \(name) / 共 \(total) \(name)"
    }
}

public struct TableLocation: Codable {
    public let sheet: String
    public let first_row: Int
    public let last_row: Int
    public let first_column: Int
    public let last_column: Int
    public let total_rows: Int
    public var label: String { "\(sheet) · 第 \(first_row)–\(last_row) 行，第 \(first_column)–\(last_column) 列 / 共 \(total_rows) 行" }
}

public struct FileSource: Identifiable, Codable {
    public var id = UUID()
    public let file: URL
    public let firstLine: Int
    public let lastLine: Int
    public let excerpt: String
    public var documentLocation: DocumentLocation?
    public var tableLocation: TableLocation?
    public var locationLabel: String {
        tableLocation?.label ?? documentLocation?.label ?? (lastLine == 0 ? "空文件" : "第 \(firstLine)–\(lastLine) 行")
    }
}
public struct ToolExecution: Identifiable, Codable {
    public let id: String
    public var title: String
    public var status: String
    public var output: String = ""
    public var check: ProjectCheck?
}

public enum ProjectCheckState: String, Codable {
    case running, passed, failed, skipped, notRun = "not_run", unconfirmed
    public var label: String {
        switch self {
        case .running: return "运行中"
        case .passed: return "命令退出码 0"
        case .failed: return "失败"
        case .skipped: return "已跳过"
        case .notRun: return "未运行"
        case .unconfirmed: return "结果未确认"
        }
    }
}
public struct ProjectCheck: Codable {
    public let name: String
    public var state: ProjectCheckState
}

public struct FileChange: Identifiable, Codable {
    public let id: String
    public let file: URL
    public let summary: String
    public let diff: String
    public let before: String?
    public let after: String
    public let record: URL
    public var restoredAt: Date?
    public var restoreError: String?
    public var originalFile: URL?
    public var reason: String?
}

private struct FileChangeRecord: Decodable {
    let id: String
    let path: String
    let before: String?
    let after: String
    let diff: String
    let operation: String?
    let original_path: String?
    let reason: String?
}

@MainActor public final class TaskService: ObservableObject {
    @Published public private(set) var tasks: [DesktopTask] = [] { didSet { scheduleHistorySave() } }
    @Published public private(set) var modelProfiles: [ModelProfile] = []
    @Published public private(set) var settingsError: String?
    @Published public private(set) var historyError: String?
    private let storageDirectory: URL
    private let modelStore: ModelSettingsStore
    private let historyStore: TaskHistoryStore
    private var historyReady = false
    private var historySave: Task<Void, Never>?
    private let executable: URL
    private var clients: [UUID: ACPProcess] = [:]
    private var sessions: [UUID: String] = [:]
    private var configurations: [UUID: ModelConfiguration] = [:]
    private var configurationProfileIDs: [UUID: UUID] = [:]
    private var continuationConfigurations: [UUID: ModelConfiguration] = [:]
    private var runs: [UUID: UUID] = [:]
    private var continueWithRequirements: Set<UUID> = []
    private var restorations: Set<UUID> = []
    private var updatingModelSettings = false
    private var credentialStarts: [UUID: UUID] = [:]

    public init(executable: URL, storageDirectory: URL? = nil, keychainService: String = "local.claurst.desktop.models", allowKeychainUI: Bool = true) {
        self.executable = executable
        let directory = storageDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaurstDesktop", isDirectory: true)
        self.storageDirectory = directory
        historyStore = TaskHistoryStore(directory: directory)
        modelStore = ModelSettingsStore(directory: directory, service: keychainService, allowInteraction: allowKeychainUI)
        do { modelProfiles = try modelStore.load() }
        catch { settingsError = error.localizedDescription }
        let history = historyStore.load()
        tasks = history.tasks
        historyError = history.warning
        historyReady = true
    }

    public var historyDirectory: URL { historyStore.directory }

    public func reloadHistory() {
        let active = Set(tasks.filter { $0.status.isActive }.map(\.id))
        let history = historyStore.load(preserving: active)
        let loaded = Set(history.tasks.map(\.id))
        tasks = (tasks.filter { active.contains($0.id) || !loaded.contains($0.id) }
            + history.tasks.filter { !active.contains($0.id) }).sorted { $0.createdAt > $1.createdAt }
        for task in tasks where !active.contains(task.id) {
            clients.removeValue(forKey: task.id)?.close()
            sessions[task.id] = nil
        }
        historyError = history.warning
    }

    private func scheduleHistorySave() {
        guard historyReady, historySave == nil else { return }
        historySave = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 200_000_000) }
            catch { return }
            self?.persistHistory()
        }
    }

    @discardableResult private func persistHistory() -> Bool {
        historySave?.cancel(); historySave = nil
        do { try historyStore.save(tasks); return true }
        catch {
            historyError = (error as? SettingsFailure)?.message ?? "任务历史保存失败。已完成的文件修改仍保留，请检查磁盘空间和历史目录权限后重试。"
            return false
        }
    }

    @discardableResult public func saveModelProfile(id: UUID? = nil, name: String, configuration: ModelConfiguration) async throws -> ModelProfile {
        if let settingsError { throw SettingsFailure(settingsError) }
        try validateModelConfiguration(configuration)
        guard !updatingModelSettings else { throw SettingsFailure("模型设置正在保存，请稍后重试。") }
        updatingModelSettings = true
        defer { updatingModelSettings = false }
        let old = modelProfiles.first { $0.id == id }
        if var unchanged = old,
           unchanged.endpoint == configuration.endpoint, unchanged.model == configuration.model,
           unchanged.isTest == configuration.isTest,
           (try? await modelStore.readSecret(unchanged.secretReference)) == configuration.apiKey {
            unchanged.name = name.isEmpty ? configuration.model : name
            unchanged.webSearchEnabled = configuration.webSearchEnabled
            var updated = modelProfiles.filter { $0.id != unchanged.id }
            updated.append(unchanged)
            try modelStore.save(updated)
            modelProfiles = updated
            return unchanged
        }
        let reference = try await modelStore.createSecret(configuration.apiKey)
        let profile = ModelProfile(id: id ?? UUID(), name: name.isEmpty ? configuration.model : name,
            endpoint: configuration.endpoint, model: configuration.model, isTest: configuration.isTest, secretReference: reference,
            webSearchEnabled: configuration.webSearchEnabled)
        var updated = modelProfiles.filter { $0.id != profile.id }
        updated.append(profile)
        do { try modelStore.save(updated) }
        catch { try? await modelStore.removeSecret(reference); throw error }
        modelProfiles = updated
        if let old { try await modelStore.removeSecret(old.secretReference) }
        return profile
    }

    public func removeModelProfile(id: UUID) async throws {
        guard !updatingModelSettings else { throw SettingsFailure("模型设置正在保存，请稍后重试。") }
        guard let profile = modelProfiles.first(where: { $0.id == id }) else { return }
        updatingModelSettings = true
        defer { updatingModelSettings = false }
        let updated = modelProfiles.filter { $0.id != id }
        try modelStore.save(updated)
        do { try await modelStore.removeSecret(profile.secretReference) }
        catch {
            do { try modelStore.save(modelProfiles) }
            catch {
                modelProfiles = updated
                settingsError = "配置删除后钥匙串清理失败，配置回滚也未成功。请检查磁盘和钥匙串；旧密钥未自动转存。"
            }
            throw error
        }
        modelProfiles = updated
    }

    public func modelConfiguration(profileID: UUID) async throws -> ModelConfiguration {
        guard !updatingModelSettings else { throw SettingsFailure("模型设置正在保存，请稍后重试。") }
        guard let profile = modelProfiles.first(where: { $0.id == profileID }) else { throw SettingsFailure("模型配置不存在，请打开模型设置。") }
        let key = try await modelStore.readSecret(profile.secretReference)
        guard !updatingModelSettings, modelProfiles.first(where: { $0.id == profileID }) == profile else {
            throw SettingsFailure("配置已在读取钥匙串期间改变，请重试。")
        }
        return ModelConfiguration(endpoint: profile.endpoint, model: profile.model, apiKey: key, isTest: profile.isTest,
            imageInputEnabled: profile.imageCapability == .verified, webSearchEnabled: profile.webSearchEnabled == true)
    }

    @discardableResult public func checkModelProfile(id: UUID) async throws -> ModelProfile {
        guard let original = modelProfiles.first(where: { $0.id == id }) else { throw SettingsFailure("模型配置不存在。") }
        let configuration = try await modelConfiguration(profileID: id)
        let directory = storageDirectory.appendingPathComponent("connection-checks/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let probe = TaskService(executable: executable, storageDirectory: directory)
        // Connection checks have no user workspace. Never leave a hidden
        // permission request waiting, or grant it on the user's behalf.
        let observation = probe.$tasks.sink { tasks in
            for task in tasks {
                for question in task.permissions {
                    Task { @MainActor in probe.answerPermission(taskID: task.id, requestID: question.id, allow: false) }
                }
            }
        }
        var timedOut = false
        let deadline = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 90_000_000_000)
                timedOut = true
                probe.shutdown()
            }
            catch { /* Cancelled after the check completed. */ }
        }
        defer { deadline.cancel(); observation.cancel(); probe.shutdown(); try? FileManager.default.removeItem(at: directory) }
        let task = probe.createTask(workspace: directory)
        await probe.send(taskID: task, text: "这是连接检查。请仅回复：连接成功。不要使用工具。", configuration: configuration)
        let textResult = probe.tasks.first
        let hasText = !(textResult?.messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let textVerified = textResult?.status == .completed && hasText
        var toolVerified = false
        if textVerified && !timedOut {
            let token = UUID().uuidString
            let sample = directory.appendingPathComponent("connection-probe.txt")
            try token.write(to: sample, atomically: true, encoding: .utf8)
            await probe.send(taskID: task, text: "请调用 Read 读取 connection-probe.txt，并只回复文件中的验证码。", configuration: configuration)
            let toolResult = probe.tasks.first
            toolVerified = toolResult?.status == .completed
                && toolResult?.sources.contains(where: { $0.file.resolvingSymlinksInPath() == sample.resolvingSymlinksInPath() && $0.excerpt.contains(token) }) == true
                && toolResult?.messages.last?.text.contains(token) == true
        }
        var imageVerified = false
        if textVerified && !timedOut {
            let challenge = try ImageCapabilityProbe.make()
            var imageConfiguration = configuration
            // Only the generated challenge bypasses the unverified capability
            // gate. Normal task configuration derives it from saved results.
            imageConfiguration.imageInputEnabled = true
            let imageTask = probe.createTask(workspace: directory)
            await probe.sendTurn(taskID: imageTask, text: ImageCapabilityProbe.prompt,
                configuration: imageConfiguration, image: challenge.png)
            let imageResult = probe.tasks.first { $0.id == imageTask }
            imageVerified = imageResult?.status == .completed
                && imageResult?.tools.isEmpty == true
                && challenge.matches(imageResult?.messages.last?.text ?? "")
        }
        guard !updatingModelSettings,
              let index = modelProfiles.firstIndex(where: { $0.id == id && $0.secretReference == original.secretReference }) else {
            throw SettingsFailure("配置已在检查期间改变，请重新检查。")
        }
        var checked = modelProfiles[index]
        checked.textCapability = textVerified ? .verified : .unknown
        checked.toolCapability = toolVerified ? .verified : .unknown
        checked.imageCapability = imageVerified ? .verified : .unknown
        checked.checkedAt = Date()
        checked.checkDetails = checked.textCapability == .verified
            ? "真实文本请求已返回。" + (toolVerified ? "已通过真实文件读取与工具结果回传。" : "工具往返未通过，可能不支持或暂时失败，请重试。") + (imageVerified ? "随机图片的颜色顺序核对通过；不代表任意图像均能准确理解。" : "图像检查未通过，可能不支持或暂时失败。请确认模型支持图像后重新检查；不会自动发送用户图片。")
            : textResult?.error ?? "服务没有返回可用文本，请检查模型名称、接口类型或重试。"
        if timedOut { checked.checkDetails = (checked.checkDetails ?? "") + "检查已超时，后续检查未启动；请重试。" }
        var updated = modelProfiles
        updated[index] = checked
        try modelStore.save(updated)
        modelProfiles = updated
        return checked
    }

    public func send(taskID: UUID, text: String, profileID: UUID, onAccepted: (() -> Void)? = nil) async {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if credentialStarts[taskID] != nil {
            tasks[index].controlNotice = "正在读取模型凭据。新增要求仍留在输入框，请等待启动或先停止。"
            return
        }
        if tasks[index].status.isActive, var bound = configurations[taskID] {
            // Refresh the switch without a blocking credential read. A different
            // selected profile must not silently reconfigure an active task.
            if configurationProfileIDs[taskID] == profileID,
               let profile = modelProfiles.first(where: { $0.id == profileID }),
               profile.endpoint == bound.endpoint, profile.model == bound.model,
               profile.isTest == bound.isTest {
                bound.webSearchEnabled = profile.webSearchEnabled == true
            }
            await send(taskID: taskID, text: text, configuration: bound, onAccepted: onAccepted)
            return
        }
        guard !restorations.contains(taskID) else {
            tasks[index].error = "正在恢复文件，请等待恢复结束后发送要求。"
            return
        }
        do { try historyStore.claim(taskID) }
        catch {
            tasks[index].error = (error as? SettingsFailure)?.message ?? "无法取得任务历史的使用权，请稍后重试。"
            return
        }
        let previousStatus = tasks[index].status
        let startID = UUID()
        credentialStarts[taskID] = startID
        tasks[index].status = .preparing
        tasks[index].error = nil
        tasks[index].controlNotice = "正在读取模型凭据；若系统弹出钥匙串提示，请在系统窗口中处理。可停止本次启动。"
        defer { persistHistory() }
        do {
            let configuration = try await modelConfiguration(profileID: profileID)
            // Stop, shutdown or a newer start can invalidate this request while
            // macOS is waiting for the user. A late credential must not run it.
            guard credentialStarts[taskID] == startID,
                  let current = tasks.firstIndex(where: { $0.id == taskID }) else { return }
            credentialStarts[taskID] = nil
            tasks[current].status = previousStatus
            tasks[current].controlNotice = nil
            configurationProfileIDs[taskID] = profileID
            await send(taskID: taskID, text: text, configuration: configuration, onAccepted: onAccepted)
        } catch {
            guard credentialStarts[taskID] == startID,
                  let current = tasks.firstIndex(where: { $0.id == taskID }) else { return }
            credentialStarts[taskID] = nil
            tasks[current].status = .failed
            tasks[current].controlNotice = nil
            tasks[current].error = error.localizedDescription
        }
    }
    @discardableResult public func createTask(workspace: URL) -> UUID {
        let canonical = workspace.resolvingSymlinksInPath()
        let task = DesktopTask(workspace: canonical, workspaceIdentity: workspaceIdentity(canonical))
        do { try historyStore.claim(task.id) }
        catch { historyError = "无法保存新任务，请检查历史目录权限后重试。" }
        tasks.insert(task, at: 0)
        persistHistory()
        return task.id
    }

    public func send(taskID: UUID, text: String, configuration: ModelConfiguration, onAccepted: (() -> Void)? = nil) async {
        await sendTurn(taskID: taskID, text: text, configuration: configuration, onAccepted: onAccepted)
    }

    private func sendTurn(taskID: UUID, text: String, configuration: ModelConfiguration,
        image: Data? = nil, onAccepted: (() -> Void)? = nil) async {
        guard credentialStarts[taskID] == nil else { return }
        guard let index = tasks.firstIndex(where: { $0.id == taskID }),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !restorations.contains(taskID) else {
            tasks[index].error = "正在恢复文件，请等待恢复结束后发送要求。"
            return
        }
        do { try historyStore.claim(taskID) }
        catch {
            historyError = (error as? SettingsFailure)?.message ?? "无法取得任务历史的使用权，请检查历史目录权限后重试。"
            tasks[index].error = historyError
            return
        }
        defer { persistHistory() }
        if tasks[index].requiresHistoryRecovery || (sessions[taskID] != nil && clients[taskID]?.closed != false) {
            tasks[index].requiresHistoryRecovery = true
            clients.removeValue(forKey: taskID)?.close()
            sessions[taskID] = nil
        }
        if (configurations[taskID].map { !$0.usesSameService(as: configuration) } ?? false)
            || (tasks[index].modelName.map { $0 != configuration.model } ?? false)
            || (tasks[index].endpoint.map { $0 != configuration.endpoint } ?? false) {
            if !tasks[index].status.isActive { tasks[index].status = .failed }
            tasks[index].error = "此任务绑定原模型服务。请新建任务以使用修改后的配置，或恢复原配置后继续。"
            return
        }
        if tasks[index].status.isActive {
            let previous = tasks[index]
            tasks[index].requirements.append(TaskRequirement(text: redact(text, secret: configuration.apiKey)))
            guard persistHistory() else { tasks[index] = previous; return }
            if tasks[index].status != .stopping { continueWithRequirements.insert(taskID) }
            if continueWithRequirements.contains(taskID) { continuationConfigurations[taskID] = configuration }
            onAccepted?()
            cancelCurrentTurn(taskID: taskID)
            return
        }
        if let bound = configurations[taskID],
           bound.imageInputEnabled != configuration.imageInputEnabled || bound.webSearchEnabled != configuration.webSearchEnabled,
           sessions[taskID] != nil {
            // A capability recheck does not change the service identity. Restore
            // visible history in a fresh runtime so both enabling and revoking
            // image input or search take effect without replaying tool actions.
            tasks[index].requiresHistoryRecovery = true
            clients.removeValue(forKey: taskID)?.close()
            sessions[taskID] = nil
        }
        guard let identity = workspaceIdentity(tasks[index].workspace), identity == tasks[index].workspaceIdentity else {
            tasks[index].status = .failed
            tasks[index].error = "工作文件夹已不存在、被替换或无法访问。请恢复原文件夹后重试，或重新选择文件夹新建任务；历史与成果记录仍保留。"
            return
        }
        let previous = tasks[index]
        let recovery = tasks[index].requiresHistoryRecovery ? tasks[index] : nil
        let pendingRequirements = tasks[index].requirements.filter { $0.state == .received }
        let prompt = (pendingRequirements.map(\.text) + [text]).joined(separator: "\n\n")
        configurations[taskID] = configuration
        tasks[index].modelName = configuration.model
        tasks[index].endpoint = configuration.endpoint
        let workspacePath = tasks[index].workspace.path
        let runID = UUID()
        runs[taskID] = runID
        tasks[index].status = .running
        tasks[index].error = nil
        tasks[index].controlNotice = nil
        tasks[index].isTest = configuration.isTest
        if tasks[index].messages.isEmpty { tasks[index].title = String(redact(text, secret: configuration.apiKey).prefix(32)) }
        tasks[index].messages.append(ChatMessage(role: "user", text: redact(prompt, secret: configuration.apiKey)))
        tasks[index].messages.append(ChatMessage(role: "assistant", text: ""))
        guard persistHistory() else {
            tasks[index] = previous
            tasks[index].status = .failed
            tasks[index].error = historyError
            return
        }
        onAccepted?()
        var promptAttempted = false
        do {
            guard tasks[index].status != .stopping else { throw ServiceError("启动已取消") }
            let client: ACPProcess
            let session: String
            if let existing = clients[taskID], let existingSession = sessions[taskID] {
                client = existing; session = existingSession
            } else {
                client = try ACPProcess(executable: executable, secret: configuration.apiKey,
                    runtimeDirectory: storageDirectory.appendingPathComponent("runtime/" + taskID.uuidString))
                clients[taskID] = client
                _ = try await client.request("desktop/configure", [
                    "cwd": workspacePath, "endpoint": configuration.endpoint,
                    "model": configuration.model, "apiKey": configuration.apiKey,
                    "imageInputEnabled": configuration.imageInputEnabled,
                    "webSearchEnabled": configuration.webSearchEnabled
                ])
                _ = try await client.request("initialize", ["protocolVersion": 1, "clientCapabilities": [String: String]()])
                let response = try await client.request("session/new", ["cwd": workspacePath, "mcpServers": [String]()])
                guard let newSession = response["sessionId"] as? String else { throw ServiceError("Claurst 未返回任务标识") }
                session = newSession
                sessions[taskID] = session
                if let recovery {
                    let history = try JSONEncoder().encode(recovery)
                    guard let historyText = String(data: history, encoding: .utf8) else { throw ServiceError("历史无法编码，请检查历史文件。") }
                    _ = try await client.request("desktop/restore", ["sessionId": session, "history": historyText])
                    guard let i = tasks.firstIndex(where: { $0.id == taskID }), runs[taskID] == runID else { return }
                    tasks[i].requiresHistoryRecovery = false
                    tasks[i].controlNotice = "已基于可见历史恢复。未重放旧工具操作；当前文件和越界访问会重新检查。"
                }
            }
            client.onPermissionRequest = { [weak self, weak client] requestID, params in
                guard let self, self.runs[taskID] == runID,
                      params["sessionId"] as? String == session,
                      let i = self.tasks.firstIndex(where: { $0.id == taskID }), self.tasks[i].status.isActive, self.tasks[i].status != .stopping,
                      let tool = params["toolCall"] as? [String: Any],
                      let title = tool["title"] as? String else {
                    try? client?.answerPermission(requestID, allow: false); return
                }
                self.tasks[i].permissions.append(PermissionQuestion(id: requestID, description: redact(title, secret: configuration.apiKey)))
                self.tasks[i].status = .waiting
            }
            client.onQuestionRequest = { [weak self, weak client] requestID, params in
                guard let self, self.runs[taskID] == runID,
                      params["sessionId"] as? String == session,
                      let i = self.tasks.firstIndex(where: { $0.id == taskID }), self.tasks[i].status.isActive, self.tasks[i].status != .stopping,
                      let question = params["question"] as? String else {
                    try? client?.answerQuestion(requestID, text: nil); return
                }
                self.tasks[i].questions.append(UserQuestion(id: requestID, question: redact(question, secret: configuration.apiKey),
                    options: (params["options"] as? [String] ?? []).map { redact($0, secret: configuration.apiKey) }))
                self.tasks[i].status = .answering
            }
            var responseText = ""
            client.onNotification = { [weak self] method, params in
                guard let self, self.runs[taskID] == runID,
                      params["sessionId"] as? String == session,
                      let i = self.tasks.firstIndex(where: { $0.id == taskID }) else { return }
                if method == "desktop/prompt_started" {
                    for requirement in pendingRequirements {
                        if let index = self.tasks[i].requirements.firstIndex(where: { $0.id == requirement.id }) {
                            self.tasks[i].requirements[index].state = .applied
                        }
                    }
                    return
                }
                guard method == "session/update", let update = params["update"] as? [String: Any] else { return }
                if update["sessionUpdate"] as? String == "agent_message_chunk",
                   let content = update["content"] as? [String: Any], let chunk = content["text"] as? String,
                   let last = self.tasks[i].messages.indices.last {
                    responseText += chunk
                    self.tasks[i].messages[last].text = redactStream(responseText, secret: configuration.apiKey)
                } else { self.receiveTool(update, taskIndex: i, runID: runID, secret: configuration.apiKey) }
            }
            guard let current = tasks.first(where: { $0.id == taskID }), current.status != .stopping else {
                throw ServiceError("启动已取消")
            }
            promptAttempted = true
            var blocks = [["type": "text", "text": prompt]]
            if let image {
                guard configuration.imageInputEnabled, image.count <= 256 * 1024 else { throw ServiceError("图像检查样本无效或未启用。") }
                blocks.append(["type": "image", "mimeType": "image/png", "data": image.base64EncodedString()])
            }
            let result = try await client.request("session/prompt", ["sessionId": session, "prompt": blocks])
            guard runs[taskID] == runID, let i = tasks.firstIndex(where: { $0.id == taskID }) else { return }
            tasks[i].permissions.removeAll()
            client.rejectPermissions()
            client.cancelQuestions()
            for index in tasks[i].questions.indices { tasks[i].questions[index].isPending = false }
            if let last = tasks[i].messages.indices.last {
                tasks[i].messages[last].text = redactStream(responseText, secret: configuration.apiKey, final: true)
            }
            switch tasks[i].status == .stopping ? "cancelled" : result["stopReason"] as? String {
            case "end_turn":
                let hadFailure = tasks[i].tools.contains { $0.id.hasPrefix(runID.uuidString + ":") && $0.status == "失败" }
                if hadFailure || tasks[i].error != nil {
                    tasks[i].status = .failed
                    if tasks[i].error == nil { tasks[i].error = "有工具操作未完成，请查看执行记录；已成功执行的操作会保留。" }
                } else { tasks[i].status = .completed }
            case "cancelled":
                tasks[i].status = .stopped
                tasks[i].controlNotice = "已停止。已完成的文件修改会保留；停止不会撤销。可补充要求后继续。"
            default: tasks[i].status = .failed; tasks[i].error = "执行达到限制，尚未完成。可补充要求后继续。"
            }
        } catch {
            guard runs[taskID] == runID, let i = tasks.firstIndex(where: { $0.id == taskID }) else { return }
            let stopping = tasks[i].status == .stopping
            tasks[i].status = stopping ? .stopped : .failed
            tasks[i].permissions.removeAll()
            for index in tasks[i].questions.indices { tasks[i].questions[index].isPending = false }
            if stopping { tasks[i].controlNotice = "连接已结束。已完成的文件修改会保留；停止不会撤销。可补充要求后继续。" }
            tasks[i].error = stopping ? nil : redact(error.localizedDescription, secret: configuration.apiKey)
            clients[taskID]?.rejectPermissions()
            clients[taskID]?.cancelQuestions()
            // Query errors leave the runtime and its transcript usable. Only
            // discard a disconnected client or an incomplete startup.
            if clients[taskID]?.closed != false || sessions[taskID] == nil {
                if promptAttempted {
                    tasks[i].requiresHistoryRecovery = true
                    tasks[i].error = "运行时连接中断。历史和已完成修改仍保留，可发送要求后基于历史继续；中断操作的结果需重新核对。"
                    tasks[i].controlNotice = "停止不会撤销已完成的修改。"
                }
                clients.removeValue(forKey: taskID)?.close()
                sessions[taskID] = nil
            }
        }
        if runs[taskID] == runID, let i = tasks.firstIndex(where: { $0.id == taskID }) {
            var missingResult = false
            for index in tasks[i].tools.indices where tasks[i].tools[index].id.hasPrefix(runID.uuidString + ":") && tasks[i].tools[index].status == "执行中" {
                tasks[i].tools[index].status = "结果未确认"
                if tasks[i].tools[index].check != nil { tasks[i].tools[index].check?.state = .unconfirmed }
                missingResult = true
            }
            if missingResult && tasks[i].status == .completed {
                tasks[i].status = .failed
                tasks[i].error = "部分工具没有返回结果，请核对执行记录和已有成果后继续。"
            }
        }
        let continuationConfiguration = continuationConfigurations.removeValue(forKey: taskID) ?? configuration
        if continueWithRequirements.remove(taskID) != nil,
           let task = tasks.first(where: { $0.id == taskID }), task.status == .stopped,
           task.requirements.contains(where: { $0.state == .received }) {
            await send(taskID: taskID, text: "请按以上补充要求继续；保留已经完成的修改，不要重复执行。", configuration: continuationConfiguration)
        }
    }

    public func stop(taskID: UUID) {
        continueWithRequirements.remove(taskID)
        continuationConfigurations[taskID] = nil
        if credentialStarts.removeValue(forKey: taskID) != nil,
           let index = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[index].status = .stopped
            tasks[index].controlNotice = "已取消启动，任务要求仍留在输入框。系统授权提示可能仍需处理，但本次任务不会随后执行。"
            persistHistory()
            return
        }
        cancelCurrentTurn(taskID: taskID)
    }

    /// Local file recovery uses ACP without loading model credentials or sending a prompt.
    @discardableResult public func restoreChange(taskID: UUID, changeID: String) async -> Bool {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }), !tasks[i].status.isActive,
              let c = tasks[i].changes.firstIndex(where: { $0.id == changeID }),
              tasks[i].changes[c].restoredAt == nil else { return false }
        let previousStatus = tasks[i].status
        let runID = UUID()
        let workspacePath = tasks[i].workspace.path
        var restored = false
        var failure: String?
        var started = false
        do {
            try historyStore.claim(taskID)
            guard let identity = workspaceIdentity(tasks[i].workspace), identity == tasks[i].workspaceIdentity else {
                throw ServiceError("工作文件夹已不存在或被替换，请恢复原文件夹后重试。")
            }
            guard UUID(uuidString: changeID) != nil else { throw ServiceError("修改记录编号无效") }
            guard persistHistory() else { throw ServiceError(historyError ?? "无法保存任务历史") }
            clients.removeValue(forKey: taskID)?.close(); sessions[taskID] = nil
            tasks[i].requiresHistoryRecovery = true
            restorations.insert(taskID); runs[taskID] = runID
            started = true
            tasks[i].status = .running; tasks[i].changes[c].restoreError = nil
            tasks[i].controlNotice = "正在检查文件并恢复；发生内容或路径冲突时会保留当前文件。"
            let client = try ACPProcess(executable: executable, secret: "",
                runtimeDirectory: storageDirectory.appendingPathComponent("runtime/" + taskID.uuidString))
            clients[taskID] = client
            defer {
                client.close()
                if runs[taskID] == runID { clients[taskID] = nil }
            }
            client.onPermissionRequest = { [weak self, weak client] requestID, params in
                guard let self, self.runs[taskID] == runID,
                      let index = self.tasks.firstIndex(where: { $0.id == taskID }),
                      self.tasks[index].status != .stopping,
                      let tool = params["toolCall"] as? [String: Any], let title = tool["title"] as? String else {
                    try? client?.answerPermission(requestID, allow: false); return
                }
                self.tasks[index].permissions.append(PermissionQuestion(id: requestID, description: title))
                self.tasks[index].status = .waiting
            }
            let result = try await client.request("desktop/restore_file", ["cwd": workspacePath, "changeId": changeID])
            guard result["restored"] as? Bool == true else { throw ServiceError("恢复结果未确认，请核对当前文件；恢复材料仍保留。") }
            restored = true
        } catch { failure = error.localizedDescription }
        guard !started || runs[taskID] == runID,
              let index = tasks.firstIndex(where: { $0.id == taskID }),
              let change = tasks[index].changes.firstIndex(where: { $0.id == changeID }) else { return false }
        if restored {
            tasks[index].changes[change].restoredAt = Date()
            tasks[index].messages.append(ChatMessage(role: "user", text: "已从文件修改记录恢复：" + tasks[index].changes[change].file.path + "。后续执行须重新核对当前文件。"))
            tasks[index].controlNotice = "已恢复本次文件修改。原始差异与恢复材料仍保留。"
            tasks[index].error = nil
        } else {
            tasks[index].changes[change].restoreError = (failure ?? "恢复结果未确认") + "\n恢复材料：" + tasks[index].changes[change].record.path
            tasks[index].controlNotice = "未确认恢复成功，请查看文件修改记录中的原因。"
        }
        tasks[index].status = previousStatus
        tasks[index].permissions.removeAll()
        restorations.remove(taskID); runs[taskID] = nil
        persistHistory()
        return restored
    }

    private func cancelCurrentTurn(taskID: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }), tasks[i].status.isActive, tasks[i].status != .stopping else { return }
        tasks[i].status = .stopping
        tasks[i].controlNotice = "正在停止，等待已启动操作结束。已完成的文件修改会保留；停止不会撤销。"
        guard let session = sessions[taskID], let client = clients[taskID] else {
            clients.removeValue(forKey: taskID)?.close()
            return
        }
        do { try client.notify("session/cancel", ["sessionId": session]) }
        catch { client.close() }
        client.rejectPermissions()
        client.cancelQuestions()
        tasks[i].permissions.removeAll()
        for index in tasks[i].questions.indices { tasks[i].questions[index].isPending = false }
    }

    public func answerQuestion(taskID: UUID, requestID: UUID, text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let i = tasks.firstIndex(where: { $0.id == taskID }), tasks[i].status != .stopping,
              let q = tasks[i].questions.firstIndex(where: { $0.id == requestID && $0.isPending }),
              let client = clients[taskID] else { return }
        do {
            try client.answerQuestion(requestID, text: text)
            tasks[i].questions[q].answer = redact(text, secret: configurations[taskID]?.apiKey ?? "")
            tasks[i].questions[q].isPending = false
            if !tasks[i].questions.contains(where: { $0.isPending }) {
                tasks[i].status = tasks[i].permissions.isEmpty ? .running : .waiting
            }
        } catch { client.close(); tasks[i].error = "回答未能送达，请在连接恢复后重新回答。" }
    }

    public func answerPermission(taskID: UUID, requestID: UUID, allow: Bool) {
        guard let i = tasks.firstIndex(where: { $0.id == taskID }),
              tasks[i].permissions.contains(where: { $0.id == requestID }), let client = clients[taskID] else { return }
        do {
            try client.answerPermission(requestID, allow: allow)
            tasks[i].permissions.removeAll { $0.id == requestID }
            if tasks[i].permissions.isEmpty { tasks[i].status = tasks[i].questions.contains(where: { $0.isPending }) ? .answering : .running }
        } catch { client.close(); tasks[i].permissions.removeAll(); tasks[i].status = .failed; tasks[i].error = "授权答复未能送达，连接已关闭，请重试。" }
    }

    private func receiveTool(_ update: [String: Any], taskIndex i: Int, runID: UUID, secret: String) {
        defer { persistHistory() }
        guard let callID = update["toolCallId"] as? String else { return }
        let id = runID.uuidString + ":" + callID
        if update["sessionUpdate"] as? String == "tool_call" {
            let input = update["rawInput"] as? [String: Any]
            let checkName = input?["check_name"] as? String
            let projectCheck = update["kind"] as? String == "execute" && checkName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? ProjectCheck(name: redact(checkName ?? "", secret: secret), state: .running) : nil
            tasks[i].tools.append(ToolExecution(id: id, title: redact(update["title"] as? String ?? "工具", secret: secret), status: "执行中", check: projectCheck))
        } else if update["sessionUpdate"] as? String == "tool_call_update",
                  let index = tasks[i].tools.firstIndex(where: { $0.id == id }) {
            let completed = update["status"] as? String == "completed"
            tasks[i].tools[index].status = completed ? "完成" : "失败"
            if tasks[i].tools[index].check != nil {
                let raw = update["rawOutput"] as? [String: Any]
                let receipt = raw?["command_check"] as? [String: Any]
                let state = (receipt?["state"] as? String).flatMap(ProjectCheckState.init(rawValue:))
                tasks[i].tools[index].check?.state = state == .passed && !completed ? .unconfirmed : (state ?? .unconfirmed)
            }
            if completed, let raw = update["rawOutput"] as? [String: Any], raw["latex_artifact"] != nil {
                do {
                    let data = try JSONSerialization.data(withJSONObject: raw["latex_artifact"] as Any)
                    var artifact = try JSONDecoder().decode(LaTeXArtifact.self, from: data)
                    guard artifact.isValid(in: tasks[i].workspace), secret.isEmpty ||
                            ![artifact.mainPath, artifact.pdfPath, artifact.logPath].contains(where: { $0.contains(secret) }) else {
                        throw ServiceError("LaTeX 成果位置无效")
                    }
                    artifact.warnings = artifact.reviewNotes.map { redact($0, secret: secret) }
                    if !tasks[i].latexArtifacts.contains(where: { $0.id == artifact.id }) { tasks[i].latexArtifacts.append(artifact) }
                    tasks[i].tools[index].output = redact(raw["content"] as? String ?? "PDF 已生成；页面布局与引用仍需核对。", secret: secret)
                } catch {
                    tasks[i].tools[index].status = "失败"
                    tasks[i].tools[index].output = "编译工具返回的成果记录无效，未加入成果。请重试。"
                    tasks[i].error = tasks[i].tools[index].output
                }
            } else if completed, let raw = update["rawOutput"] as? [String: Any], raw["web_source"] != nil {
                do {
                    let data = try JSONSerialization.data(withJSONObject: raw["web_source"] as Any)
                    let source = try JSONDecoder().decode(WebSource.self, from: data).redacting(secret: secret)
                    guard source.isValid else { throw ServiceError("网页来源位置无效") }
                    if !tasks[i].webSources.contains(where: { $0.id == source.id }) { tasks[i].webSources.append(source) }
                    tasks[i].tools[index].output = redact(raw["content"] as? String ?? source.excerpt, secret: secret)
                } catch {
                    tasks[i].tools[index].status = "失败"
                    tasks[i].tools[index].output = "网页工具返回的来源记录无效，未加入已读来源。请重试。"
                    tasks[i].error = tasks[i].tools[index].output
                }
            } else if let raw = update["rawOutput"] as? [String: Any],
               let content = raw["content"] as? String, let source = raw["source"] as? [String: Any],
               let path = source["path"] as? String, path.hasPrefix("/"),
               let first = source["first_line"] as? Int, let last = source["last_line"] as? Int, completed {
                let excerpt = redact(content, secret: secret)
                tasks[i].sources.append(FileSource(file: URL(fileURLWithPath: path), firstLine: first, lastLine: last, excerpt: excerpt))
                tasks[i].tools[index].output = excerpt
            } else if completed, let raw = update["rawOutput"] as? [String: Any],
                      let content = raw["content"] as? String, let source = raw["source"] as? [String: Any],
                      let path = source["path"] as? String, path.hasPrefix("/"),
                      let locator = source["locator"] as? [String: Any],
                      let unit = (locator["unit"] as? String).flatMap(DocumentLocation.Unit.init(rawValue:)),
                      let first = locator["first"] as? Int, let last = locator["last"] as? Int,
                      let total = locator["total"] as? Int, first > 0, last >= first, total >= last {
                let excerpt = redact(content, secret: secret)
                tasks[i].sources.append(FileSource(file: URL(fileURLWithPath: path), firstLine: 0, lastLine: 0, excerpt: excerpt,
                    documentLocation: DocumentLocation(unit: unit, first: first, last: last, total: total,
                        recognition: locator["recognition"] as? Bool, visual: locator["visual"] as? Bool)))
                tasks[i].tools[index].output = excerpt
            } else if completed, let raw = update["rawOutput"] as? [String: Any],
                      let content = raw["content"] as? String, let source = raw["source"] as? [String: Any],
                      let path = source["path"] as? String, path.hasPrefix("/"),
                      let table = source["table"] as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: table),
                      let location = try? JSONDecoder().decode(TableLocation.self, from: data),
                      location.first_row > 0, location.last_row >= location.first_row,
                      location.total_rows >= location.last_row, location.first_column > 0,
                      location.last_column >= location.first_column {
                let excerpt = redact(content, secret: secret)
                tasks[i].sources.append(FileSource(file: URL(fileURLWithPath: path), firstLine: 0, lastLine: 0, excerpt: excerpt, tableLocation: location))
                tasks[i].tools[index].output = excerpt
            } else if completed, let raw = update["rawOutput"] as? [String: Any],
                      let change = raw["change"] as? [String: Any],
                      let changeID = change["id"] as? String, UUID(uuidString: changeID) != nil,
                      let path = change["path"] as? String, path.hasPrefix("/"),
                      let recordPath = change["record_path"] as? String {
                let expected = storageDirectory.appendingPathComponent("runtime/" + tasks[i].id.uuidString + "/changes/" + changeID + ".json")
                let recordURL = URL(fileURLWithPath: recordPath)
                do {
                    guard recordURL.standardizedFileURL == expected.standardizedFileURL else { throw ServiceError("修改记录不在当前任务存储目录") }
                    let record = try JSONDecoder().decode(FileChangeRecord.self, from: Data(contentsOf: recordURL))
                    guard record.id == changeID, record.path == path else { throw ServiceError("修改记录与实际工具结果不一致") }
                    let summary: String
                    switch record.operation {
                    case "move": summary = "移动文件"
                    case "delete": summary = "删除文件"
                    default: summary = record.before == nil ? "创建文件" : "修改文件"
                    }
                    if !tasks[i].changes.contains(where: { $0.id == changeID }) {
                        tasks[i].changes.append(FileChange(id: changeID, file: URL(fileURLWithPath: path), summary: summary,
                            diff: redact(record.diff, secret: secret), before: record.before.map { redact($0, secret: secret) },
                            after: redact(record.after, secret: secret), record: recordURL,
                            originalFile: record.original_path.map { URL(fileURLWithPath: $0) },
                            reason: record.reason.map { redact($0, secret: secret) }))
                    }
                    tasks[i].tools[index].output = redact(raw["content"] as? String ?? summary, secret: secret)
                } catch {
                    tasks[i].tools[index].output = "文件工具报告写入完成，但无法加载差异：" + redact(error.localizedDescription, secret: secret)
                    tasks[i].error = tasks[i].tools[index].output
                }
            } else if let raw = update["rawOutput"] as? [String: Any], let content = raw["content"] as? String {
                tasks[i].tools[index].output = redact(content, secret: secret)
            } else {
                tasks[i].tools[index].output = redact(update["rawOutput"] as? String ?? "", secret: secret)
            }
        }
    }
    public func shutdown() {
        runs.removeAll(); continueWithRequirements.removeAll(); restorations.removeAll(); credentialStarts.removeAll()
        continuationConfigurations.removeAll(); configurationProfileIDs.removeAll()
        for index in tasks.indices {
            if sessions[tasks[index].id] != nil { tasks[index].requiresHistoryRecovery = true }
            if tasks[index].status.isActive {
                tasks[index].status = .stopped
                tasks[index].controlNotice = "应用已结束本次执行。已完成修改仍保留，重新打开后可基于历史继续。"
            }
            tasks[index].permissions.removeAll()
            for tool in tasks[index].tools.indices where tasks[index].tools[tool].status == "执行中" {
                tasks[index].tools[tool].status = "已中断，结果待核对"
                if tasks[index].tools[tool].check != nil { tasks[index].tools[tool].check?.state = .unconfirmed }
            }
            for q in tasks[index].questions.indices { tasks[index].questions[q].isPending = false }
        }
        for client in clients.values { client.close() }
        clients.removeAll(); sessions.removeAll()
        persistHistory()
        historyStore.releaseTasks()
    }
}

private func workspaceIdentity(_ url: URL) -> String? {
    guard url.resolvingSymlinksInPath().standardizedFileURL == url.standardizedFileURL,
          let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          attributes[.type] as? FileAttributeType == .typeDirectory,
          let device = attributes[.systemNumber] as? NSNumber,
          let inode = attributes[.systemFileNumber] as? NSNumber else { return nil }
    return "\(device):\(inode)"
}

private struct ServiceError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
private func redact(_ text: String, secret: String) -> String {
    secret.isEmpty ? text : text.replacingOccurrences(of: secret, with: "[密钥已隐藏]")
}

/// Hold a suffix that could become a secret on the next streaming chunk.
private func redactStream(_ text: String, secret: String, final: Bool = false) -> String {
    guard !secret.isEmpty else { return text }
    let sanitized = redact(text, secret: secret)
    let limit = min(secret.count - 1, sanitized.count)
    guard limit > 0 else { return sanitized }
    for length in stride(from: limit, through: 1, by: -1) {
        if sanitized.hasSuffix(String(secret.prefix(length))) {
            // A short terminal overlap (e.g. the last letter of a normal word)
            // is not evidence of a credential. Longer fragments remain hidden.
            if final && length < min(4, secret.count - 1) { return sanitized }
            return String(sanitized.dropLast(length)) + (final ? "[密钥片段已隐藏]" : "")
        }
    }
    return sanitized
}

/// One task owns one process. Only newline-delimited ACP crosses this boundary.
@MainActor private final class ACPProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let secret: String
    private var incomingBytes: AsyncStream<Data>.Continuation?
    private var reader: Task<Void, Never>?
    private var buffer = Data()
    private var searchedBytes = 0
    private var sequence = 0
    private var methods: [Int: String] = [:]
    private var pending: [Int: CheckedContinuation<[String: Any], Error>] = [:]
    private(set) var closed = false
    private var inboundPermissions: [UUID: Any] = [:]
    private var inboundQuestions: [UUID: Any] = [:]
    var onNotification: ((String, [String: Any]) -> Void)?
    var onPermissionRequest: ((UUID, [String: Any]) -> Void)?
    var onQuestionRequest: ((UUID, [String: Any]) -> Void)?

    init(executable: URL, secret: String, runtimeDirectory: URL) throws {
        self.secret = secret
        process.executableURL = executable
        // No ambient model credentials, shell hooks or inherited provider overrides.
        try FileManager.default.createDirectory(at: runtimeDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8", "CLAURST_HOME": runtimeDirectory.path]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let bytes = AsyncStream<Data> { incomingBytes = $0 }
        let continuation = incomingBytes
        output.fileHandleForReading.readabilityHandler = { handle in
            continuation?.yield(handle.availableData)
        }
        // Independent MainActor tasks are not FIFO. One consumer preserves the
        // pipe's byte order, including UTF-8 split across large tool messages.
        reader = Task { [weak self] in
            for await chunk in bytes {
                guard !Task.isCancelled else { break }
                self?.receive(chunk)
            }
        }
        // EOF travels through the same consumer. A separate termination task
        // could close the connection before already-written output is drained.
    }

    func request(_ method: String, _ params: [String: Any]) async throws -> [String: Any] {
        guard !closed else { throw ServiceError("Claurst 连接已关闭") }
        sequence += 1
        let id = sequence
        methods[id] = method
        return try await withCheckedThrowingContinuation { continuation in
            register(id, continuation)
            do { try write(["jsonrpc": "2.0", "id": id, "method": method, "params": params]) }
            catch { pending.removeValue(forKey: id)?.resume(throwing: error) }
        }
    }
    private func register(_ id: Int, _ continuation: CheckedContinuation<[String: Any], Error>) {
        pending[id] = continuation
    }
    func notify(_ method: String, _ params: [String: Any]) throws {
        try write(["jsonrpc": "2.0", "method": method, "params": params])
    }
    func answerPermission(_ requestID: UUID, allow: Bool) throws {
        guard let id = inboundPermissions.removeValue(forKey: requestID) else { return }
        try write(["jsonrpc": "2.0", "id": id, "result": ["outcome": ["outcome": "selected", "optionId": allow ? "allow_once" : "reject_once"]]])
    }
    func rejectPermissions() {
        for id in Array(inboundPermissions.keys) { try? answerPermission(id, allow: false) }
    }
    func answerQuestion(_ requestID: UUID, text: String?) throws {
        guard let id = inboundQuestions.removeValue(forKey: requestID) else { return }
        try write(["jsonrpc": "2.0", "id": id, "result": ["answer": text.map { $0 as Any } ?? NSNull()]])
    }
    func cancelQuestions() {
        for id in Array(inboundQuestions.keys) { try? answerQuestion(id, text: nil) }
    }
    private func write(_ object: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
    }
    private func receive(_ bytes: Data) {
        guard !closed else { return }
        if bytes.isEmpty { fail(ServiceError("Claurst 连接中断，请重试。")); return }
        buffer.append(bytes)
        // Scan only new bytes when a large JSON line arrives in many chunks.
        // Re-scanning the whole prefix on every chunk blocks the UI quadratically.
        var search = buffer.index(buffer.startIndex, offsetBy: searchedBytes)
        while let end = buffer[search...].firstIndex(of: 10) {
            let line = buffer[..<end]
            buffer.removeSubrange(...end)
            search = buffer.startIndex
            do {
                guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any] else { throw ServiceError("Claurst 返回了无效消息") }
                if let method = object["method"] as? String, let params = object["params"] as? [String: Any] {
                    if let id = object["id"] {
                        if method == "session/request_permission", let onPermissionRequest,
                           let options = params["options"] as? [[String: Any]],
                           options.contains(where: { $0["optionId"] as? String == "allow_once" }) {
                            let requestID = UUID()
                            inboundPermissions[requestID] = id
                            onPermissionRequest(requestID, params)
                        } else if method == "desktop/request_question", let onQuestionRequest {
                            let requestID = UUID()
                            inboundQuestions[requestID] = id
                            onQuestionRequest(requestID, params)
                        } else {
                            try write(["jsonrpc": "2.0", "id": id, "result": ["outcome": ["outcome": "cancelled"]]])
                        }
                    } else {
                        // The task service redacts the accumulated text, so secrets
                        // split across JSON/SSE chunks never reach published state.
                        onNotification?(method, params)
                    }
                } else if let id = object["id"] as? Int, let continuation = pending.removeValue(forKey: id) {
                    if let error = object["error"] as? [String: Any] {
                        continuation.resume(throwing: ServiceError(redact("\(methods.removeValue(forKey: id) ?? "请求"): \(error["message"] as? String ?? "Claurst 执行失败") \(error["data"] ?? "")", secret: secret)))
                    } else { methods.removeValue(forKey: id); continuation.resume(returning: object["result"] as? [String: Any] ?? [:]) }
                }
            } catch { fail(error); return }
        }
        searchedBytes = buffer.count
    }
    private func fail(_ error: Error) {
        let waiting = pending.values
        pending.removeAll()
        for continuation in waiting { continuation.resume(throwing: error) }
        close()
    }
    func close() {
        guard !closed else { return }
        closed = true
        inboundPermissions.removeAll()
        inboundQuestions.removeAll()
        output.fileHandleForReading.readabilityHandler = nil
        incomingBytes?.finish(); incomingBytes = nil
        reader?.cancel(); reader = nil
        // The bundled desktop runtime cancels and joins its handlers on EOF,
        // cleaning up child processes and incomplete output directories. An
        // immediate SIGTERM here would bypass that cleanup during app exit.
        try? input.fileHandleForWriting.close()
        let waiting = pending.values
        pending.removeAll()
        for continuation in waiting { continuation.resume(throwing: ServiceError("Claurst 连接已关闭")) }
    }
}
