import vi;
import vi::kb;

const WIDTH = 770;
const HEIGHT = 350;

int n_lines = 100;

fn void draw(float dt) @export("draw") @wasm {
    // vi::clearBackground(Color { 8, 8, 18, 255 });

    // if (kb::isKeyDown(kb::ARROW_UP)) {
    //     n_lines += 1;
    // }
    // if (kb::isKeyDown(kb::ARROW_DOWN)) {
    //     if (n_lines > 1) {
    //         n_lines -= 1;
    //     }
    // }

    // int verticalDelta = HEIGHT / n_lines;
    // int horizontalDelta = WIDTH / n_lines;

    // for (int i = 0; i < n_lines; ++i) {
    //     vi::drawLine(i * horizontalDelta, 0, WIDTH - i * horizontalDelta, HEIGHT, Color { 236, 72, 153, 255 });
    //     vi::drawLine(0, i * verticalDelta, WIDTH, HEIGHT - i * verticalDelta, Color { 236, 72, 153, 255 });
    // }

    for (int i = 0; i < WIDTH; ++i) {
        vi::drawLine(i, 0, WIDTH - i, HEIGHT, Color { 150, (char)(i / 3.1 % 256), 100, 255 });
        if (i > 0 && i <= HEIGHT) {
            vi::drawLine(0, i, WIDTH, HEIGHT - i, Color { 150, (char)(i / 1.4 % 256), 100, 255 });
        }
    }

    vi::quit();
}

fn void main() @export("main") @wasm {
    vi::initWindow(WIDTH, HEIGHT);
}
