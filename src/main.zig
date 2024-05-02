const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Renderer = @import("renderer.zig");
const MapLoader = @import("game/MapLoader.zig");
const Player = @import("game/Player.zig");
const GameMap = @import("game/GameMap.zig");

pub fn main() anyerror!void {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gp.deinit();
    var allocator = gp.allocator();

    var map_loader = try MapLoader.init(&allocator, "assets/maps/map1.map");
    defer map_loader.deinit();

    var game_map = GameMap.init(&map_loader);

    var player = Player.init(0, 0, 0);

    var renderer = try Renderer.init(&allocator, 640, 360, 320);
    defer renderer.deinit();

    const cellInfos = game_map.getCellInfos(2, 2, 2);

    std.log.debug("cellInfos : {any}", .{cellInfos});

    sdl_wrapper.toggleFPSMouse(true);

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
        if (processEvents(&renderer, &player))
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

    if (keys.isPressed(.x)) {
        return true;
    }

    return false;
}

pub fn processEvents(renderer: *Renderer, player: *Player) bool {
    while (sdl_wrapper.pollEvent()) |event| {
        switch (event) {
            .mouse => {
                // std.log.debug("mouse event : {any}", .{event.mouse});
                player.turn(event.mouse.xrel);
                player.pitchChange(event.mouse.yrel);
            },
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
