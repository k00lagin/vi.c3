import vi;

const WIDTH = 800;
const HEIGHT = 600;

fn void draw(float dt) @export("draw") @wasm {
	vi::clearBackground((Color) { 8, 8, 18, 255 });
	vi::drawText("Hello, World!", 10, 120, (Color) { 255, 255, 255, 255 });
	vi::drawText("Привет, мир!", 10, 170, (Color) { 255, 180, 220, 255 });
}

fn void main() @export("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);
	vi::setFontChars("BoldPixels", 32, "Hello, World!Привет, мир!");
}
