// Based on Alexey Kutepov's https://github.com/tsoding/zozlib.js/blob/main/examples/tsoding_ball.c
import vi;

const WIDTH = 800;
const HEIGHT = 600;

const EMOJI_DATA = $embed("../assets/emoji.qoi");
const EMOJI_HIT_DATA = $embed("../assets/emoji-hit.qoi");
Canvas* emoji;


const float GRAVITY = 2000.0;

Vector2 ball_position = Vector2 { 0, 0 };
const Vector2 BALL_MAX_VELOCITY = Vector2 { 1050, 1050 };
Vector2 ball_velocity = Vector2 { 200, 200 };
float hitTime = 0;

fn void hit() {
	hitTime += 0.2f;
	emoji.populateWithImageData(EMOJI_HIT_DATA);
}
fn void heal() {
	emoji.populateWithImageData(EMOJI_DATA);
}

fn void draw(float dt) @export("draw") @wasm {
	if (hitTime > 0) {
		if (hitTime - dt <= 0) {
			heal();
		}
		hitTime = hitTime - dt;
	}
	vi::clearBackground(Color { 8, 8, 18, 255 });
	ball_velocity.y += GRAVITY * dt;
	if (ball_velocity.y > BALL_MAX_VELOCITY.y) {
		ball_velocity.y = BALL_MAX_VELOCITY.y;
	} else if (ball_velocity.y < -BALL_MAX_VELOCITY.y) {
		ball_velocity.y = -BALL_MAX_VELOCITY.y;
	}
	float x = ball_position.x + ball_velocity.x * dt;
	if (x < 0 || x + emoji.width >= WIDTH) {
		ball_velocity.x *= -1;
		hit();
	} else {
		ball_position.x = x;
	}
	float y = ball_position.y + ball_velocity.y * dt;
	if (y < 0 || y + emoji.height >= HEIGHT) {
		ball_velocity.y *= -1;
		hit();
	} else {
		ball_position.y = y;
	}
	vi::draw(emoji, 0, 0, emoji.width, emoji.height, (int)ball_position.x, (int)ball_position.y);
}

fn void main() @export("main") @wasm {
  ball_position = Vector2 { WIDTH / 2 - (float)emoji.width / 2, HEIGHT / 2 - (float)emoji.height / 2 };
	emoji = vi::newCanvasFromImageData(EMOJI_DATA);

	vi::initWindow(WIDTH, HEIGHT);
}
