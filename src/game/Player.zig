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
