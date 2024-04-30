const std = @import("std");
const Allocator = std.mem.Allocator;
const MapCell = @import("game/MapLoader.zig").MapCell;
const Player = @import("game/Player.zig");
const GameMap = @import("game/GameMap.zig");

pub const CastStep = struct {
    step: u32 = 0,
    backDistance: f32 = 0.0,
    backOffset: f32 = 0.0,
    backSide: u8 = 0,
    thinDistance: f32 = 0.0,
    thinOffset: f32 = 0.0,
    thinSide: u8 = 0,
    frontDistance: f32 = 0.0,
    frontOffset: f32 = 0.0,
    frontSide: u8 = 0,
    cellInfos: ?*MapCell,
    ceilingInfos: ?*MapCell,
    water: u8 = 0,
    floorOnly: bool = false,
    zLevel: i32 = 0,
};

const RayStep = struct {
    step: u32 = 0,
    side: u8 = 0,
    sideDistX: f32 = 0.0,
    sideDistY: f32 = 0.0,
    mapX: i32 = 0,
    mapY: i32 = 0,
    stepX: i32 = 0,
    stepY: i32 = 0,
    deltaDistX: f32 = 0.0,
    deltaDistY: f32 = 0.0,
    rayDirX: f32 = 0.0,
    rayDirY: f32 = 0.0,
};

const Raycaster = @This();

range: u32,
zRange: u32,
nzRange: i32,
steps: [250]CastStep,
lastStep: u32,

pub fn init(range: u32, zRange: u32) Raycaster {
    const raycaster = Raycaster{
        .range = range,
        .zRange = zRange,
        .nzRange = 0 - @as(i32, @intCast(zRange)),
        .steps = [_]CastStep{undefined} ** 250,
        .lastStep = 0,
    };

    return raycaster;
}

pub fn cast(self: *Raycaster, player: *Player, cameraX: f32, map: *GameMap, zLevel: i32) []CastStep {
    self.lastStep = 0;
    self.steps = [_]CastStep{undefined} ** 250;

    var rayStep = RayStep{
        .side = 0,
        .sideDistX = 0.0,
        .sideDistY = 0.0,
        .mapX = 0,
        .mapY = 0,
        .deltaDistX = 0.0,
        .deltaDistY = 0.0,
        .rayDirX = 0.0,
        .rayDirY = 0.0,
    };

    rayStep.rayDirX = -player.dirX + player.planeX * cameraX;
    rayStep.rayDirY = -player.dirY + player.planeY * cameraX;

    //which box of the map we're in
    rayStep.mapX = @intFromFloat(player.x);
    rayStep.mapY = @intFromFloat(player.y);

    //length of ray from one x or y-side to next x or y-side
    rayStep.deltaDistX = (1 / @abs(rayStep.rayDirX));
    rayStep.deltaDistY = (1 / @abs(rayStep.rayDirY));

    //what direction to step in x or y-direction (either +1 or -1)
    rayStep.stepX = 0;
    rayStep.stepY = 0;

    //calculate step and initial sideDist
    if (rayStep.rayDirX < 0) {
        rayStep.stepX = -1;
        rayStep.sideDistX = (player.x - @as(f32, @floatFromInt(rayStep.mapX))) * rayStep.deltaDistX;
    } else {
        rayStep.stepX = 1;
        rayStep.sideDistX = (@as(f32, @floatFromInt(rayStep.mapX)) + 1 - player.x) * rayStep.deltaDistX;
    }

    if (rayStep.rayDirY < 0) {
        rayStep.stepY = -1;
        rayStep.sideDistY = (player.y - @as(f32, @floatFromInt(rayStep.mapY))) * rayStep.deltaDistY;
    } else {
        rayStep.stepY = 1;
        rayStep.sideDistY = (@as(f32, @floatFromInt(rayStep.mapY)) + 1 - player.y) * rayStep.deltaDistY;
    }

    self._startRay(player, &rayStep, zLevel, map, 0);
    return self.steps[0..self.lastStep];
}

fn _startRay(self: *Raycaster, player: *Player, rayStep: *RayStep, zLevel: i32, map: *GameMap, zOffset: i32) void {
    var registerBackWall = false;
    var alreadyLookedDown = false;
    var alreadyLookedUp = false;
    // const delayedRays = [_]DelayedRay{undefined} ** 20;

    while (rayStep.step <= self.range) : (rayStep.step += 1) {
        //jump to next map square, either in x-direction, or in y-direction
        if (rayStep.sideDistX < rayStep.sideDistY) {
            rayStep.sideDistX += rayStep.deltaDistX;

            rayStep.mapX += @intCast(rayStep.stepX);
            rayStep.side = 0;
        } else {
            rayStep.sideDistY += rayStep.deltaDistY;
            rayStep.mapY += rayStep.stepY;
            rayStep.side = 1;
        }

        if (registerBackWall) {
            _backWall(&self.steps[self.lastStep - 1], player, rayStep);
            registerBackWall = false;
        }

        const stepInfos = self._nextStep() orelse {
            std.log.debug("no more step !!! {d}", .{self.lastStep});
            break;
        };

        var perpWallDist: f32 = 0.0;
        var wallX: f32 = 0; //where exactly the wall was hit

        if (rayStep.side == 0) {
            perpWallDist = (rayStep.sideDistX - rayStep.deltaDistX);
            wallX = player.y + perpWallDist * rayStep.rayDirY;
        } else {
            perpWallDist = (rayStep.sideDistY - rayStep.deltaDistY);
            wallX = player.x + perpWallDist * rayStep.rayDirX;
        }

        stepInfos.frontDistance = perpWallDist;
        stepInfos.frontOffset = wallX - @floor(wallX);
        stepInfos.frontSide = rayStep.side;
        stepInfos.zLevel = zLevel;
        stepInfos.cellInfos = null;

        const cellInfos = map.getCellInfos(rayStep.mapX, rayStep.mapY, @intCast(zLevel)) catch {
            break;
        };

        stepInfos.water = cellInfos.water;
        //Check if ray has hit a wall
        if (cellInfos.floor_texture != 0 or cellInfos.wall_texture != 0) {
            stepInfos.cellInfos = cellInfos;

            if (cellInfos.thin_wall != 0) {
                _thinWall(stepInfos, player, rayStep);
            }

            registerBackWall = true;
        } else {
            const underLevel: i32 = @as(i32, @intCast(zLevel)) - 1;
            if (map.getCellInfos(rayStep.mapX, rayStep.mapY, underLevel)) |undercellInfos| {
                if (undercellInfos.wall_texture != 0 and undercellInfos.heightRatio == 1) {
                    stepInfos.cellInfos = undercellInfos;
                    stepInfos.floorOnly = true;
                    alreadyLookedDown = false;
                    registerBackWall = true;
                } else {
                    if (zOffset <= 0 and zOffset > self.nzRange and !alreadyLookedDown) {
                        registerBackWall = true;

                        //delayedRay.push([player, mapX, mapY, sideDistX, sideDistY, deltaDistX, deltaDistY, stepX, stepY, side, rayDirX, rayDirY, zLevel-1, map, zOffset-1, step]);

                        alreadyLookedDown = true;
                    }
                }
            } else |_| {
                //std.log.debug("hors map {d}", .{underLevel});
            }
        }

        if (map.getCellInfos(rayStep.mapX, rayStep.mapY, @intCast(zLevel + 1))) |overcellInfos| {
            if (overcellInfos.floor_texture != 0) {
                stepInfos.ceilingInfos = overcellInfos;
                registerBackWall = true;
                alreadyLookedUp = false;
            } else {
                if (zOffset >= 0 and zOffset < self.zRange and !alreadyLookedUp) {
                    registerBackWall = true;
                    //delayedRay.push([player, mapX, mapY, sideDistX, sideDistY, deltaDistX, deltaDistY, stepX, stepY, side, rayDirX, rayDirY, zLevel+1, map, zOffset+1, step]);
                    // this._startRay(player, mapX, mapY, sideDistX, sideDistY, deltaDistX, deltaDistY, stepX, stepY, side, rayDirX, rayDirY, zLevel+1, map, this.range, step)
                    alreadyLookedUp = true;
                }
            }
        } else |_| {
            //std.log.debug("hors map {d}", .{zLevel + 1});
        }
    }

    //start delayed rays
}

fn _backWall(step: *CastStep, player: *Player, rayStep: *RayStep) void {
    var perpWallDist: f32 = 0.0;
    var wallX: f32 = 0.0; //where exactly the wall was hit
    if (rayStep.side == 0) {
        perpWallDist = (rayStep.sideDistX - rayStep.deltaDistX);
        wallX = player.y + perpWallDist * rayStep.rayDirY;
    } else {
        perpWallDist = (rayStep.sideDistY - rayStep.deltaDistY);
        wallX = player.x + perpWallDist * rayStep.rayDirX;
    }
    step.backDistance = perpWallDist;
    step.backOffset = wallX - @floor(wallX);
    step.backSide = rayStep.side;
}

fn _thinWall(step: *CastStep, player: *Player, rayStep: *RayStep) void {
    var perpWallDist: f32 = 0.0;
    var wallX: f32 = 0.0; //where exactly the wall was hit
    if (rayStep.side == 1) {
        const wallYOffset: f32 = 0.5 * @as(f32, @floatFromInt(rayStep.stepY));
        perpWallDist = (@as(f32, @floatFromInt(rayStep.mapY)) - player.y + wallYOffset + (1.0 - @as(f32, @floatFromInt(rayStep.stepY))) / 2.0) / rayStep.rayDirY;
        wallX = player.x + perpWallDist * rayStep.rayDirX;
        if (rayStep.sideDistY - (rayStep.deltaDistY / 2) < rayStep.sideDistX) { //If ray hits offset wall
            step.thinDistance = perpWallDist;
            step.thinOffset = wallX - @floor(wallX);
            step.thinSide = rayStep.side;
        }
    } else { //side == 0
        const wallXOffset = 0.5 * @as(f32, @floatFromInt(rayStep.stepX));
        perpWallDist = (@as(f32, @floatFromInt(rayStep.mapX)) - player.x + wallXOffset + (1.0 - @as(f32, @floatFromInt(rayStep.stepX))) / 2.0) / rayStep.rayDirX;
        wallX = player.y + perpWallDist * rayStep.rayDirY;
        if (rayStep.sideDistX - (rayStep.deltaDistX / 2) < rayStep.sideDistY) {
            step.thinDistance = perpWallDist;
            step.thinOffset = wallX - @floor(wallX);
            step.thinSide = rayStep.side;
        }
    }
}

fn _nextStep(self: *Raycaster) ?*CastStep {
    if (self.lastStep >= 250) {
        return null;
    }

    const step: ?*CastStep = &self.steps[self.lastStep];
    self.lastStep += 1;

    return step;
}
