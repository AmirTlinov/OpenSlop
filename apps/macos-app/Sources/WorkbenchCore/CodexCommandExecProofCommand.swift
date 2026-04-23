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

    public static let ptyResizeWitness: [String] = [
        "python3",
        "-u",
        "-c",
        """
        import fcntl
        import signal
        import struct
        import sys
        import termios
        def size():
            rows, cols, _, _ = struct.unpack(
                'HHHH',
                fcntl.ioctl(sys.stdin.fileno(), termios.TIOCGWINSZ, struct.pack('HHHH', 0, 0, 0, 0)),
            )
            return cols, rows
        def emit(label, marker):
            cols, rows = size()
            sys.stdout.write(marker)
            sys.stdout.flush()
            print(f'{label}:{cols}x{rows}', flush=True)
        def on_winch(signum, frame):
            emit('SIZE2', 'W')
        signal.signal(signal.SIGWINCH, on_winch)
        emit('SIZE1', 'R')
        line = sys.stdin.readline()
        print(f'READ:{line.rstrip()}', flush=True)
        """
    ]
}
