import vi;

const WIDTH = 800;
const HEIGHT = 600;

const HORIZON_POS = HEIGHT / 2;
const HORIZON_STEP = 100;
const NEAR_STEP = 200;

float offset = 0;

Canvas *sun;

fn void draw(float dt) @export("draw") @wasm { // TODO: implement skew algorithm to fake perspective
    vi::clearBackground(Color { 8, 8, 18, 255 });

    int n_lines = WIDTH / HORIZON_STEP;
    int near_start = (WIDTH / 2) - (WIDTH / 2 * NEAR_STEP / HORIZON_STEP);

    for (int i = 1; i < n_lines; ++i) {
        vi::drawLine(i * HORIZON_STEP, HORIZON_POS, near_start + i * NEAR_STEP, HEIGHT, Color { 236, 72, 153, 255 });
    }

    offset = (offset + dt * 100) % 50;

    int posY = HORIZON_POS;
    while (posY < HEIGHT) {
        vi::drawLine(0, posY + (int)offset, WIDTH, posY + (int)offset, Color { 236, 72, 153, 255 });
        posY += 50;
    }

    for (int i = -1; i <= 1; ++i) {
        vi::drawLine(0, HORIZON_POS + i, WIDTH, HORIZON_POS + i, Color { 236, 72, 153, 255 });
    }

    for (int i = WIDTH / 4 + 1; i < WIDTH / 4 * 3 - 1; ++i) {
        int topLeftX = WIDTH / 8 * 3 + 1;
        int topRightX = WIDTH / 8 * 5 - 1;
        if (i < topLeftX) {
            vi::drawLine(topLeftX, HORIZON_POS + 2, i, HEIGHT, Color { 8, 8, 18, 255 });
        } else if (i > topRightX) {
            vi::drawLine(topRightX, HORIZON_POS + 2, i, HEIGHT, Color { 8, 8, 18, 255 });
        } else {
            vi::drawLine(i, HORIZON_POS + 2, i, HEIGHT, Color { 8, 8, 18, 255 });
        }
    }

    vi::drawRectangle(0, 0, WIDTH, 299, Color { 18, 18, 36, 255 });
    vi::draw(sun, 0, 0, 401, 299, WIDTH / 2 - 200, 0);
}

fn void main() @export("main") @wasm {
    vi::initWindow(WIDTH, HEIGHT);

    sun = vi::newCanvas(401, 401);
    sun.drawCircle(200, 220, 180, Color { 200, 69, 69, 255 });
    sun.drawRectangle(0, 210, 401, 8, Color { 0, 0, 0, 0 });
    sun.drawRectangle(0, 225, 401, 8, Color { 0, 0, 0, 0 });
    sun.drawRectangle(0, 240, 401, 10, Color { 0, 0, 0, 0 });
    sun.drawRectangle(0, 260, 401, 5, Color { 0, 0, 0, 0 });
    sun.drawRectangle(0, 270, 401, 6, Color { 0, 0, 0, 0 });
    sun.drawRectangle(0, 285, 401, 8, Color { 0, 0, 0, 0 });
}
