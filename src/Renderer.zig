const std = @import("std");
const sdl_wrapper = @import("sdl_wrapper.zig");
const Texture = @import("game/Texture.zig").Texture;
const Player = @import("game/Player.zig");
const GameMap = @import("game/GameMap.zig");
const Raycaster = @import("Raycaster.zig");
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
raycaster: Raycaster,
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

    const raycaster = Raycaster.init(15, 10);

    const renderer = Renderer{
        .allocator = allocator,
        .sdl_screen = sdl_screen,
        .sdl_renderer = sdl_renderer,
        .sdl_surface = sdl_surface,
        .sdl_texture = sdl_texture,
        .textures = textures,
        .raycaster = raycaster,
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

fn resetBuffer(self: *Renderer) void {
    std.mem.copyForwards(u32, self.screen_buffer, self.back_buffer);
}

pub fn render(self: *Renderer, delta: f32, player: *Player, game_map: *GameMap) void {
    const fps = @as(i32, @intFromFloat(1 / delta));
    const fps_string = std.fmt.bufPrintZ(self.string_buffer, "fps : {d}", .{fps}) catch |err| {
        std.debug.print("Failed to allocate string: {any}\n", .{err});
        return;
    };
    sdl_wrapper.setWindowTitle(self.sdl_screen, fps_string);
    self.resetBuffer();

    //render logic here
    const playerZ = @as(i32, @intFromFloat(player.z));
    self._renderColumns(player, game_map, playerZ);

    self.updateBuffer();

    self.refreshScreen();
}

fn _renderColumns(self: *Renderer, player: *Player, map: *GameMap, playerZ: i32) void {
    var x: u32 = 0;
    while (x < self.resolution) : (x += 1) {
        const rayResult = self.raycaster.cast(player, self.cameraX[x], map, playerZ);
        self._drawRay(rayResult, x, player, playerZ);
    }
}

fn _drawRay(self: *Renderer, rayResult: []Raycaster.RayStepResult, x: u32, player: *Player, playerZ: i32) void {
    if (rayResult.len == 0) return;

    const fHeight: f32 = @floatFromInt(self.height);
    var i: usize = rayResult.len - 1;
    while (i > 0) : (i -= 1) {
        const hit = rayResult[i];
        if (hit.frontDistance == 0) continue;

        const zOffset: f32 = @as(f32, @floatFromInt(hit.zLevel - playerZ));
        const zRest: f32 = player.z - @as(f32, @floatFromInt(playerZ));

        const verticalAdjustement: f32 = fHeight * @tan(player.pitch);

        const cellHeight: f32 = fHeight / hit.frontDistance;
        const cellTop: f32 = (((fHeight + cellHeight) / 2) - cellHeight) + (cellHeight * -zOffset) + (cellHeight * zRest) + verticalAdjustement;

        if (hit.backDistance != 0) {
            const backCellHeight: f32 = fHeight / hit.backDistance;
            const backCellTop: f32 = (((fHeight + backCellHeight) / 2) - backCellHeight) + (backCellHeight * -zOffset) + (backCellHeight * zRest) + verticalAdjustement;

            if (zOffset >= 0) {
                if (hit.ceilingInfos) |ceilingInfos| {
                    self._drawTexturedColumn(x, backCellTop, cellTop - backCellTop, hit.frontDistance, ceilingInfos.floor_texture, hit.backOffset, 1, ceilingInfos.floor_tint);
                }
            }

            if (zOffset <= 0) {
                if (hit.cellInfos) |cellInfos| {
                    //draw floor
                    if (cellInfos.floor_texture != 0 and (cellInfos.wall_texture == 0 or hit.floorOnly)) {
                        self._drawTexturedColumn(x, cellTop + cellHeight, (backCellTop + backCellHeight) - (cellTop + cellHeight), hit.frontDistance, cellInfos.floor_texture, hit.backOffset, 0, cellInfos.floor_tint);
                    }

                    //draw top face
                    if (cellInfos.heightRatio < 1) {
                        const blockHeight: f32 = cellHeight * cellInfos.heightRatio;
                        const blockTop: f32 = cellTop + (cellHeight - blockHeight);

                        const backBlockHeight: f32 = backCellHeight * cellInfos.heightRatio;
                        const backBlockTop: f32 = backCellTop + (backCellHeight - backBlockHeight);

                        // this._drawWireframeColumn(x, backBlockTop, blockTop - backBlockTop, hit.distance, COLORS.gray, 0);
                        self._drawTexturedColumn(x, backBlockTop, blockTop - backBlockTop, hit.frontDistance, cellInfos.wall_texture, hit.backOffset, 0, cellInfos.wall_tint);
                    }
                }

                if (hit.water != 0) {
                    //water top face
                    const blockHeight = cellHeight * (0.12 * @as(f32, @floatFromInt(hit.water)));
                    const blockTop = cellTop + (cellHeight - blockHeight);

                    const backBlockHeight = backCellHeight * (0.12 * @as(f32, @floatFromInt(hit.water)));
                    const backBlockTop = backCellTop + (backCellHeight - backBlockHeight);
                    self._drawWater(x, backBlockTop, blockTop - backBlockTop, hit.frontDistance, hit.frontSide);
                }
            }
        }

        if (hit.cellInfos) |cellInfos| {
            //draw normal wall
            if (cellInfos.wall_texture != 0 and cellInfos.thin_wall == 0 and !hit.floorOnly) {
                if (zOffset == 0) {
                    self.Zbuffer[x] = hit.frontDistance;
                }
                const blockHeight = cellHeight * cellInfos.heightRatio;
                const blockTop = cellTop + (cellHeight - blockHeight);
                self._drawTexturedColumn(x, blockTop, blockHeight, hit.frontDistance, cellInfos.wall_texture, hit.frontOffset, hit.frontSide, cellInfos.wall_tint);
            }
            if (hit.water != 0) {
                //water front face
                const blockHeight = cellHeight * (0.12 * @as(f32, @floatFromInt(hit.water)));
                const blockTop = cellTop + (cellHeight - blockHeight);
                self._drawWater(x, blockTop, blockHeight, hit.frontDistance, hit.frontSide);
            }
            //draw thin wall
            if (cellInfos.thin_wall != 0 and hit.thinDistance != 0) {
                if (zOffset == 0) {
                    self.Zbuffer[x] = hit.thinDistance;
                }
                const cellThinHeight: f32 = fHeight / hit.thinDistance;
                const cellThinTop: f32 = (((fHeight + cellThinHeight) / 2) - cellThinHeight) + (cellThinHeight * -zOffset) + (cellThinHeight * zRest) + verticalAdjustement;
                const blockHeight: f32 = cellThinHeight * cellInfos.heightRatio;
                const blockTop: f32 = cellThinTop + (cellThinHeight - blockHeight);
                std.log.debug("block top and such {d} {d} {d} {d}", .{ blockTop, blockHeight, cellThinTop, cellThinHeight });
                self._drawTexturedColumn(x, blockTop, blockHeight, hit.thinDistance, cellInfos.thin_wall, hit.thinOffset, hit.thinSide, cellInfos.wall_tint);
            }
        }
    }
}

fn _drawSpriteSlice(self: *Renderer, x: u32, y: u32, textureIndex: u32, width: u32, height: u32) void {
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

fn _drawWater(self: *Renderer, x: u32, top: f32, height: f32, distance: f32, side: u8) void {
    self._drawSidedColoredColumn(x, top, height, distance, side, 0x0000ff);
}

fn _drawSidedColoredColumn(self: *Renderer, x: u32, top: f32, height: f32, distance: f32, side: u8, color: u32) void {
    var newColor = color;
    if (side == 1) {
        newColor = (newColor >> 1) & 0x7f7f7f;
    }
    self._drawColoredColumn(x, top, height, distance, newColor);
}

fn _drawColoredColumn(self: *Renderer, x: u32, top: f32, height: f32, distance: f32, color: u32) void {
    //std.log.debug("colored column ? {d} {d} {d}", .{ x, top, height });
    if (height <= 0 or top <= 0) return;

    const safeTop: u32 = @intFromFloat(top);
    const safeHeight: u32 = @intFromFloat(height);

    var currentX = x * self.spacing;
    const shadeTint = 0x010101 * @as(u32, @intFromFloat(distance * 0.1));
    const shadedColor = mergePixels(color, shadeTint);

    while (currentX < (x + 1) * self.spacing) : (currentX += 1) {
        var currentY = safeTop;
        while (currentY <= safeTop + safeHeight) : (currentY += 1) {
            self.screen_buffer[currentX + currentY * self.width] = mergePixels(self.screen_buffer[currentX + currentY * self.width], shadedColor);
        }
    }
}

fn _drawTexturedColumn(self: *Renderer, x: u32, top: f32, height: f32, distance: f32, textureIndex: u32, textureOffset: f32, side: u8, tint: u32) void {
    //std.log.debug("textured colmun ? {d} {d} {d}", .{ distance, textureIndex, textureOffset });
    _ = distance;
    _ = side;
    _ = tint;

    const texture = self.textures[textureIndex];
    const safeTop: i32 = @intFromFloat(top);

    const texX: u32 = @intFromFloat(textureOffset * @as(f32, @floatFromInt(texture.width - 1)));

    var currentX: u32 = 0;
    while ((x * self.spacing) + currentX < (x + 1) * self.spacing) : (currentX += 1) {
        var currentY: i32 = @intFromFloat(height);
        const dir: i8 = if (currentY < 0) 1 else -1;
        while (currentY != 0) : (currentY += dir) {
            const index: i32 = @as(i32, @intCast(x * self.spacing + currentX)) + (safeTop + currentY) * @as(i32, @intCast(self.width));
            if (index < 0 or index >= self.width * self.height) {
                continue;
            }
            const texelYprojection = @as(f32, @floatFromInt(texture.height - 1)) * @abs((@as(f32, @floatFromInt(currentY))) / height);
            // std.log.debug("proj {d} {d} {d}", .{ texelYprojection, currentY, height });
            const texel = texture.data[(texX + currentX) + (@as(u32, @intFromFloat(texelYprojection)) * texture.width)];
            // var pixel = mergePixels(texel, tint);
            // const shadeTint = 0x010101 * @as(u32, @intFromFloat(distance * 0.1));
            // pixel = mergePixels(pixel, shadeTint);

            // if (side == 1) {
            //     pixel = (pixel >> 1) & 0x7f7f7f;
            // }

            self.screen_buffer[@intCast(index)] = mergePixels(self.screen_buffer[@intCast(index)], texel);
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
            buffer[index] = 0x000000;
        }
    }
}
