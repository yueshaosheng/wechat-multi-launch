import SwiftUI
import AppKit

enum IconMode: String, CaseIterable, Identifiable {
    case rotate, style, none
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var runner = ScriptRunner()
    @State private var language = 1
    @State private var total = 4
    @State private var iconMode: IconMode = .rotate
    @State private var selectedStyle = 1
    @State private var order: [Int] = [1, 2, 3]
    @State private var sourceVersion: String?
    @State private var sourceExists = false

    private let styles = ["flat", "classic", "minimal", "blue", "purple", "dark", "gradient"]

    private func t(_ cn: String, _ en: String) -> String { language == 2 ? en : cn }

    private var iconChoice: String {
        switch iconMode {
        case .rotate:
            return order == defaultOrder() ? "a" : "o:" + order.map(String.init).joined(separator: ",")
        case .none: return "n"
        case .style: return "\(selectedStyle)"
        }
    }

    private func defaultOrder() -> [Int] { (2...total).map { (($0 - 2) % styles.count) + 1 } }

    private func syncOrder() {
        let target = total - 1
        if order.count < target {
            order.append(contentsOf: defaultOrder()[order.count..<target])
        } else if order.count > target {
            order.removeLast(order.count - target)
        }
    }

    private var running: Bool { runner.state == .running }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            settings
            iconSection
            actionArea
            resultBanner
            logSection
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { detectSource(); order = defaultOrder() }
        .onChange(of: total) { _ in syncOrder() }
        .onChange(of: iconMode) { mode in if mode == .rotate { order = defaultOrder() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                Text(t("微信多开", "WeChat Multi Launch"))
                    .font(.title.bold())
            }
            HStack(spacing: 6) {
                Image(systemName: sourceExists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(sourceExists ? .green : .orange)
                Text(sourceExists
                     ? t("已检测到原版微信 \(sourceVersion ?? "")", "Original WeChat \(sourceVersion ?? "") detected")
                     : t("未找到 /Applications/WeChat.app，请先安装原版微信",
                         "WeChat.app not found in /Applications. Install it first."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("语言", "Language")).frame(width: 90, alignment: .leading)
                Picker("", selection: $language) {
                    Text("中文").tag(1)
                    Text("English").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .disabled(running)
                Spacer()
            }
            HStack {
                Text(t("总开数", "Total")).frame(width: 90, alignment: .leading)
                Stepper(value: $total, in: 2...9) {
                    Text("\(total)").font(.title3.monospacedDigit().bold()).frame(width: 30)
                }
                .disabled(running)
                Text(t("包含原版，将创建 \(total - 1) 个副本",
                       "Including the original; creates \(total - 1) copies"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("副本图标", "Copy icons")).frame(width: 90, alignment: .leading)
                Picker("", selection: $iconMode) {
                    Text(t("自动轮换", "Rotate")).tag(IconMode.rotate)
                    Text(t("统一配色", "One colour")).tag(IconMode.style)
                    Text(t("原图标", "Original")).tag(IconMode.none)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(running)
                Spacer()
            }
            iconPreview
        }
    }

    @ViewBuilder
    private var iconPreview: some View {
        switch iconMode {
        case .rotate:
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(order.enumerated()), id: \.offset) { pos, styleIndex in
                            iconChip(styles[styleIndex - 1], label: "WeChat\(pos + 2)")
                                .draggable("\(pos)")
                                .dropDestination(for: String.self) { items, _ in
                                    guard let from = items.first.flatMap(Int.init),
                                          from != pos, from < order.count else { return false }
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        let moved = order.remove(at: from)
                                        order.insert(moved, at: pos)
                                    }
                                    return true
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Text(t("拖拽图标可调整每个副本的配色顺序", "Drag icons to reorder colours per copy"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .allowsHitTesting(!running)
        case .style:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 10) {
                ForEach(1...7, id: \.self) { index in
                    let selected = selectedStyle == index
                    Button { selectedStyle = index } label: {
                        iconChip(styles[index - 1], label: styles[index - 1], selected: selected)
                    }
                    .buttonStyle(.plain)
                    .disabled(running)
                }
            }
        case .none:
            Text(t("副本保留微信原图标。", "Copies keep the original WeChat icon."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func iconChip(_ style: String, label: String, selected: Bool = false) -> some View {
        VStack(spacing: 4) {
            Group {
                if let image = IconCache.image(style) {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 46)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if running {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: runner.progress)
                HStack {
                    Text(runner.statusText.isEmpty ? t("正在运行…", "Running…") : runner.statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(t("取消", "Cancel")) { runner.cancel() }
                }
            }
        } else {
            Button {
                runner.run(language: language, total: total, iconChoice: iconChoice)
            } label: {
                Text(t("创建 / 重建副本", "Create / Rebuild Copies"))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!sourceExists)
        }
    }

    @ViewBuilder
    private var resultBanner: some View {
        switch runner.state {
        case .success:
            banner("checkmark.circle.fill", .green,
                   t("完成：所有 \(total) 个微信实例均已运行。",
                     "Done: all \(total) WeChat instances are running."))
        case .partial:
            banner("exclamationmark.triangle.fill", .orange,
                   t("副本已安装并通过验证，但未检测到所有实例运行，详见日志。",
                     "Copies installed and verified, but not all instances are running. See log."))
        case .failed:
            banner("xmark.octagon.fill", .red,
                   t("失败（退出码 \(runner.exitCode)），详见日志。",
                     "Failed (exit code \(runner.exitCode)). See log."))
        default:
            EmptyView()
        }
    }

    private func banner(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(.callout)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)))
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("运行日志", "Log")).font(.headline)
            ScrollViewReader { proxy in
                ScrollView {
                    Text(runner.log.isEmpty ? t("日志将显示在这里。", "Output will appear here.") : runner.log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(runner.log.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(8)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(height: 170)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                .onChange(of: runner.log) { _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func detectSource() {
        let app = URL(fileURLWithPath: "/Applications/WeChat.app")
        sourceExists = FileManager.default.fileExists(atPath: app.path)
        let plist = app.appendingPathComponent("Contents/Info.plist")
        if let dict = NSDictionary(contentsOf: plist) {
            sourceVersion = dict["CFBundleShortVersionString"] as? String
        }
    }
}

enum IconCache {
    private static var cache: [String: NSImage] = [:]
    static func image(_ style: String) -> NSImage? {
        if let cached = cache[style] { return cached }
        guard let url = Bundle.main.url(forResource: "wechat-\(style)", withExtension: "icns", subdirectory: "wechat_icons"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[style] = image
        return image
    }
}