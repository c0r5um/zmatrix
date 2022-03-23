const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const Size = struct {
    width: usize,
    height: usize
};

var i: usize = 0;
var size: Size = undefined;
var tty: fs.File = undefined;
var original: os.termios = undefined;
var raw: os.termios = undefined;

fn termEnter() !void {
    const writer = tty.writer();

    original = try os.tcgetattr(tty.handle);
    errdefer termLeave() catch {};

    raw = original;
    //   ECHO: Stop the terminal from displaying pressed keys.
    // ICANON: Disable canonical ("cooked") input mode. Allows us to read inputs
    //         byte-wise instead of line-wise.
    //   ISIG: Disable signals for Ctrl-C (SIGINT) and Ctrl-Z (SIGTSTP), so we
    //         can handle them as "normal" escape sequences.
    // IEXTEN: Disable input preprocessing. This allows us to handle Ctrl-V,
    //         which would otherwise be intercepted by some terminals.
    raw.lflag &= ~@as(
        os.system.tcflag_t,
        os.system.ECHO | os.system.ICANON | os.system.ISIG | os.system.IEXTEN
    );

    //   IXON: Disable software control flow. This allows us to handle Ctrl-S
    //         and Ctrl-Q.
    //  ICRNL: Disable converting carriage returns to newlines. Allows us to
    //         handle Ctrl-J and Ctrl-M.
    // BRKINT: Disable converting sending SIGINT on break conditions. Likely has
    //         no effect on anything remotely modern.
    //  INPCK: Disable parity checking. Likely has no effect on anything
    //         remotely modern.
    // ISTRIP: Disable stripping the 8th bit of characters. Likely has no effect
    //         on anything remotely modern.
    raw.iflag &= ~@as(
        os.system.tcflag_t,
        os.system.IXON | os.system.ICRNL | os.system.BRKINT | os.system.INPCK | os.system.ISTRIP
    );

    // Disable output processing. Common output processing includes prefixing
    // newline with a carriage return. 
    raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);

    // Set the character size to 8 bits per byte. Likely has no efffect on
    // anything remotely modern.
    raw.cflag |= os.system.CS8;

    raw.cc[os.system.V.TIME] = 0;
    raw.cc[os.system.V.MIN] = 0;

    try os.tcsetattr(tty.handle, .FLUSH, raw);
    try hideCursor(writer);
    try clear(writer);
}

fn termLeave() !void {
    try os.tcsetattr(tty.handle, .FLUSH, original);
}

fn clear(writer: anytype) !void {
    try writer.writeAll("\x1B[2J");
}

fn hideCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?251");
}

fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    _ = try writer.print("\x1B[{};{}H", .{ row + 1, col + 1});
}

fn writeChar(writer: anytype, char: []const u8, y: usize, x: usize ) !void {
    try moveCursor(writer, y, x);
    try writer.writeAll(char);
}


fn getSize() !Size {
    var win_size = mem.zeroes(os.system.winsize);
    const err = os.system.ioctl(tty.handle, os.system.T.IOCGWINSZ, @ptrToInt(&win_size));
    if (os.errno(err) != .SUCCESS) {
        return os.unexpectedErrno(@intToEnum(os.system.E, err));
    }

    return Size {
        .height = win_size.ws_row,
        .width = win_size.ws_col,
    };

}

pub fn main() anyerror!void {
    //std.log.info("All your codebase are belong to us.", .{});
    //const original = try os.tcgetattr(tty.handle);
    
    //debug.print("{}\n", .{@TypeOf(original)});

    tty = try fs.cwd().openFile("/dev/tty", .{ .read = true, .write = true });
    defer tty.close();

    const writer = tty.writer();
    
    size = try getSize();

    try termEnter();
    defer termLeave() catch {};

    while (i < size.height) {
        //debug.print("{}\n", .{i});
        try moveCursor(writer, i, 3 );
        try writeChar(writer, "a", i, 3 );
        i += 1;

    }
    //try moveCursor(writer, 3, 3 );
    //try writeChar(writer, "a", 3, 3 );

    //debug.print("{}\n", .{size});



}
