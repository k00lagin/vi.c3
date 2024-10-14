import vi;

const WIDTH = 800;
const HEIGHT = 600;

const HORIZON_POS = HEIGHT / 2;
const HORIZON_STEP = 100;
const NEAR_STEP = 200;

float offset = 0;

fn void draw(float dt) @export("draw") @wasm {
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
        posY += 50; // TODO: introduce perspective
    }

    for (int i = -1; i <= 1; ++i) {
        vi::drawLine(0, HORIZON_POS + i, WIDTH, HORIZON_POS + i, Color { 236, 72, 153, 255 });
    }
}

fn void main() @export("main") @wasm {
    vi::initWindow(WIDTH, HEIGHT);
}

