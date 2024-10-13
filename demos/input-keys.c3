import vi;
import vi::kb;
import vi::js;

const WIDTH = 800;
const HEIGHT = 450;

Vector2 ball_position = Vector2 { WIDTH / 2, HEIGHT / 2 };

Canvas *canvas = null;

fn void draw() @export("draw") @wasm {
    if (kb::isKeyDown(kb::ARROW_RIGHT)) ball_position.x += 2.0f;
    if (kb::isKeyDown(kb::ARROW_LEFT)) ball_position.x -= 2.0f;
    if (kb::isKeyDown(kb::ARROW_UP)) ball_position.y -= 2.0f;
    if (kb::isKeyDown(kb::ARROW_DOWN)) ball_position.y += 2.0f;


    canvas.clearBackground(Color { 8, 8, 18, 255 });
    canvas.drawCircle((int)ball_position.x, (int)ball_position.y, 50, Color { 236, 72, 153, 255 });
    // canvas.drawText("move the ball with arrow keys", 10, 10, 20, Color { 255, 255, 255, 255 });
}

fn void main() @export("main") @wasm {
	canvas = vi::allocateCanvas(WIDTH, HEIGHT);
    canvas.beginDrawing();    
}