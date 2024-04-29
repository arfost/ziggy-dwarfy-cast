const std = @import("std");

const Position = struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const Player = @This();

x: f32,
y: f32,
z: f32,
lastValidPosition: Position,
dirX: f32,
dirY: f32,
planeX: f32,
planeY: f32,
pitch: f32,
paces: f32 = 0.0,

pub fn init(x: f32, y: f32, z: f32) Player {
    const player = Player{
        .x = x,
        .y = y,
        .z = z,
        .lastValidPosition = Position{ .x = x, .y = y, .z = z },
        .dirX = -1.0,
        .dirY = 0.0,
        .planeX = 0.0,
        .planeY = 0.66,
        .pitch = 0.0,
    };

    return player;
}

pub fn turn(self: *Player, angle: f32) void {
    const oldDirX = self.dirX;
    self.dirX = self.dirX * @cos(-angle) - self.dirY * @sin(-angle);
    self.dirY = oldDirX * @sin(-angle) + self.dirY * @cos(-angle);

    const oldPlaneX = self.planeX;
    self.planeX = self.planeX * @cos(-angle) - self.planeY * @sin(-angle);
    self.planeY = oldPlaneX * @sin(-angle) + self.planeY * @cos(-angle);
}

pub fn pitchChange(self: *Player, angle: f32) void {
    self.pitch += angle;
    if (self.pitch > 0.5) {
        self.pitch = 0.5;
    } else if (self.pitch < -0.5) {
        self.pitch = -0.5;
    }
}

pub fn fly(self: *Player, distance: f32) void {
    self.z += distance;
}

pub fn walk(self: *Player, distance: f32) void {
    // var dx = Math.cos(this.direction) * distance;
    // var dy = Math.sin(this.direction) * distance;
    // this.x += dx;
    // this.y += dy;
    self.x += self.dirX * distance;
    self.y += self.dirY * distance;
    self.paces += distance;
}

pub fn strafe(self: *Player, distance: f32) void {
    // var dx = Math.cos(this.direction + Math.PI/2) * distance;
    // var dy = Math.sin(this.direction + Math.PI/2) * distance;
    // this.x += dx;
    // this.y += dy;
    self.x += self.planeX * distance;
    self.y += self.planeY * distance;
    self.paces += distance;
}
