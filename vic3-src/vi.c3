module vi;

import std::math;
import std::core::string;
import std::compression::qoi;

def Color = char[<4>];
def Vector2 = float[<2>];
def IntVector2 = int[<2>];
def Vector4 = float[<4>];
def IntVector4 = int[<4>];

extern fn float fpow(float x, float exp) @extern("fpow") @wasm;

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
    uint width;
    uint height;
    Color[*] pixels;
}
Canvas *defaultCanvas;
Canvas *currentCanvas;
IntVector4 drawArea = IntVector4 { 0, 0, 0, 0 }; // sets by setScissor, restrict draw area, if zeros - whole canvas

extern fn void connectCanvas(Canvas *canvas) @extern("connectCanvas") @wasm;
fn Canvas *initWindow(uint width, uint height) {
    defaultCanvas = newCanvas(width, height);
    currentCanvas = defaultCanvas;
    connectCanvas(defaultCanvas);
    return defaultCanvas;
}

fn Color hsvToRGB(float hue, float saturation, float value, float alpha) { // h: 0-360, s: 0-1, v: 0-1, a: 0-1
    float[3] k = { 5.0, 3.0, 1.0 };
    float[3] color;
    for (int i = 0; i < 3; ++i) {
        k[i] = (k[i] + hue / 60.0) % 6.0;
        k[i] = math::clamp(math::min(4.0f - k[i], k[i]), 0.0f, 1.0f);
        color[i] = (value - value * saturation * k[i]) * 255.0f;
    }

    return Color { (char)color[0], (char)color[1], (char)color[2], (char)(alpha * 255) };
}

struct Oklch {
    float l; // Lightness (0 to 1)
    float c; // Chroma (0 to 1)
    float h; // Hue (in degrees, 0 to 360)
    float a; // Alpha (0 to 1)
}

// Function to convert OKLCH to sRGB (0-255)
fn Color oklchToRGB(Oklch oklch) {
    // Convert hue from degrees to radians
    float h_rad = oklch.h * (math::PI / 180.0f);

    // Convert OKLCH to Oklab
    float lab_1 = oklch.l;
	float lab_2 = oklch.c * math::cos(h_rad);
    float lab_3 = oklch.c * math::sin(h_rad);

    // Oklab to linear LMS
    float l_ = lab_1 + 0.3963377774 * lab_2 + 0.2158037573 * lab_3;
    float m_ = lab_1 - 0.1055613458 * lab_2 - 0.0638541728 * lab_3;
    float s_ = lab_1 - 0.0894841775 * lab_2 - 1.2914855480 * lab_3;

    // Cube the values
    float l_cubed = l_ * l_ * l_;
    float m_cubed = m_ * m_ * m_;
    float s_cubed = s_ * s_ * s_;

    // Linear RGB
    float r_linear =  4.0767416621 * l_cubed - 3.3077115913 * m_cubed + 0.2309699292 * s_cubed;
    float g_linear = -1.2684380046 * l_cubed + 2.6097574011 * m_cubed - 0.3413193965 * s_cubed;
    float b_linear = -0.0041960863 * l_cubed - 0.7034186147 * m_cubed + 1.7076147010 * s_cubed;

    // Apply gamma correction to convert linear RGB to sRGB
    float r_srgb = (r_linear <= 0.0031308f) ? 12.92f * r_linear : 1.055f * fpow(r_linear, 1.0f / 2.4f) - 0.055f;
    float g_srgb = (g_linear <= 0.0031308f) ? 12.92f * g_linear : 1.055f * fpow(g_linear, 1.0f / 2.4f) - 0.055f;
    float b_srgb = (b_linear <= 0.0031308f) ? 12.92f * b_linear : 1.055f * fpow(b_linear, 1.0f / 2.4f) - 0.055f;

    Color rgba = { // Clamp values to range [0, 255]
        (char)(math::clamp(r_srgb * 255.0, 0.0, 255.0)),
        (char)(math::clamp(g_srgb * 255.0, 0.0, 255.0)),
        (char)(math::clamp(b_srgb * 255.0, 0.0, 255.0)),
        (char)(math::clamp(oklch.a * 255.0, 0.0, 255.0))
    };

    // Color rgba = { 230, 230, 230, 255 };

    return rgba;
}

fn Canvas *newCanvas(uint width, uint height) {
    Canvas *canvas = mem::calloc((Canvas.sizeof + (ulong)(width * height) * Color.sizeof));
    canvas.width = width;
    canvas.height = height;
    for (uint i = 0; i < width * height; ++i) {
        canvas.pixels[i] = Color { 0, 0, 0, 0 };
    }
    return canvas;
}

fn Canvas *newCanvasFromImageData(char[] data) {
    QOIDesc desc;
    char[] pixels = qoi::decode(data, &desc) ?? (char[]){};
    Canvas *canvas = newCanvas(desc.width, desc.height);
    for (uint i = 0; i < desc.width * desc.height; ++i) {
        canvas.putPixel(i % desc.width, i / desc.width, Color { pixels[i*4], pixels[i*4+1], pixels[i*4+2], pixels[i*4+3] });
    }
    return canvas;
}

fn void Canvas.clearBackground(&canvas, Color color) {
    for (uint i = 0; i < canvas.width * canvas.height; ++i) {
        canvas.pixels[i] = color;
    }
}

// Basic shapes drawing functions

// Draw a pixel
fn void Canvas.putPixel(&canvas, int posX, int posY, Color color) {
    if (posX < 0 || posX >= canvas.width || posY < 0 || posY >= canvas.height) {
        return;
    }
    if (drawArea[2] > 0 && drawArea[3] > 0) {
        if (posX < drawArea.x || posX >= drawArea.x + drawArea[2] || posY < drawArea.y || posY >= drawArea.y + drawArea[3]) {
            return;
        }
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
fn void Canvas.putPixelV(&canvas, IntVector2 position, Color color) {
    Canvas.putPixel(canvas, position.x, position.y, color);
}

// Draw a color-filled circle
fn void Canvas.drawCircle(&canvas, int centerX, int centerY, float radius, Color color) {
    int x = 0;
    int y = (int)radius;
    int d = 3 - 2 * (int)radius;
    
    while (y >= x) {
        canvas.putPixel(centerX + x, centerY + y, color);
        canvas.putPixel(centerX - x, centerY + y, color);
        canvas.putPixel(centerX + x, centerY - y, color);
        canvas.putPixel(centerX - x, centerY - y, color);
        canvas.putPixel(centerX + y, centerY + x, color);
        canvas.putPixel(centerX - y, centerY + x, color);
        canvas.putPixel(centerX + y, centerY - x, color);
        canvas.putPixel(centerX - y, centerY - x, color);
        
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
                canvas.putPixel(centerX + px, centerY + py, color);
            }
        }
    }
}

// Draw a color-filled rectangle
fn void Canvas.drawRectangle(&canvas, int posX, int posY, int width, int height, Color color) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            canvas.putPixel(posX + x, posY + y, color);
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
        canvas.putPixel(posX, posY + y, color);
        canvas.putPixel(posX + width - 1, posY + y, color);
    }
    for (int x = 0; x < width; ++x) {
        canvas.putPixel(posX + x, posY, color);
        canvas.putPixel(posX + x, posY + height - 1, color);
    }
}

fn void Canvas.drawTriangle(&canvas, int x1, int y1, int x2, int y2, int x3, int y3, Color color) {
    int lx, hx, ly, hy;
    if (vi::normalizeTriangle(canvas.width, canvas.height, x1, y1, x2, y2, x3, y3, &lx, &hx, &ly, &hy)) {
        for (int y = ly; y <= hy; ++y) {
            for (int x = lx; x <= hx; ++x) {
                int u1, u2, det;
                if (vi::barycentric(x1, y1, x2, y2, x3, y3, x, y, &u1, &u2, &det)) {
                    canvas.putPixel(x, y, color);
                }
            }
        }
    }
}

fn void Canvas.drawTriangleLines(&canvas, int x1, int y1, int x2, int y2, int x3, int y3, Color color) {
    canvas.drawLine(x1, y1, x2, y2, color);
    canvas.drawLine(x1, y1, x3, y3, color);
    canvas.drawLine(x2, y2, x3, y3, color);
}

// Draw a line
fn void Canvas.drawLine(&canvas, int x1, int y1, int x2, int y2, Color color) @extern("drawLine") @wasm {
    int dx = x2 - x1;
    int dy = y2 - y1;

    // If both of the differences are 0 there will be a division by 0 below.
    if (dx == 0 && dy == 0) {
        canvas.putPixel(x1, y1, color);
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
            canvas.putPixel(x, y, color);
        }
    } else {
        if (y1 > y2) {
            swap(&x1, &x2);
            swap(&y1, &y2);
        }

        for (int y = y1; y <= y2; ++y) {
            int x = dx*(y - y1)/dy + x1;
            // TODO: move boundary checks out side of the loops in olivec_draw_line
            canvas.putPixel(x, y, color);
        }
    }
}

fn void Canvas.drawText(&canvas, char *text, int posX, int posY, Color color) {
    vi::js::drawText(canvas, text, posX, posY, &color);
}

fn void Canvas.draw(&canvas, Canvas *target, int sourceX, int sourceY, int width, int height, int targetX, int targetY) {
    for (int x = 0; x < math::min(width, canvas.width - sourceX); ++x) {
        for (int y = 0; y < math::min(height, canvas.height - sourceY); ++y) {
            Color pixel = canvas.pixels[(sourceY + y) * canvas.width + (sourceX + x)];
            if (pixel.a > 0) {
                target.putPixel(targetX + x, targetY + y, pixel);
            }
        }
    }
}

fn void Canvas.mask(&mask, Canvas *target, int maskX, int maskY, int width, int height, int targetX, int targetY) {
    for (int x = 0; x < math::min(width, mask.width - maskX); ++x) {
        for (int y = 0; y < math::min(height, mask.height - maskY); ++y) {
            Color mask_pixel = mask.pixels[(maskY + y) * mask.width + (maskX + x)];
            Color target_pixel = target.pixels[(targetY + y) * target.width + (targetX + x)];
            if (mask_pixel.a == 0) {
                target.pixels[(targetY + y) * target.width + (targetX + x)].a = (char)0;
            } else if (target_pixel.a == 255) {
                target.pixels[(targetY + y) * target.width + (targetX + x)].a = mask_pixel.a;
            } else if (mask_pixel.a < 255) {
                target.pixels[(targetY + y) * target.width + (targetX + x)].a = (char)(target_pixel.a * mask_pixel.a / 255 / 255);
            }
        }
    }
}

fn void Canvas.populateWithImageData(Canvas *canvas, char[] data) {
    QOIDesc desc;
    char[] pixels = qoi::decode(data, &desc) ?? (char[]){};
    for (int i = 0; i < desc.width * desc.height; ++i) {
        canvas.putPixel(i % desc.width, i / desc.width, Color{ pixels[i * 4], pixels[i * 4 + 1], pixels[i * 4 + 2], pixels[i * 4 + 3] });
    }
}

fn void clearBackground(Color color) { Canvas.clearBackground(currentCanvas, color); }
fn void putPixel(int x, int y, Color color) { Canvas.putPixel(currentCanvas, x, y, color); }
fn void putPixelV(IntVector2 position, Color color) { Canvas.putPixelV(currentCanvas, position, color); }
fn void drawCircle(int centerX, int centerY, float radius, Color color) { Canvas.drawCircle(currentCanvas, centerX, centerY, radius, color); }
fn void drawRectangle(int posX, int posY, int width, int height, Color color) { Canvas.drawRectangle(currentCanvas, posX, posY, width, height, color); }
fn void drawRectangleV(IntVector2 position, IntVector2 size, Color color) { Canvas.drawRectangleV(currentCanvas, position, size, color); }
fn void drawRectangleLines(int posX, int posY, int width, int height, Color color) { Canvas.drawRectangleLines(currentCanvas, posX, posY, width, height, color); }
fn void drawTriangle(int x1, int y1, int x2, int y2, int x3, int y3, Color color) { Canvas.drawTriangle(currentCanvas, x1, y1, x2, y2, x3, y3, color); }
fn void drawTriangleLines(int x1, int y1, int x2, int y2, int x3, int y3, Color color) { Canvas.drawTriangleLines(currentCanvas, x1, y1, x2, y2, x3, y3, color); }
fn void drawLine(int x1, int y1, int x2, int y2, Color color) { Canvas.drawLine(currentCanvas, x1, y1, x2, y2, color); }
fn void drawText(char *text, int posX, int posY, Color color) { Canvas.drawText(currentCanvas, text, posX, posY, color); }

fn void setCanvas(Canvas *canvas) { currentCanvas = canvas; }
fn void setScissor(IntVector4 area) { drawArea = area; } // The idea stolen from Love2d https://love2d.org/wiki/love.graphics.setScissor
fn void unsetScissor() { drawArea = IntVector4 { 0, 0, 0, 0 }; }
fn void setBlendMode(BlendMode blendMode) { currentBlendMode = blendMode; }

fn void draw(Canvas *source, int sourceX, int sourceY, int width, int height, int targetX, int targetY) {
    Canvas.draw(source, currentCanvas, sourceX, sourceY, width, height, targetX, targetY);
}
fn void mask(Canvas *mask, int maskX, int maskY, int width, int height, int targetX, int targetY) {
    Canvas.mask(mask, currentCanvas, maskX, maskY, width, height, targetX, targetY);
}
fn void populateWithImageData(char[] data) { Canvas.populateWithImageData(currentCanvas, data); }

fn bool checkCollisionPointRec(IntVector2 point, IntVector4 rect) {
    if (point.x >= rect.x && point.x <= rect.x + rect.b && point.y >= rect.y && point.y <= rect.y + rect.a) {
        return true;
    }
    return false;
}

fn bool normalizeTriangle(uint width, uint height, int x1, int y1, int x2, int y2, int x3, int y3, int *lx, int *hx, int *ly, int *hy) {
    *lx = x1;
    *hx = x1;
    if (*lx > x2) { *lx = x2; }
    if (*lx > x3) { *lx = x3; }
    if (*hx < x2) { *hx = x2; }
    if (*hx < x3) { *hx = x3; }
    if (*lx < 0) { *lx = 0; }
    if ((uint) *lx >= width) { return false; }
    if (*hx < 0) { return false; }
    if ((uint) *hx >= width) { *hx = width-1; }

    *ly = y1;
    *hy = y1;
    if (*ly > y2) { *ly = y2; }
    if (*ly > y3) { *ly = y3; }
    if (*hy < y2) { *hy = y2; }
    if (*hy < y3) { *hy = y3; }
    if (*ly < 0) { *ly = 0; }
    if ((uint) *ly >= height) { return false; }
    if (*hy < 0) { return false; }
    if ((uint) *hy >= height) { *hy = height-1; }

    return true;
}

fn bool barycentric(int x1, int y1, int x2, int y2, int x3, int y3, int xp, int yp, int *u1, int *u2, int *det) {
    *det = ((x1 - x3)*(y2 - y3) - (x2 - x3)*(y1 - y3));
    *u1  = ((y2 - y3)*(xp - x3) + (x3 - x2)*(yp - y3));
    *u2  = ((y3 - y1)*(xp - x3) + (x1 - x3)*(yp - y3));
    int u3 = *det - *u1 - *u2;
    return ((math::sign(*u1) == math::sign(*det) || *u1 == 0) &&
        (math::sign(*u2) == math::sign(*det) || *u2 == 0) &&
        (math::sign(u3) == math::sign(*det) || u3 == 0));
}

extern fn void setClipboardText(char *text) @extern("setClipboardText") @wasm;
extern fn void openURL(char *text) @extern("openURL") @wasm;

extern fn void quit() @extern("shouldQuit") @wasm;

module vi::kb;

extern fn bool isKeyDown(char *code) @extern("isKeyDown") @wasm;

module vi::mouse;

extern fn void getPosition(IntVector2 *result) @extern("Mouse_getPosition") @wasm;
extern fn int getX() @extern("Mouse_getX") @wasm;
extern fn int getY() @extern("Mouse_getY") @wasm;
extern fn bool isDown(char button) @extern("Mouse_isDown") @wasm; // 0-4 https://developer.mozilla.org/en-US/docs/Web/API/MouseEvent/button
extern fn void setCursor(char *cursor) @extern("Mouse_setCursor") @wasm;

module vi::js;

extern fn int getRandomValue(int min, int max) @extern("getRandomValue") @wasm;

// Here'll be temporary *Borrow-functions*. They borrow given canvas to js, draw stuff, and rewrite pixels in raw memory.
// **BEWARE** The memory passing back and forth in a single frame will heavily influence performance
// You can avoid it by drawing everything once at the start of the programm to a separate canvas
// and then just draw this canvas to your actual render target
// TODO: maybe I should use freetype?
extern fn void drawText(Canvas *canvas, char *text, int posX, int posY, Color *color) @extern("drawText") @wasm;
extern fn void measureText(char *text, IntVector2 *result) @extern("measureText") @wasm;
extern fn void setFont(char *font) @extern("setFont") @wasm;

