import vi;

const WIDTH = 360 * 2;
const HEIGHT = 400;

fn void draw(float dt) @extern("draw") @wasm {
	for (int i = 0; i < WIDTH; ++i) {
		vi::drawLine(i, 0, i, HEIGHT, vi::oklchToRGB(Oklch { 0.8f, 0.75f, (float)i / 2, 1.0f }));
	}

	vi::quit();
}

fn void main() @extern("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);
}