module vi;

def Color = char[<4>];
def Vector2 = float[<2>];
def IntVector2 = int[<2>];

struct Canvas {
    usz width;
    usz height;
    Color[*] pixels;
}

fn Color hsvToRGB(float hue, float saturation, float value, float alpha) { // h: 0-360, s: 0-1, v: 0-1, a: 0-1
    char r, g, b;

    // Red channel
    float k = (5.0 + hue / 60.0) % 6;
    float t = 4.0 - k;
    k = (t < k)? t : k;
    k = (k < 1)? k : 1;
    k = (k > 0)? k : 0;
    r = (char)(((value - value*saturation*k)*255));

    // Green channel
    k = (3.0 + hue / 60.0) % 6;
    t = 4.0 - k;
    k = (t < k)? t : k;
    k = (k < 1)? k : 1;
    k = (k > 0)? k : 0;
    g = (char)(((value - value*saturation*k)*255));

    // Blue channel
    k = (1.0 + hue / 60.0) % 6;
    t = 4.0 - k;
    k = (t < k)? t : k;
    k = (k < 1)? k : 1;
    k = (k > 0)? k : 0;
    b = (char)(((value - value*saturation*k)*255));

    return Color { r, g, b, (char)(alpha * 255) };
}

fn Canvas *allocateCanvas(usz width, usz height) {
    Canvas *canvas = mem::calloc(Canvas.sizeof + width * height * Color.sizeof);
    canvas.width = width;
    canvas.height = height;
    for (usz i = 0; i < width * height; i++) {
        canvas.pixels[i] = Color { 0, 0, 0, 255 };
    }
    return canvas;
}

extern fn void Canvas.beginDrawing(&canvas) @export("beginDrawing") @wasm;
extern fn float Canvas.getFrameTime(&canvas) @export("getFrameTime") @wasm;

fn void Canvas.clearBackground(&canvas, Color color) {
    for (usz i = 0; i < canvas.width * canvas.height; i++) {
        canvas.pixels[i] = color;
    }
}

// Basic shapes drawing functions

// Draw a pixel
fn void Canvas.drawPixel(&canvas, int posX, int posY, Color color) {
    if (posX < 0 || posX >= canvas.width || posY < 0 || posY >= canvas.height) {
        return;
    }
    canvas.pixels[posY * canvas.width + posX] = color;
}

// Draw a pixel (Vector version)
fn void Canvas.drawPixelV(&canvas, IntVector2 position, Color color) {
    Canvas.drawPixel(canvas, position.x, position.y, color);
}

// Draw a color-filled circle
fn void Canvas.drawCircle(&canvas, int centerX, int centerY, float radius, Color color) {
    int x = 0;
    int y = (int)radius;
    int d = 3 - 2 * (int)radius;
    
    while (y >= x) {
        canvas.drawPixel(centerX + x, centerY + y, color);
        canvas.drawPixel(centerX - x, centerY + y, color);
        canvas.drawPixel(centerX + x, centerY - y, color);
        canvas.drawPixel(centerX - x, centerY - y, color);
        canvas.drawPixel(centerX + y, centerY + x, color);
        canvas.drawPixel(centerX - y, centerY + x, color);
        canvas.drawPixel(centerX + y, centerY - x, color);
        canvas.drawPixel(centerX - y, centerY - x, color);
        
        if (d < 0) {
            d += 4 * x + 6;
        } else {
            d += 4 * (x - y) + 10;
            y--;
        }
        x++;
    }
    
    for (int py = -1 * (int)radius; py <= (int)radius; ++py) {
        for (int px = -1 * (int)radius; px <= (int)radius; ++px) {
            if (px * px + py * py <= (int)radius * (int)radius) {
                canvas.drawPixel(centerX + px, centerY + py, color);
            }
        }
    }
}

// Draw a color-filled rectangle
fn void Canvas.drawRectangle(&canvas, int posX, int posY, int width, int height, Color color) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            canvas.drawPixel(posX + x, posY + y, color);
        }
    }
}

// Draw a color-filled rectangle (Vector version)
fn void Canvas.drawRectangleV(&canvas, IntVector2 position, IntVector2 size, Color color) {
    Canvas.drawRectangle(canvas, position.x, position.y, size.x, size.y, color);
}

// Draw rectangle outline
fn void Canvas.drawRectangleLines(&canvas, int posX, int posY, int width, int height, Color color) {
    for (int y = 0; y < height; ++y) {
        canvas.drawPixel(posX, posY + y, color);
        canvas.drawPixel(posX + width - 1, posY + y, color);
    }
    for (int x = 0; x < width; ++x) {
        canvas.drawPixel(posX + x, posY, color);
        canvas.drawPixel(posX + x, posY + height - 1, color);
    }
}

module vi::kb;

const ARROW_RIGHT = 39;
const ARROW_LEFT = 37;
const ARROW_UP = 38;
const ARROW_DOWN = 40;

extern fn bool isKeyDown(char key) @export("isKeyDown") @wasm;

module vi::js;

extern fn float getRandomValue(int min, int max) @export("getRandomValue") @wasm;
