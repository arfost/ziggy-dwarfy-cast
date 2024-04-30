const std = @import("std");
const Allocator = std.mem.Allocator;

pub const MapCell = struct {
    floor_texture: u8 = 0,
    wall_texture: u8 = 0,
    thin_wall: u8 = 0,
    heightRatio: f16 = 1.0,
    wall_tint: u32 = 0,
    floor_tint: u32 = 0,
    water: u8 = 0,
    magma: u8 = 0,
};

const Sprite = struct {
    texture: u8,
    x: f32,
    y: f32,
};

const cellDefinitions = [_]MapCell{
    .{},
    .{ .floor_texture = 1 },
    .{ .floor_texture = 2 },
    .{ .floor_texture = 1, .wall_texture = 3 },
    .{ .floor_texture = 2, .wall_texture = 3, .thin_wall = 0, .wall_tint = 0x80FF0000 },
    .{ .floor_texture = 1, .wall_texture = 4, .heightRatio = 0.5 },
    .{ .floor_texture = 2, .wall_texture = 5, .heightRatio = 0.2 },
    .{ .floor_texture = 1, .thin_wall = 7, .heightRatio = 1 },
    .{ .floor_texture = 2, .thin_wall = 7, .heightRatio = 1 },
};

pub const MapLoader = @This();

allocator: *Allocator,
map: [][]MapCell,
width: u32,
height: u32,
length: u32,

pub fn init(allocator: *Allocator, filepath: []const u8) !MapLoader {
    var pathBuffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const file_path = try std.fs.realpath(filepath, &pathBuffer);

    const file = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
    defer file.close();

    const max_buffer_size = 20000;
    const file_buffer = try file.readToEndAlloc(allocator.*, max_buffer_size);
    defer allocator.free(file_buffer);

    var it = std.mem.split(u8, file_buffer, "\n");
    const widthLine = it.next().?;
    const lengthLine = it.next().?;
    const heightLine = it.next().?;
    var widthTokenIt = std.mem.tokenize(u8, widthLine, "width =");
    var lengthTokenIt = std.mem.tokenize(u8, lengthLine, "length =");
    var heightTokenIt = std.mem.tokenize(u8, heightLine, "height =");

    const widthToken = widthTokenIt.next().?;
    const lengthToken = lengthTokenIt.next().?;
    const heightToken = heightTokenIt.next().?;
    const radix = 10;
    const width = try std.fmt.parseInt(u32, widthToken, radix);
    const length = try std.fmt.parseInt(u32, lengthToken, radix);
    const height = try std.fmt.parseInt(u32, heightToken, radix);

    const mapDataSize: usize = width * length;

    var mapLayerBuffer = try allocator.alloc(MapCell, mapDataSize);
    errdefer allocator.free(mapLayerBuffer);

    var mapBuffer = try allocator.alloc([]MapCell, mapLayerBuffer.len * height);

    const dataBytes = it.rest();
    var currentLayer: u16 = 0;
    var dataCount: usize = 0;
    for (dataBytes) |byte| {
        if (std.ascii.eqlIgnoreCase(&[_]u8{byte}, "]")) {
            mapBuffer[currentLayer] = mapLayerBuffer;
            currentLayer += 1;
            if (currentLayer == height) {
                break;
            }
            mapLayerBuffer = try allocator.alloc(MapCell, mapDataSize);
            dataCount = 0;
            continue;
        }
        if (!std.ascii.isDigit(byte))
            continue;

        const cellType = try std.fmt.parseInt(u8, &[_]u8{byte}, radix);
        const cellDefinition = cellDefinitions[cellType];

        mapLayerBuffer[dataCount] = .{
            .floor_texture = cellDefinition.floor_texture,
            .wall_texture = cellDefinition.wall_texture,
            .thin_wall = cellDefinition.thin_wall,
            .heightRatio = cellDefinition.heightRatio,
            .wall_tint = cellDefinition.wall_tint,
            .floor_tint = cellDefinition.floor_tint,
            .water = cellDefinition.water,
            .magma = cellDefinition.magma,
        };

        dataCount += 1;
    }

    return MapLoader{
        .allocator = allocator,
        .map = mapBuffer,
        .width = width,
        .height = height,
        .length = length,
    };
}

pub fn deinit(self: *MapLoader) void {
    var z: u32 = 0;
    while (z < self.height) {
        self.allocator.free(self.map[z]);
        z += 1;
    }

    self.allocator.free(self.map);
}
