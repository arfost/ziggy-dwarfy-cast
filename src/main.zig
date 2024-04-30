const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Renderer = @import("renderer.zig");
const MapLoader = @import("game/MapLoader.zig");
const Player = @import("game/Player.zig");
const GameMap = @import("game/GameMap.zig");

var cursorFps: bool = false;

pub fn main() anyerror!void {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gp.deinit();
    var allocator = gp.allocator();

    var map_loader = try MapLoader.init(&allocator, "assets/maps/map1.map");
    defer map_loader.deinit();

    var game_map = GameMap.init(&map_loader);

    var player = Player.init(0, 0, 0);

    var renderer = try Renderer.init(&allocator, 1280, 720, 640);
    defer renderer.deinit();

    const cellInfos = game_map.getCellInfos(2, 2, 2);

    std.log.debug("cellInfos : {any}", .{cellInfos});

    var time: i128 = std.time.nanoTimestamp();
    var old_time: i128 = std.time.nanoTimestamp();
    const min_time_per_frame = 16 * std.time.ns_per_ms;

    var ticks: u32 = 0xFFFFFF;
    while (ticks > 0) : (ticks -= 1) {

        // Quick and dirty cap at ~60FPs.
        old_time = time;
        time = std.time.nanoTimestamp();
        var delta_time = time - old_time;

        if (delta_time < min_time_per_frame) {
            std.time.sleep(@intCast(min_time_per_frame - delta_time));
        }

        delta_time = std.time.nanoTimestamp() - old_time;
        const frame_time_seconds = @as(f32, @floatFromInt(delta_time)) / std.time.ns_per_s;

        if (processInput(&player, frame_time_seconds))
            break;
        if (processEvents(&renderer))
            break;

        renderer.render(frame_time_seconds, &player, &game_map);
    }
}

// Basic movement for testing.
pub fn processInput(player: *Player, frame_time_seconds: f32) bool {
    var keys = sdl_wrapper.getKeyboardState();

    if (keys.isPressed(.w)) {
        player.walk(frame_time_seconds * -2.0);
    }

    if (keys.isPressed(.s)) {
        player.walk(frame_time_seconds * 2.0);
    }

    if (keys.isPressed(.a)) {
        player.strafe(frame_time_seconds * -2.0);
    }

    if (keys.isPressed(.d)) {
        player.strafe(frame_time_seconds * 2.0);
    }

    if (keys.isPressed(.q)) {
        player.fly(frame_time_seconds * 1.0);
    }

    if (keys.isPressed(.e)) {
        player.fly(frame_time_seconds * -1.0);
    }

    if (keys.isPressed(.tab)) {
        cursorFps = !cursorFps;
        std.log.debug("set mouse fps mode {any}", .{cursorFps});
        sdl_wrapper.toggleFPSMouse(cursorFps);
    }
    const mouseRelative = sdl_wrapper.getRelativeMousePosition();

    const turnValue: f32 = (@as(f32, @floatFromInt(mouseRelative.x))) * frame_time_seconds * (std.math.pi / 180.0);
    const pitchValue: f32 = (@as(f32, @floatFromInt(mouseRelative.y))) * frame_time_seconds * (std.math.pi / 180.0);
    player.turn(turnValue);
    player.pitchChange(pitchValue);

    if (keys.isPressed(.x)) {
        return true;
    }

    return false;
}

pub fn processEvents(renderer: *Renderer) bool {
    while (sdl_wrapper.pollEvent()) |event| {
        switch (event) {
            .quit => return true,
            .window => switch (event.window) {
                .resize => return renderer.setScreenSize(event.window.resize.width, event.window.resize.height),
                else => return false,
            },
            else => return false,
        }
    }
    return false;
}
