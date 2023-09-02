//! Safe zero-cost message passing between Zig programs.

const std = @import("std");

const builtin = std.builtin;
const fmt = std.fmt;

pub const Error = error{InsufficientLength};

/// Cast a message to an array buffer.
pub fn castToArray(
    comptime T: type,
    msg: *T,
) *align(@alignOf(T)) [@sizeOf(T)]u8 {
    comptime assertSafe(T);
    return @ptrCast(msg);
}

/// Cast a message to an array buffer (const).
pub fn castToArrayConst(
    comptime T: type,
    msg: *const T,
) *align(@alignOf(T)) const [@sizeOf(T)]u8 {
    comptime assertSafe(T);
    return @ptrCast(msg);
}

/// Writes a message into a slice buffer.
pub fn writeIntoSlice(
    comptime T: type,
    msg: *const T,
    buf: []u8,
) Error!void {
    comptime assertSafe(T);

    if (buf.len < @sizeOf(T)) {
        return error.InsufficientLength;
    }

    var dst = buf[0..@sizeOf(T)];
    const src: *const [@sizeOf(T)]u8 = @ptrCast(msg);

    @memcpy(dst, src);
}

/// Cast an array buffer to a message.
pub fn castFromArray(
    comptime T: type,
    buf: *align(@alignOf(T)) [@sizeOf(T)]u8,
) *T {
    comptime assertSafe(T);
    return @ptrCast(buf);
}

/// Cast an array buffer to a message (const).
pub fn castFromArrayConst(
    comptime T: type,
    buf: *align(@alignOf(T)) const [@sizeOf(T)]u8,
) *const T {
    comptime assertSafe(T);
    return @ptrCast(buf);
}

/// Reads a message from a slice buffer.
pub fn readFromSlice(
    comptime T: type,
    msg: *T,
    buf: []const u8,
) Error!void {
    comptime assertSafe(T);

    if (buf.len < @sizeOf(T)) {
        return error.InsufficientLength;
    }

    var dst: *[@sizeOf(T)]u8 = @ptrCast(msg);
    const src = buf[0..@sizeOf(T)];

    @memcpy(dst, src);
}

//
//
// Comptime checking
//
//

/// Asserts a type is safe to send/receive.
fn assertSafe(comptime T: type) void {
    switch (@typeInfo(T)) {
        .Bool => {},
        .Int => assertSafeInt(T),
        .Float => {},
        .Array => |a| assertSafe(a.child),
        .Struct => |s| assertSafeStruct(T, s),
        else => @compileError(fmt.comptimePrint(
            "unsupported type `{s}`",
            .{@typeName(T)},
        )),
    }
}

/// Asserts an integer type is safe to send/receive.
///
/// Types that do not have a fixed width or whose width is architecture
/// dependent will generate a compile failure.
fn assertSafeInt(comptime T: type) void {
    switch (T) {
        isize,
        usize,
        c_char,
        c_short,
        c_ushort,
        c_int,
        c_uint,
        c_long,
        c_ulong,
        c_longlong,
        c_ulonglong,
        c_longdouble,
        => {
            @compileError(fmt.comptimePrint(
                "unsupported integer `{s}`: width is architecture dependent",
                .{@typeName(T)},
            ));
        },
        else => {},
    }
}

/// Asserts a struct is safe to send/receive.
///
/// Structs must use packed format, and every field type must also conform.
fn assertSafeStruct(comptime T: type, comptime s: builtin.Type.Struct) void {
    if (s.layout != .Packed) {
        @compileError(fmt.comptimePrint(
            "unsupported struct `{s}`: does not use packed layout",
            .{@typeName(T)},
        ));
    }

    inline for (s.fields) |field| {
        assertSafe(field.type);
    }
}

//
//
// Unit tests
//
//

test "smoke castToArray, u32" {
    var msg: u32 = 123456789;
    const buf = castToArray(u32, &msg);
    try std.testing.expectEqual(msg, @as(u32, @bitCast(buf.*)));
}

test "smoke castToArray, f32" {
    var msg: f32 = 1234.56789;
    const buf = castToArray(f32, &msg);
    try std.testing.expectEqual(msg, @as(f32, @bitCast(buf.*)));
}

test "smoke castToArray, [1]u32" {
    var msg = [1]u32{123456789};
    const buf = castToArray([1]u32, &msg);
    try std.testing.expectEqual(msg, @as([1]u32, @bitCast(buf.*)));
}

test "smoke castToArray, struct{u32}" {
    const Msg = packed struct { val: u32 };
    var msg = Msg{ .val = 123456789 };
    const buf = castToArray(Msg, &msg);
    try std.testing.expectEqual(msg, @as(Msg, @bitCast(buf.*)));
}

test "smoke castToArrayConst, u32" {
    const msg: u32 = 123456789;
    const buf = castToArrayConst(u32, &msg);
    try std.testing.expectEqual(msg, @as(u32, @bitCast(buf.*)));
}

test "smoke castFromArray, u32" {
    var msg: u32 = 123456789;
    const buf: *align(4) [4]u8 = @ptrCast(&msg);
    try std.testing.expectEqual(msg, castFromArray(u32, buf).*);
}

test "smoke castFromArrayConst, u32" {
    const msg: u32 = 123456789;
    const buf: *align(4) const [4]u8 = @ptrCast(&msg);
    try std.testing.expectEqual(msg, castFromArrayConst(u32, buf).*);
}

test "smoke writeIntoSlice, u32" {
    const msg: u32 = 123456789;
    var buf = [_]u8{0} ** 4;
    try writeIntoSlice(u32, &msg, &buf);
    try std.testing.expectEqual(msg, @as(u32, @bitCast(buf)));
}

test "smoke readFromSlice, u32" {
    const msg: u32 = 123456789;
    const buf: *const [4]u8 = @ptrCast(&msg);
    var newmsg: u32 = 0;
    try readFromSlice(u32, &newmsg, buf);
    try std.testing.expectEqual(msg, newmsg);
}
