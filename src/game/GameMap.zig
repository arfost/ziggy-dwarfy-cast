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

pub fn getCellInfos(self: *GameMap, x: u32, y: u32, z: u32) MapError!MapLoader.MapCell {
    if (x >= self.mapLoader.width) {
        return MapError.InvalidCell;
    }
    if (y >= self.mapLoader.length) {
        return MapError.InvalidCell;
    }
    if (z >= self.mapLoader.height) {
        return MapError.InvalidCell;
    }
    return self.mapLoader.map[z][x + y * self.mapLoader.width];
}

pub fn deinit(self: *GameMap) void {
    _ = self;
}
