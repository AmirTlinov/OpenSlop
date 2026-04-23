import Foundation
import WorkbenchCore

enum CommandExecProofMode: String, CaseIterable, Identifiable {
    case interactiveStdin
    case ptyResize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interactiveStdin:
            return "Interactive stdin"
        case .ptyResize:
            return "PTY resize"
        }
    }

    var headline: String {
        switch self {
        case .interactiveStdin:
            return "Standalone exec interactive proof"
        case .ptyResize:
            return "Standalone exec PTY resize proof"
        }
    }

    var summary: String {
        switch self {
        case .interactiveStdin:
            return "Bounded same-connection proof lane. Fixed command ждёт output-paced follow-up control: write, close stdin или terminate."
        case .ptyResize:
            let initial = DaemonCodexCommandExecProofCommand.ptyResizeInitialSize
            let target = DaemonCodexCommandExecProofCommand.ptyResizeTargetSize
            return "Bounded same-connection PTY proof lane. Fixed command стартует в \(initial.cols)x\(initial.rows), ждёт resize в \(target.cols)x\(target.rows), потом один final stdin+close."
        }
    }

    var detail: String {
        "Каждый следующий control здесь привязан к output burst. Если follow-up control не приходит примерно за 5 секунд, lane завершается failed."
    }

    var command: [String] {
        switch self {
        case .interactiveStdin:
            return DaemonCodexCommandExecProofCommand.boundedInteractiveEcho
        case .ptyResize:
            return DaemonCodexCommandExecProofCommand.ptyResizeWitness
        }
    }

    var defaultStdin: String {
        DaemonCodexCommandExecProofCommand.defaultInteractiveInput
    }

    var footerNote: String {
        switch self {
        case .interactiveStdin:
            return "Pane остаётся standalone proof surface. Он не обещает transcript bridge, reconnect, resize surface вне fixed proof mode и полноценный terminal runtime."
        case .ptyResize:
            return "Pane доказывает только fixed PTY resize witness. Он не обещает transcript resize bridge, arbitrary geometry controls и clean terminal rendering."
        }
    }
}
