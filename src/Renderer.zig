const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Texture = @import("game/Texture.zig").Texture;
const Allocator = std.mem.Allocator;

const texturesFilepath = [_][]const u8{
    "empty",
    "assets/textures/floor_construction.bmp",
    "assets/textures/floor_stone.bmp",
    "assets/textures/wall_construction.bmp",
    "assets/textures/wall_mineral.bmp",
    "assets/textures/sapling_wall.bmp",
    "assets/textures/stairs_wall_construction.bmp",
    "assets/textures/door.bmp",
};

pub const Colour = struct { r: u8, g: u8, b: u8 };
const default_screen_height = 1280;
const default_screen_width = 720;

pub const Renderer = @This();

allocator: *Allocator,
sdl_screen: *sdl_wrapper.Window,
sdl_renderer: *sdl_wrapper.Renderer,
sdl_surface: *sdl_wrapper.Surface,
sdl_texture: *sdl_wrapper.Texture,
textures: []Texture,
screen_buffer: []u32,
back_buffer: []u32,
string_buffer: []u8,
cameraX: []f32,
Zbuffer: []f32,
width: u32,
height: u32,
resolution: u32,
spacing: u32,
position: f32,

pub fn init(allocator: *Allocator, width: u32, height: u32, resolution: u32) !Renderer {
    const screen_buffer = try allocator.alloc(u32, (width * height));
    errdefer allocator.free(screen_buffer);

    const string_buffer = try allocator.alloc(u8, 10);
    errdefer allocator.free(string_buffer);

    const back_buffer = try allocator.alloc(u32, (width * height));
    errdefer allocator.free(back_buffer);
    initialiseBackBuffer(width, height, back_buffer);

    const cameraX = try allocator.alloc(f32, resolution);
    errdefer allocator.free(cameraX);

    var i: u32 = 0;
    while (i < resolution) : (i += 1) {
        cameraX[i] = 2 * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(resolution)) - 1; //x-coordinate in camera space
    }

    const Zbuffer = try allocator.alloc(f32, resolution);
    errdefer allocator.free(Zbuffer);

    i = 0;
    while (i < resolution) : (i += 1) {
        Zbuffer[i] = 0;
    }

    try sdl_wrapper.initVideo();

    const sdl_screen = try sdl_wrapper.createWindow(default_screen_height, default_screen_width);
    errdefer sdl_wrapper.destroyWindow(sdl_screen);

    const sdl_renderer = try sdl_wrapper.createRendererFromWindow(sdl_screen);
    errdefer sdl_wrapper.destroyRenderer(sdl_renderer);

    const sdl_surface = try sdl_wrapper.createRGBSurface(width, height);
    errdefer sdl_wrapper.freeSurface(sdl_surface);

    const sdl_texture = try sdl_wrapper.createTextureFromSurface(sdl_renderer, sdl_surface);
    errdefer sdl_wrapper.destroyTexture(sdl_texture);

    var textures = try allocator.alloc(Texture, texturesFilepath.len);
    errdefer allocator.free(textures);

    //textures[0] = try Texture.createTexture(allocator, "assets/textures/error.bmp", 64, 64);

    for (texturesFilepath, 0..) |path, index| {
        textures[index] = try Texture.createTexture(allocator, path, 256, 256);
        errdefer {
            for (textures[0..index]) |texture| {
                texture.deinit();
            }
        }
    }

    const renderer = Renderer{
        .allocator = allocator,
        .sdl_screen = sdl_screen,
        .sdl_renderer = sdl_renderer,
        .sdl_surface = sdl_surface,
        .sdl_texture = sdl_texture,
        .textures = textures,
        .screen_buffer = screen_buffer,
        .back_buffer = back_buffer,
        .string_buffer = string_buffer,
        .cameraX = cameraX,
        .Zbuffer = Zbuffer,
        .width = width,
        .height = height,
        .resolution = resolution,
        .spacing = (width / resolution),
        .position = 0.0,
    };

    std.debug.print("render ready with width:{d}, height:{d}, resolution:{d} and spacing:{d}\n", .{ width, height, resolution, renderer.spacing });
    return renderer;
}

pub fn render(self: *Renderer, delta: f32) void {
    const fps = @as(i32, @intFromFloat(1 / delta));
    const fps_string = std.fmt.bufPrintZ(self.string_buffer, "fps : {d}", .{fps}) catch |err| {
        std.debug.print("Failed to allocate string: {any}\n", .{err});
        return;
    };

    self.position += 5 * delta;

    self.resetBuffer();

    const intPos = @as(u32, @intFromFloat(self.position));

    self.drawColoredColumn(20, 40, 20, 0x80ff0000);
    self.drawColoredColumn(21, 40, 20, 0x80ff0000);
    self.drawColoredColumn(22, 40, 20, 0x800000ff);
    self.drawColoredColumn(23, 40, 20, 0x80ff0000);

    var x: u32 = 0;
    while (x < 150) : (x += 1) {
        self.drawTexturedColumn(350 + x, 100, 50, 1, 40 + x);
    }

    self.drawColoredColumn(intPos, 20, intPos + 20, 0xff0000ff);

    sdl_wrapper.setWindowTitle(self.sdl_screen, fps_string);
    self.updateBuffer();

    self.refreshScreen();
}

fn resetBuffer(self: *Renderer) void {
    std.mem.copyForwards(u32, self.screen_buffer, self.back_buffer);
}

fn drawSpriteSlice(self: *Renderer, x: u32, y: u32, textureIndex: u32, width: u32, height: u32) void {
    const texture = self.textures[textureIndex];

    var currentX: u32 = 0;
    while (currentX < width) : (currentX += 1) {
        var currentY: u32 = 0;
        while (currentY < height) : (currentY += 1) {
            const texel = texture.data[currentX + currentY * texture.width];
            self.screen_buffer[(x + currentX) + (y + currentY) * self.width] = mergePixels(self.screen_buffer[(x + currentX) + (y + currentY) * self.width], texel);
        }
    }
}

fn drawColoredColumn(self: *Renderer, x: u32, height: u32, top: u32, colour: u32) void {
    var currentX = x * self.spacing;
    while (currentX < (x + 1) * self.spacing) : (currentX += 1) {
        var currentY = top;
        while (currentY <= top + height) : (currentY += 1) {
            self.screen_buffer[currentX + currentY * self.width] = mergePixels(self.screen_buffer[currentX + currentY * self.width], colour);
        }
    }
}

fn drawTexturedColumn(self: *Renderer, x: u32, height: u32, top: u32, textureIndex: u32, textureOffset: u32) void {
    const texture = self.textures[textureIndex];

    var currentX: u32 = 0;
    while ((x * self.spacing) + currentX < (x + 1) * self.spacing) : (currentX += 1) {
        var currentY: u32 = 0;
        while (currentY < height) : (currentY += 1) {
            const texelYprojection = @as(f32, @floatFromInt(texture.height)) * (@as(f32, @floatFromInt(currentY)) / @as(f32, @floatFromInt(height)));
            const texel = texture.data[(textureOffset + currentX) + (@as(u32, @intFromFloat(texelYprojection)) * texture.width)];
            self.screen_buffer[(x * self.spacing + currentX) + (currentY + top) * self.width] = mergePixels(self.screen_buffer[(x * self.spacing + currentX) + (currentY + top) * self.width], texel);
        }
    }
}

pub fn setScreenSize(self: *Renderer, width: u32, height: u32) bool {
    _ = self;
    _ = width;
    _ = height;

    // self.width = width;
    // self.height = height;
    // self.spacing = (width / self.resolution);

    // self.allocator.free(self.screen_buffer);

    // const screen_buffer = self.allocator.alloc(u32, (width * height)) catch |err| {
    //     std.debug.print("Failed to allocate screen buffer: {any}\n", .{err});
    //     return true;
    // };

    // self.screen_buffer = screen_buffer;

    // sdl_wrapper.destroyTexture(self.sdl_texture);
    // sdl_wrapper.freeSurface(self.sdl_surface);
    // sdl_wrapper.destroyRenderer(self.sdl_renderer);

    // const sdl_renderer = sdl_wrapper.createRendererFromWindow(self.sdl_screen) catch |err| {
    //     std.debug.print("Failed to create renderer: {any}\n", .{err});
    //     return true;
    // };
    // self.sdl_renderer = sdl_renderer;

    // const sdl_surface = sdl_wrapper.createRGBSurface(width, height) catch |err| {
    //     std.debug.print("Failed to create surface: {any}\n", .{err});
    //     return true;
    // };
    // self.sdl_surface = sdl_surface;

    // const sdl_texture = sdl_wrapper.createTextureFromSurface(self.sdl_renderer, self.sdl_surface) catch |err| {
    //     std.debug.print("Failed to create texture: {any}\n", .{err});
    //     return true;
    // };
    // self.sdl_texture = sdl_texture;

    // std.debug.print("new resolution {d}, {d}\n", .{ width, height });

    return false;
}

fn updateBuffer(self: *Renderer) void {
    sdl_wrapper.renderBuffer(self.sdl_renderer, self.sdl_texture, self.screen_buffer, self.width);
}

fn refreshScreen(self: *Renderer) void {
    sdl_wrapper.refreshScreen(self.sdl_renderer);
}

pub fn deinit(self: *Renderer) void {
    std.debug.print("Deinit SDLRenderer {d}x{d}:{d}\n", .{ self.width, self.height, self.resolution });

    self.allocator.free(self.screen_buffer);
    self.screen_buffer = undefined;

    self.allocator.free(self.back_buffer);
    self.back_buffer = undefined;

    self.allocator.free(self.string_buffer);
    self.string_buffer = undefined;

    self.allocator.free(self.cameraX);
    self.cameraX = undefined;

    self.allocator.free(self.Zbuffer);
    self.Zbuffer = undefined;

    for (self.textures) |*texture| {
        texture.deinit();
    }
    self.allocator.free(self.textures);
    self.textures = undefined;

    sdl_wrapper.destroyTexture(self.sdl_texture);
    sdl_wrapper.freeSurface(self.sdl_surface);
    sdl_wrapper.destroyRenderer(self.sdl_renderer);
    sdl_wrapper.destroyWindow(self.sdl_screen);
    sdl_wrapper.quit();
    //self.allocator.free(*self);
}

fn drawRect(self: *Renderer, x: u32, y: u32, width: u32, height: u32, colour: Colour) void {
    const sdl_color = sdl_wrapper.Color{ .r = colour.r, .g = colour.g, .b = colour.b, .a = 255 };
    sdl_wrapper.drawRect(self.sdl_renderer, x, y, width, height, sdl_color);
}

fn drawLine(self: *Renderer, x1: u32, y1: u32, x2: u32, y2: u32, colour: Colour) void {
    const sdl_color = sdl_wrapper.Color{ .r = colour.r, .g = colour.g, .b = colour.b, .a = 255 };
    sdl_wrapper.drawLine(self.sdl_renderer, x1, y1, x2, y2, sdl_color);
}

//take two u32s pixels and merge them together depending on the alpha value of the second pixel
fn mergePixels(pixel1: u32, pixel2: u32) u32 {
    const alpha = (pixel2 >> 24) & 0xff;
    const invAlpha = 255 - alpha;

    const r1 = (pixel1 >> 16) & 0xff;
    const g1 = (pixel1 >> 8) & 0xff;
    const b1 = pixel1 & 0xff;

    const r2 = (pixel2 >> 16) & 0xff;
    const g2 = (pixel2 >> 8) & 0xff;
    const b2 = pixel2 & 0xff;

    const r = (r1 * invAlpha + r2 * alpha) / 255;
    const g = (g1 * invAlpha + g2 * alpha) / 255;
    const b = (b1 * invAlpha + b2 * alpha) / 255;

    return (r << 16) | (g << 8) | b;
}

fn initialiseBackBuffer(width: u32, height: u32, buffer: []u32) void {
    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            const index = (y * width) + x;
            buffer[index] = 0xffffff;
        }
    }
}
