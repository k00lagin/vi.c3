module vi;

import std::math;
import std::core::string;

def Color = char[<4>];
def Vector2 = float[<2>];
def IntVector2 = int[<2>];
def Vector4 = float[<4>];
def IntVector4 = int[<4>];

/*
    // C3 implementation of swap macro
    // looks fine, but not working for some reason in my particular case
    // macro void @swap(&x, &y)
    // {
    // 	var t = *x;
    // 	*x = *y;
    // 	*y = t;
    // }
*/

fn void swap(int* x, int* y) {
    int t = *x;
    *x = *y;
    *y = t;
}

enum BlendMode : uint {
    ALPHA,
    REPLACE
}
BlendMode currentBlendMode = BlendMode.ALPHA;

struct Canvas {
    usz width;
    usz height;
    Color[*] pixels;
}
Canvas *defaultCanvas;
Canvas *currentCanvas;

extern fn void connectCanvas(Canvas *canvas) @export("connectCanvas") @wasm;
fn Canvas *initWindow(usz width, usz height) {
    defaultCanvas = newCanvas(width, height);
    currentCanvas = defaultCanvas;
    connectCanvas(defaultCanvas);
    return defaultCanvas;
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

fn Canvas *newCanvas(usz width, usz height) {
    Canvas *canvas = mem::calloc(Canvas.sizeof + width * height * Color.sizeof);
    canvas.width = width;
    canvas.height = height;
    for (usz i = 0; i < width * height; i++) {
        canvas.pixels[i] = Color { 0, 0, 0, 0 };
    }
    return canvas;
}

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
    if (currentBlendMode == BlendMode.ALPHA && color.a < 255) {
        Color pixel = canvas.pixels[posY * canvas.width + posX];
        canvas.pixels[posY * canvas.width + posX] = Color {
            (char)((color.r * color.a + pixel.r * (255 - color.a)) / 255),
            (char)((color.g * color.a + pixel.g * (255 - color.a)) / 255),
            (char)((color.b * color.a + pixel.b * (255 - color.a)) / 255),
            (char)((color.a * 255 + pixel.a * (255 - color.a)) / 255)
        };
    } else {
        canvas.pixels[posY * canvas.width + posX] = color;
    }
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

// Draw a line
fn void Canvas.drawLine(&canvas, int x1, int y1, int x2, int y2, Color color) @export("drawLine") @wasm {
    int dx = x2 - x1;
    int dy = y2 - y1;

    // If both of the differences are 0 there will be a division by 0 below.
    if (dx == 0 && dy == 0) {
        canvas.drawPixel(x1, y1, color);
        return;
    }

    if (math::abs(dx) > math::abs(dy)) {
        if (x1 > x2) {
            swap(&x1, &x2);
            swap(&y1, &y2);
        }

        for (int x = x1; x <= x2; ++x) {
            int y = dy*(x - x1)/dx + y1;
            // TODO: move boundary checks out side of the loops in olivec_draw_line
            canvas.drawPixel(x, y, color);
        }
    } else {
        if (y1 > y2) {
            swap(&x1, &x2);
            swap(&y1, &y2);
        }

        for (int y = y1; y <= y2; ++y) {
            int x = dx*(y - y1)/dy + x1;
            // TODO: move boundary checks out side of the loops in olivec_draw_line
            canvas.drawPixel(x, y, color);
        }
    }
}

fn void Canvas.drawText(&canvas, char *text, int posX, int posY, int fontSize, Color color) {
    vi::js::drawText(canvas,text, posX, posY, fontSize, &color);
}

fn void Canvas.draw(&canvas, Canvas *target, int sourceX, int sourceY, int width, int height, int targetX, int targetY) {
    for (int x = 0; x < math::min(width, canvas.width - sourceX); ++x) {
        for (int y = 0; y < math::min(height, canvas.height - sourceY); ++y) {
            Color pixel = canvas.pixels[(sourceY + y) * canvas.width + (sourceX + x)];
            if (pixel.a > 0) {
                target.drawPixel(targetX + x, targetY + y, pixel);
            }
        }
    }
}

fn void clearBackground(Color color) { Canvas.clearBackground(currentCanvas, color); }
fn void drawPixel(int x, int y, Color color) { Canvas.drawPixel(currentCanvas, x, y, color); }
fn void drawPixelV(IntVector2 position, Color color) { Canvas.drawPixelV(currentCanvas, position, color); }
fn void drawCircle(int centerX, int centerY, float radius, Color color) { Canvas.drawCircle(currentCanvas, centerX, centerY, radius, color); }
fn void drawRectangle(int posX, int posY, int width, int height, Color color) { Canvas.drawRectangle(currentCanvas, posX, posY, width, height, color); }
fn void drawRectangleV(IntVector2 position, IntVector2 size, Color color) { Canvas.drawRectangleV(currentCanvas, position, size, color); }
fn void drawRectangleLines(int posX, int posY, int width, int height, Color color) { Canvas.drawRectangleLines(currentCanvas, posX, posY, width, height, color); }
fn void drawLine(int x1, int y1, int x2, int y2, Color color) { Canvas.drawLine(currentCanvas, x1, y1, x2, y2, color); }
fn void drawText(char *text, int posX, int posY, int fontSize, Color color) { Canvas.drawText(currentCanvas, text, posX, posY, fontSize, color); }

fn void setCanvas(Canvas *canvas) { currentCanvas = canvas; }
fn void setBlendMode(BlendMode blendMode) { currentBlendMode = blendMode; }
fn void draw(Canvas *source, int sourceX, int sourceY, int width, int height, int targetX, int targetY) { Canvas.draw(source, currentCanvas, sourceX, sourceY, width, height, targetX, targetY); }

fn bool checkCollisionPointRec(IntVector2 point, IntVector4 rect) {
    if (point.x >= rect.x && point.x <= rect.x + rect.b && point.y >= rect.y && point.y <= rect.y + rect.a) {
        return true;
    }
    return false;
}

extern fn void setClipboardText(char *text) @export("setClipboardText") @wasm;
extern fn void openURL(char *text) @export("openURL") @wasm;

extern fn void quit() @export("shouldQuit") @wasm;

module vi::kb;

const ARROW_RIGHT = 39;
const ARROW_LEFT = 37;
const ARROW_UP = 38;
const ARROW_DOWN = 40;

extern fn bool isKeyDown(char key) @export("isKeyDown") @wasm;

module vi::mouse;

extern fn void getPosition(IntVector2 *resultPtr) @export("Mouse_getPosition") @wasm;
extern fn int getX() @export("Mouse_getX") @wasm;
extern fn int getY() @export("Mouse_getY") @wasm;
extern fn bool isDown(char button) @export("Mouse_isDown") @wasm; // 0-4 https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/button
extern fn void setCursor(char *cursor) @export("Mouse_setCursor") @wasm;

module vi::js;

extern fn float getRandomValue(int min, int max) @export("getRandomValue") @wasm;

// Here'll be temporary *Borrow-functions*. They borrow given canvas to js, draw stuff, and rewrite pixels in raw memory.
// **BEWARE** The memory passing back and forth in a single frame will heavily influence performance
// You can avoid it by drawing everything once at the start of the programm to a separate canvas
// and then just draw this canvas to your actual render target
// TODO: maybe I should use freetype?
extern fn void drawText(Canvas *canvas, char *text, int posX, int posY, int fontSize, Color *color) @export("drawText") @wasm;