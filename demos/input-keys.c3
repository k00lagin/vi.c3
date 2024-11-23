import vi;
import vi::kb;

const WIDTH = 800;
const HEIGHT = 450;

Vector2 ball_position = Vector2 { WIDTH / 2, HEIGHT / 2 };

fn void draw() @export("draw") @wasm {
    if (kb::isKeyDown("ArrowRight")) ball_position.x += 2.0f;
    if (kb::isKeyDown("ArrowLeft")) ball_position.x -= 2.0f;
    if (kb::isKeyDown("ArrowUp")) ball_position.y -= 2.0f;
    if (kb::isKeyDown("ArrowDown")) ball_position.y += 2.0f;

    vi::clearBackground(Color { 8, 8, 18, 255 });
    vi::drawCircle((int)ball_position.x, (int)ball_position.y, 50, Color { 236, 72, 153, 255 });
    vi::drawText("move the ball with arrow keys", 10, 30, Color { 230, 200, 200, 255 });
}

fn void main() @export("main") @wasm {
	vi::initWindow(WIDTH, HEIGHT);
    vi::js::setFont("20px VT323");
}