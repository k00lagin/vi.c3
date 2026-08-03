import vi;

const WIDTH = 800;
const HEIGHT = 300;
const RECT_SIZE = 40;
const COLUMN = WIDTH / 4;

Canvas *labels;
IntVector2 mouseCoords;
bool labelsDrawn = false;

BlendMode[4] modes = { BlendMode.ALPHA, BlendMode.REPLACE, BlendMode.ADD, BlendMode.MULTIPLY };

fn void drawLabel(char *text, int column) {
	labels.drawText(text, column * COLUMN + 9, 31, (Color) { 0, 0, 0, 255 });
	labels.drawText(text, column * COLUMN + 10, 30, (Color) { 255, 255, 255, 255 });
}

fn void draw(float dt) @export("draw") @wasm {
		if (!labelsDrawn && vi::isFontReady()) {
			drawLabel("Alpha", 0);
			drawLabel("Replace", 1);
			drawLabel("Add", 2);
			drawLabel("Multiply", 3);
			labelsDrawn = true;
		}

		for (usz x = 0; x <= WIDTH / RECT_SIZE; ++x) {
			for (usz y = 0; y <= HEIGHT / RECT_SIZE; ++y) {
				if ((x + y) % 2) {
					vi::drawRectangle(x * RECT_SIZE, y * RECT_SIZE, RECT_SIZE, RECT_SIZE, (Color) { 255, 186, 85, 255 });
				} else {
					vi::drawRectangle(x * RECT_SIZE, y * RECT_SIZE, RECT_SIZE, RECT_SIZE, (Color) { 29, 209, 133, 255 });
				}
				vi::drawRectangleLines(x * RECT_SIZE, y * RECT_SIZE, RECT_SIZE, RECT_SIZE, (Color) { 169, 21, 127, 255 });
			}
		}

		// One circle per column at the same offset, so every mode reacts to the
		// same move at once and can be compared side by side.
		vi::mouse::getPosition(&mouseCoords);
		int localX = mouseCoords.x % COLUMN;
		for (int i = 0; i < 4; ++i) {
			vi::setScissor((IntVector4) { i * COLUMN, 0, COLUMN, HEIGHT });
			vi::setBlendMode(modes[i]);
			vi::drawCircle(i * COLUMN + localX, mouseCoords.y, 40, (Color) { 169, 169, 255, 200 });
		}
		vi::unsetScissor();
		vi::setBlendMode(BlendMode.ALPHA);

		for (int i = 1; i < 4; ++i) {
			vi::drawLineEx(i * COLUMN, 0, i * COLUMN, HEIGHT, 3, (Color) { 230, 230, 230, 255 });
		}

		vi::draw(labels, 0, 0, WIDTH, HEIGHT, 0, 0);
}

fn void main() @export("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);
	labels = vi::newCanvas(WIDTH, HEIGHT);
	vi::setFontChars("VT323", 16, "AlphaReplcdMutiy");
}
