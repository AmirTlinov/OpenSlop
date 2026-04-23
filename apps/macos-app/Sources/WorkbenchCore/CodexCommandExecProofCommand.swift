import Foundation

public enum DaemonCodexCommandExecProofCommand {
    public static let boundedInteractiveEcho: [String] = [
        "python3",
        "-u",
        "-c",
        """
        import sys
        print('READY', flush=True)
        for line in sys.stdin:
            sys.stdout.write(line)
            sys.stdout.flush()
        print('CLOSED', flush=True)
        """
    ]
}
