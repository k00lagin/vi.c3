import vi;

const WIDTH = 400;
const HEIGHT = 400;

Canvas *gradientTriangle;
Canvas *gradientCircle;

fn void draw(float dt) @export("draw") @wasm {
	vi::drawTriangleLines(100, 60, 340, 190, 55, 295, (Color) { 80, 200, 255, 255 });
	vi::drawTriangleLines(101, 60, 341, 190, 56, 295, (Color) { 80, 200, 255, 255 });
	vi::drawTriangleLines(100, 61, 340, 191, 55, 296, (Color) { 80, 200, 255, 255 });
	vi::drawTriangleLines(101, 61, 341, 191, 56, 296, (Color) { 80, 200, 255, 255 });

	vi::draw(gradientTriangle, 0, 0, WIDTH, HEIGHT, 0, 0);
	vi::drawTriangle(55, 100, 330, 110, 120, 330, (Color) { 8, 8, 18, 255 });
	vi::drawTriangleLines(55, 100, 330, 110, 120, 330, (Color) { 255, 50, 255, 255 });
	vi::drawTriangleLines(55, 100, 331, 110, 121, 330, (Color) { 255, 50, 255, 255 });
	vi::drawTriangleLines(55, 101, 330, 111, 120, 331, (Color) { 255, 50, 255, 255 });
	vi::drawTriangleLines(56, 101, 331, 111, 121, 331, (Color) { 255, 50, 255, 255 });

	vi::draw(gradientCircle, 0, 0, WIDTH, HEIGHT, 0, 0);

	vi::quit();
}

fn void main() @export("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);

	gradientTriangle = vi::newCanvas(WIDTH, HEIGHT);
	for (int i = 0; i < WIDTH; ++i) {
		gradientTriangle.drawLine(i, 0, i, HEIGHT, (Color) { (char)(80 + i / 2.2), (char)(200 - i / 2), 255, 255 }); // 255, 50, 255 
	}
	Canvas *triangleMask = vi::newCanvas(WIDTH, HEIGHT);
	triangleMask.drawTriangle(70, 75, 335, 150, 80, 315, (Color) { 255, 255, 255, 255 });
	triangleMask.mask(gradientTriangle, 0, 0, WIDTH, HEIGHT, 0, 0);

	gradientCircle = vi::newCanvas(WIDTH, HEIGHT);
  for (int i = 0; i < WIDTH; ++i) { // 255, 186, 85
      gradientCircle.drawLine(0, i, WIDTH, i, (Color) { 255, (char)(186 - i / 2.2), 100, 255 });
  }
	Canvas *circleMask = vi::newCanvas(WIDTH, HEIGHT);
	circleMask.drawCircle(170, 170, 100, (Color) { 255, 255, 255, 255 });
	vi::setBlendMode(BlendMode.REPLACE);
	circleMask.drawRectangle(70, 170, 271, 2, (Color) { 0, 0, 0, 0 });
	circleMask.drawRectangle(70, 190, 271, 5, (Color) { 0, 0, 0, 0 });
	circleMask.drawRectangle(70, 210, 271, 7, (Color) { 0, 0, 0, 0 });
	circleMask.drawRectangle(70, 240, 271, 10, (Color) { 0, 0, 0, 0 });
	circleMask.drawTriangle(56, 101, 120, 330, 0, HEIGHT, (Color) { 0, 0, 0, 0 }); //55, 100, 330, 110, 120, 330
	circleMask.drawTriangle(330, 110, 120, 330, WIDTH, HEIGHT / 2, (Color) { 0, 0, 0, 0 }); //55, 100, 330, 110, 120, 330	
	vi::setBlendMode(BlendMode.ALPHA);
	circleMask.mask(gradientCircle, 0, 0, WIDTH, HEIGHT, 0, 0);
}