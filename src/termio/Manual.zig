//! Manual backend for terminal I/O that doesn't spawn a subprocess.
//! This is used for scenarios where terminal output comes from an external
//! source (e.g., SSH connection) rather than a local PTY.
//!
//! When the terminal needs to send data back (e.g., cursor position response),
//! the write_cb callback is invoked if set.
const Manual = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const renderer = @import("../renderer.zig");
const terminal = @import("../terminal/main.zig");
const termio = @import("../termio.zig");

const log = std.log.scoped(.io_manual);

/// Callback type for writing data back to the external source.
/// NOTE: This type must match `ghostty_surface_write_cb` in ghostty.h
pub const WriteCb = *const fn (?*anyopaque, [*]const u8, usize) callconv(.c) void;

/// Write callback - called when terminal needs to send data back
write_cb: ?WriteCb,

/// Userdata passed to write callback
userdata: ?*anyopaque,

pub const Config = struct {
    /// Callback for writing data back to external source
    write_cb: ?WriteCb = null,
    /// Userdata passed to write callback
    userdata: ?*anyopaque = null,
};

pub const ThreadData = struct {
    // No thread data needed for manual backend

    pub fn deinit(self: *ThreadData, alloc: Allocator) void {
        _ = self;
        _ = alloc;
    }
};

pub fn init(
    alloc: Allocator,
    cfg: Config,
) !Manual {
    _ = alloc;
    return .{
        .write_cb = cfg.write_cb,
        .userdata = cfg.userdata,
    };
}

pub fn deinit(self: *Manual) void {
    _ = self;
}

pub fn initTerminal(self: *Manual, term: *terminal.Terminal) void {
    _ = self;
    _ = term;
    // Nothing to initialize for manual backend
}

pub fn threadEnter(
    self: *Manual,
    alloc: Allocator,
    io: *termio.Termio,
    td: *termio.Termio.ThreadData,
) !void {
    _ = self;
    _ = alloc;
    _ = io;

    // Set up thread data with manual backend data
    td.backend = .{ .manual = .{} };

    log.info("manual backend thread entered", .{});
}

pub fn threadExit(self: *Manual, td: *termio.Termio.ThreadData) void {
    _ = self;
    _ = td;
    log.info("manual backend thread exited", .{});
}

pub fn focusGained(
    self: *Manual,
    td: *termio.Termio.ThreadData,
    focused: bool,
) !void {
    _ = self;
    _ = td;
    _ = focused;
    // Nothing to do for focus changes in manual mode
}

pub fn resize(
    self: *Manual,
    grid_size: renderer.GridSize,
    screen_size: renderer.ScreenSize,
) !void {
    _ = self;
    _ = grid_size;
    _ = screen_size;
    // Nothing to do for resize in manual mode
    // The external application handles terminal size
}

/// Queue data to be written back to the external source.
/// This is called when the terminal needs to send responses (e.g., cursor position).
///
/// Note: The `linefeed` parameter is ignored because terminal responses use explicit
/// escape sequences and don't require LF→CRLF translation.
///
/// THREADING: This is called from the termio thread. The callback implementation
/// should be thread-safe (e.g., dispatch to main thread if needed).
pub fn queueWrite(
    self: *Manual,
    alloc: Allocator,
    td: *termio.Termio.ThreadData,
    data: []const u8,
    linefeed: bool,
) !void {
    _ = alloc;
    _ = td;
    _ = linefeed;

    if (self.write_cb) |cb| {
        log.debug("manual backend queueWrite: sending {} bytes via callback", .{data.len});
        cb(self.userdata, data.ptr, data.len);
    } else {
        log.debug("manual backend queueWrite: {} bytes (no callback set)", .{data.len});
    }
}

pub fn changeConfig(self: *Manual, config: *termio.DerivedConfig) void {
    _ = self;
    _ = config;
}

pub fn childExitedAbnormally(
    self: *Manual,
    gpa: Allocator,
    t: *terminal.Terminal,
    exit_code: u32,
    runtime_ms: u64,
) !void {
    _ = self;
    _ = gpa;
    _ = t;
    _ = exit_code;
    _ = runtime_ms;
    // No child process in manual mode
}
