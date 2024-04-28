const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Texture = struct {
    allocator: *Allocator,
    width: u32,
    height: u32,
    name: []const u8,
    data: []u32,

    pub fn createTexture(allocator: *Allocator, filePath: []const u8, width: u32, height: u32) !Texture {
        std.log.debug("init texture {s} ", .{filePath});
        const texture_data_length = width * height;

        const data = try allocator.alloc(u32, texture_data_length);
        errdefer allocator.free(data);

        var texture = Texture{
            .allocator = allocator,
            .name = filePath,
            .width = width,
            .height = height,
            .data = data,
        };

        const fileContent = readFile(allocator, filePath) catch |err| {
            std.debug.print("Failed to get file content for texture file {s}: {any}\n", .{ filePath, err });
            var x: u32 = 0;
            while (x < texture.width) : (x += 1) {
                var y: u32 = 0;
                while (y < texture.height) : (y += 1) {
                    texture.data[x + y * texture.width] = 0xffffff;
                }
            }
            return texture;
        };

        const image_data_start_offset = fileContent[0x0A];
        for (texture.data, 0..) |*texel, index| {
            const a: u32 = @as(u32, fileContent[image_data_start_offset + (index * 4) + 3]) << 24;
            const r: u32 = @as(u32, fileContent[image_data_start_offset + (index * 4) + 2]) << 16;
            const g: u32 = @as(u32, fileContent[image_data_start_offset + (index * 4) + 1]) << 8;
            const b: u32 = @as(u32, fileContent[image_data_start_offset + (index * 4)]);
            texel.* = r | g | b | a;
        }

        allocator.free(fileContent);

        return texture;
    }

    pub fn deinit(self: *Texture) void {
        self.allocator.free(self.data);
        self.data = undefined;
    }
};

fn readFile(allocator: *Allocator, filename: []const u8) ![]u8 {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const file_path = try std.fs.realpath(filename, &path_buffer);

    const file = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_only });
    defer file.close();

    const max_buffer_size = 1024 * 1024; // Big enough for my current testing textures
    const file_buffer = try file.readToEndAlloc(allocator.*, max_buffer_size);

    return file_buffer;
}
