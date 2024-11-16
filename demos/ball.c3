// Based on Alexey Kutepov's https://github.com/tsoding/zozlib.js/blob/main/examples/tsoding_ball.c
import vi;
import std::compression::qoi;

const WIDTH = 800;
const HEIGHT = 600;

const EMOJI_DATA = $embed("../assets/emoji.qoi");
const EMOJI_HIT_DATA = $embed("../assets/emoji-hit.qoi");
QOIDesc emojiDesc;
QOIDesc emojiHitDesc;
char[] emojiPixels;
char[] emojiHitPixels;
Canvas* emoji;


const float BALL_SIZE = 64.0;
const float GRAVITY = 2000.0;

Vector2 ball_position = Vector2 { 0, 0 };
const Vector2 BALL_MAX_VELOCITY = Vector2 { 1050, 1050 };
Vector2 ball_velocity = Vector2 { 200, 200 };
float hitTime = 0;

fn void hit() {
	hitTime += 0.2f;
	for (int i = 0; i < emojiHitDesc.width * emojiHitDesc.height; ++i) {
		emoji.putPixel(i % emojiHitDesc.width, i / emojiHitDesc.width, Color { emojiHitPixels[i*4], emojiHitPixels[i*4 + 1], emojiHitPixels[i*4 + 2], emojiHitPixels[i*4 + 3] });
	}
}
fn void heal() {
	for (int i = 0; i < emojiDesc.height * emojiDesc.height; ++i) {
		emoji.putPixel(i % emojiDesc.height, i / emojiDesc.height, Color { emojiPixels[i*4], emojiPixels[i*4 + 1], emojiPixels[i*4 + 2], emojiPixels[i*4 + 3] });
	}
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
	if (x < 0 || x + BALL_SIZE >= WIDTH) {
		ball_velocity.x *= -1;
		hit();
	} else {
		ball_position.x = x;
	}
	float y = ball_position.y + ball_velocity.y * dt;
	if (y < 0 || y + BALL_SIZE >= HEIGHT) {
		ball_velocity.y *= -1;
		hit();
	} else {
		ball_position.y = y;
	}
	vi::draw(emoji, 0, 0, emojiDesc.width, emojiDesc.height, (int)ball_position.x, (int)ball_position.y);
}

fn void main() @export("main") @wasm {
  ball_position = Vector2 { WIDTH / 2, HEIGHT / 2 };
	emojiPixels = qoi::decode(EMOJI_DATA, &emojiDesc) ?? (char[]){};
	emojiHitPixels = qoi::decode(EMOJI_HIT_DATA, &emojiHitDesc) ?? (char[]){};
	emoji = vi::newCanvas(emojiDesc.width, emojiDesc.height);
	for (int i = 0; i < emojiDesc.width * emojiDesc.height; ++i) {
		emoji.putPixel(i % emojiDesc.width, i / emojiDesc.width, Color { emojiPixels[i*4], emojiPixels[i*4 + 1], emojiPixels[i*4 + 2], emojiPixels[i*4 + 3] });
	}

	vi::initWindow(WIDTH, HEIGHT);
}
