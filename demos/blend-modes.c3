import vi;

const WIDTH = 800;
const HEIGHT = 300;
const RECT_SIZE = 40;

Canvas *labels;
IntVector2 mouseCoords;

fn void draw(float dt) @export("draw") @wasm {
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
		vi::drawLine(WIDTH / 2, 0, WIDTH / 2, HEIGHT, (Color) { 0, 0, 0, 255});
		vi::drawLine(WIDTH / 2 - 1, 0, WIDTH / 2, HEIGHT, (Color) { 230, 230, 230, 255});
		vi::drawLine(WIDTH / 2 + 1, 0, WIDTH / 2, HEIGHT, (Color) { 230, 230, 230, 255});
		vi::mouse::getPosition(&mouseCoords);

		vi::setScissor((IntVector4) { WIDTH / 2, 0, WIDTH, HEIGHT});
		vi::setBlendMode(BlendMode.REPLACE);
		vi::drawCircle(mouseCoords.x, mouseCoords.y, 40, (Color) { 169, 169, 255, 200});
		vi::draw(labels, 0, 0, WIDTH, HEIGHT, 0, 0);

		vi::setScissor((IntVector4) { 0, 0, WIDTH / 2, HEIGHT});
		vi::setBlendMode(BlendMode.ALPHA);
		vi::drawCircle(mouseCoords.x, mouseCoords.y, 40, (Color) { 169, 169, 255, 200});
		vi::draw(labels, 0, 0, WIDTH, HEIGHT, 0, 0);

		vi::setScissor((IntVector4) { 0, 0, 0, 0});
}

fn void main() @export("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);
	labels = vi::newCanvas(WIDTH, HEIGHT);
	vi::js::setFont("16px VT323");
	labels.drawText("Alpha", 9, 31, (Color) { 0, 0, 0, 255 });
	labels.drawText("Alpha", 10, 30, (Color) { 255, 255, 255, 255 });
	labels.drawText("Replace", WIDTH / 2 + 9, 31, (Color) { 0, 0, 0, 255 });
	labels.drawText("Replace", WIDTH / 2 + 10, 30, (Color) { 255, 255, 255, 255 });
}