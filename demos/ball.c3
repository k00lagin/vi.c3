// Based on Alexey Kutepov's https://github.com/tsoding/zozlib.js/blob/main/examples/tsoding_ball.c
import vi;

Canvas *canvas = null;

const WIDTH = 800;
const HEIGHT = 600;

const float BALL_RADIUS = 30.0;
const float GRAVITY = 2000.0;

Vector2 ball_position = Vector2 { 0, 0 };
Vector2 ball_velocity = Vector2 { 200, 200 };
Color ball_color;
float ball_hue;

fn void draw(float dt) @export("draw") @wasm {
	canvas.clearBackground(Color { 8, 8, 18, 255 });
	ball_velocity.y += GRAVITY * dt;
	float x = ball_position.x + ball_velocity.x * dt;
	if (x - BALL_RADIUS < 0 || x + BALL_RADIUS >= WIDTH) {
		ball_velocity.x *= -1;
		ball_hue += 10;
		ball_color = vi::hsvToRGB(ball_hue, 0.7, 0.55, 1);
	} else {
		ball_position.x = x;
	}
	float y = ball_position.y + ball_velocity.y * dt;
	if (y - BALL_RADIUS < 0 || y + BALL_RADIUS >= HEIGHT) {
		ball_velocity.y *= -1;
		ball_hue += 10;
		ball_color = vi::hsvToRGB(ball_hue, 0.7, 0.55, 1);
	} else {
		ball_position.y = y;
	}
	canvas.drawCircle((int)ball_position.x, (int)ball_position.y, BALL_RADIUS, ball_color);
}

fn void main() @export("main") @wasm {
    ball_position = Vector2 { WIDTH / 2, HEIGHT / 2 };
	ball_hue = js::getRandomValue(0, 360);
	ball_color = vi::hsvToRGB(ball_hue, 0.7, 0.55, 1);

	canvas = vi::allocateCanvas(WIDTH, HEIGHT);
    canvas.beginDrawing();
}
