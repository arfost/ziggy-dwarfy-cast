const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Renderer = @import("renderer.zig");
const MapLoader = @import("game/MapLoader.zig");
const GameMap = @import("game/GameMap.zig");

pub fn main() anyerror!void {
    var gp = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gp.deinit();
    var allocator = gp.allocator();

    var map_loader = try MapLoader.init(&allocator, "assets/maps/map1.map");
    defer map_loader.deinit();

    var game_map = GameMap.init(&map_loader);

    var renderer = try Renderer.init(&allocator, 1280, 720, 800);
    defer renderer.deinit();

    const cellInfos = game_map.getCellInfos(2, 2, 2);

    std.log.debug("cellInfos : {any}", .{cellInfos});

    var time: i128 = std.time.nanoTimestamp();
    var old_time: i128 = std.time.nanoTimestamp();
    const min_time_per_frame = 16 * std.time.ns_per_ms;

    var ticks: u32 = 0xFFFFFF;
    while (ticks > 0) : (ticks -= 1) {
        if (processInput())
            break;
        if (processEvents(&renderer))
            break;

        // Quick and dirty cap at ~60FPs.
        old_time = time;
        time = std.time.nanoTimestamp();
        var delta_time = time - old_time;

        if (delta_time < min_time_per_frame) {
            std.time.sleep(@intCast(min_time_per_frame - delta_time));
        }
        delta_time = std.time.nanoTimestamp() - old_time;
        const frame_time_seconds = @as(f32, @floatFromInt(delta_time)) / std.time.ns_per_s;

        renderer.render(frame_time_seconds);
    }
}

// Basic movement for testing.
pub fn processInput() bool {
    var keys = sdl_wrapper.getKeyboardState();

    // if (keys.isPressed(.k))
    //     engine.turnLeft(state);

    // if (keys.isPressed(.l))
    //     engine.turnRight(state);

    // if (keys.isPressed(.w))
    //     engine.moveForward(state);

    // if (keys.isPressed(.s))
    //     engine.moveBackward(state);

    // if (keys.isPressed(.a))
    //     engine.strafeLeft(state);

    // if (keys.isPressed(.d))
    //     engine.strafeRight(state);

    // if (keys.isPressed(.i)) {
    //     std.debug.print("state {}\n", .{state});
    // }

    // if (keys.isPressed(.t)) {
    //     engine.toggleTextures(state);
    // }

    // if (keys.isPressed(.m)) {
    //     engine.toggleMap(state);
    // }

    // if (keys.isPressed(.g)) {
    //     engine.toggleMainGame(state);
    // }

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
