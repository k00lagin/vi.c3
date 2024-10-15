import vi;

const IMG_SIZE = 600;

fn void draw(float dt) @export("draw") @wasm {
    for (int i = 0; i < IMG_SIZE; ++i) {
        vi::drawLine(i, 0, IMG_SIZE - i, IMG_SIZE, Color { 200, 100, (char)(i / 3.1 % 256),255 });
        vi::drawLine(0, i, IMG_SIZE, IMG_SIZE - i, Color { 200, 100, (char)(i / 3.1 % 256),255 });
    }

    vi::quit();
}

fn void main() @export("main") @wasm {
    vi::initWindow(IMG_SIZE, IMG_SIZE);
}
