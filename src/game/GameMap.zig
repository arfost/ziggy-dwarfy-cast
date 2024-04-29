const std = @import("std");
const MapLoader = @import("MapLoader.zig");
const Allocator = std.mem.Allocator;

const MapError = error{
    InvalidCell,
};

pub const GameMap = @This();

mapLoader: *MapLoader,

pub fn init(mapLoader: *MapLoader) GameMap {
    const gameMap = GameMap{ .mapLoader = mapLoader };
    return gameMap;
}

pub fn getCellInfos(self: *GameMap, x: i32, y: i32, z: i32) MapError!*MapLoader.MapCell {
    if (x >= self.mapLoader.width or x < 0) {
        return MapError.InvalidCell;
    }
    if (y >= self.mapLoader.length or y < 0) {
        return MapError.InvalidCell;
    }
    if (z >= self.mapLoader.height or z < 0) {
        return MapError.InvalidCell;
    }

    const safeX: u32 = @intCast(x);
    const safeY: u32 = @intCast(y);
    const safeZ: u32 = @intCast(z);

    return &self.mapLoader.map[safeZ][@intCast(safeX + safeY * self.mapLoader.width)];
}

pub fn deinit(self: *GameMap) void {
    _ = self;
}
