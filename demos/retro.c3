import vi;
import std::math;

const WIDTH = 800;
const HEIGHT = 600;
const HORIZON = 300;
const CX = WIDTH / 2;

const SUN_SIZE = 401;
const SUN_CX = 200;
const SUN_CY = 220;
const SUN_R = 180;

const GLOW_SIZE = 520;
const GLOW_R = 260;

const STAR_COUNT = 90;
const GRID_DEPTH = 42.0f;

// Grid rows repeat every 1.0 world unit, road dashes every 0.7 (10 vs 7 in
// tenths — coprime, cicada-style), so the two patterns rarely line up.
// gridScroll wraps at their common period of 7.0.
const GRID_STEP = 1.0f;
const DASH_PERIOD = 0.7f;
const DASH_LEN = 0.35f;
const SCROLL_WRAP = 7.0f;

float time = 0;
float gridScroll = 0;
float sunPhase = 0;

Canvas *screen;
Canvas *background; // sky + ground gradients, baked once
Canvas *sunSource;  // pristine sun gradient
Canvas *sun;        // working copy, re-masked each frame
Canvas *circleMask; // sun disc without gaps, baked once
Canvas *sunMask;    // disc + animated gaps
Canvas *glow;       // radial halo around the sun, baked once
Canvas *crt;        // per-pixel dim factor (scanlines + vignette) in the red channel

int[STAR_COUNT] starX;
int[STAR_COUNT] starY;
int[STAR_COUNT] starSize;
float[STAR_COUNT] starPhase;
float[STAR_COUNT] starSpeed;

fn float lerpf(float a, float b, float t) {
    return a + (b - a) * t;
}

fn Color oklchMix(Oklch from, Oklch to, float t) {
    return vi::oklchToRGB((Oklch) {
        lerpf(from.l, to.l, t),
        lerpf(from.c, to.c, t),
        lerpf(from.h, to.h, t),
        lerpf(from.a, to.a, t)
    });
}

fn void drawStars() {
    for (int i = 0; i < STAR_COUNT; ++i) {
        float twinkle = 0.55f + 0.45f * math::sin(time * starSpeed[i] + starPhase[i]);
        char a = (char)(60 + (int)(twinkle * 180));
        Color c = (Color) { 210, 215, 255, a };
        vi::putPixel(starX[i], starY[i], c);
        if (starSize[i] > 1) {
            Color half = (Color) { 210, 215, 255, (char)(a / 2) };
            vi::putPixel(starX[i] - 1, starY[i], half);
            vi::putPixel(starX[i] + 1, starY[i], half);
            vi::putPixel(starX[i], starY[i] - 1, half);
            vi::putPixel(starX[i], starY[i] + 1, half);
        }
    }
}

fn void drawSun() {
    // Restore the pristine gradient, rebuild the mask with gaps at animated
    // positions, cut the disc out, then blit the part above the horizon.
    for (uint i = 0; i < SUN_SIZE * SUN_SIZE; ++i) {
        sun.pixels[i] = sunSource.pixels[i];
        sunMask.pixels[i] = circleMask.pixels[i];
    }

    vi::setBlendMode(BlendMode.REPLACE);
    for (int k = 0; k < 10; ++k) {
        float t = (float)k + sunPhase;
        int y = 190 + (int)(t * t * 2.6f);
        if (y >= SUN_SIZE) break;
        int h = 2 + (int)(t * 1.1f);
        sunMask.drawRectangle(0, y, SUN_SIZE, h, (Color) { 0, 0, 0, 0 });
    }
    vi::setBlendMode(BlendMode.ALPHA);

    sunMask.mask(sun, 0, 0, SUN_SIZE, SUN_SIZE, 0, 0);
    vi::draw(sun, 0, 0, SUN_SIZE, HORIZON, CX - SUN_CX, 0);
}

fn void drawMountain(int x1, int px, int py, int x2) {
    vi::drawTriangle(x1, HORIZON, px, py, x2, HORIZON, (Color) { 16, 10, 30, 255 });
    vi::drawLine(x1, HORIZON, px, py, (Color) { 160, 70, 150, 220 });
    vi::drawLine(px, py, x2, HORIZON, (Color) { 160, 70, 150, 220 });
}

fn void drawGrid() {
    // Vertical lines fan out from the vanishing point at the center of the horizon.
    for (int j = -7; j <= 7; ++j) {
        vi::drawLine(CX, HORIZON + 1, CX + j * 170, HEIGHT + 30, (Color) { 236, 72, 153, 150 });
    }

    // Horizontal lines are rows of a ground plane projected as y = horizon + depth / z.
    float frac = gridScroll % GRID_STEP;
    for (int i = 0; i < 26; ++i) {
        float z = ((float)i + 1.0f) * GRID_STEP - frac;
        int y = HORIZON + (int)(GRID_DEPTH / z);
        if (y >= HEIGHT) continue;
        int a = 25 + (y - HORIZON) * 4;
        if (a > 235) a = 235;
        vi::drawLine(0, y, WIDTH, y, (Color) { 236, 72, 153, (char)a });
        if (y > 430) {
            vi::drawLine(0, y + 1, WIDTH, y + 1, (Color) { 236, 72, 153, (char)a });
        }
    }
}

fn void drawRoad() {
    vi::drawTriangle(CX - 7, HORIZON + 2, CX + 7, HORIZON + 2, WIDTH / 4 * 3, HEIGHT, (Color) { 7, 5, 16, 255 });
    vi::drawTriangle(CX - 7, HORIZON + 2, WIDTH / 4 * 3, HEIGHT, WIDTH / 4, HEIGHT, (Color) { 7, 5, 16, 255 });
    vi::drawLine(CX - 7, HORIZON + 2, WIDTH / 4, HEIGHT, (Color) { 236, 72, 153, 255 });
    vi::drawLine(CX + 7, HORIZON + 2, WIDTH / 4 * 3, HEIGHT, (Color) { 236, 72, 153, 255 });

    // Center dashes share the grid projection and speed but repeat with their
    // own period; a dash whose near end passes the camera stretches to the
    // bottom edge instead of vanishing.
    float dashFrac = gridScroll % DASH_PERIOD;
    for (int i = 0; i < 34; ++i) {
        float zFar = ((float)i + 1.0f) * DASH_PERIOD - dashFrac;
        if (zFar > 24.0f) break;
        float zNear = zFar - DASH_LEN;
        int yFar = HORIZON + (int)(GRID_DEPTH / zFar);
        if (yFar >= HEIGHT) continue;
        int yNear = zNear <= 0.03f ? HEIGHT : HORIZON + (int)(GRID_DEPTH / zNear);
        if (yNear > HEIGHT) yNear = HEIGHT;
        int w = 2 + (yFar - HORIZON) / 40;
        int a = 40 + (yFar - HORIZON) * 5;
        if (a > 230) a = 230;
        vi::drawRectangle(CX - w / 2, yFar, w, yNear - yFar, (Color) { 255, 214, 130, (char)a });
    }
}

fn void drawTitle() {
    int x = 298;
    int y = 96;
    vi::drawText("RETROWAVE", x - 3, y, (Color) { 236, 72, 153, 60 });
    vi::drawText("RETROWAVE", x + 3, y, (Color) { 236, 72, 153, 60 });
    vi::drawText("RETROWAVE", x, y - 3, (Color) { 236, 72, 153, 60 });
    vi::drawText("RETROWAVE", x, y + 3, (Color) { 236, 72, 153, 60 });
    vi::drawText("RETROWAVE", x - 1, y - 1, (Color) { 236, 72, 153, 140 });
    vi::drawText("RETROWAVE", x + 1, y + 1, (Color) { 236, 72, 153, 140 });
    vi::drawText("RETROWAVE", x, y, (Color) { 255, 236, 250, 255 });
}

fn void applyCrt() {
    for (uint i = 0; i < WIDTH * HEIGHT; ++i) {
        Color p = screen.pixels[i];
        char f = crt.pixels[i].r;
        screen.pixels[i] = (Color) {
            (char)(p.r * f / 255),
            (char)(p.g * f / 255),
            (char)(p.b * f / 255),
            p.a
        };
    }
}

fn void draw(float dt) @export("draw") @wasm {
    if (dt > 0.1f) dt = 0.1f;
    time += dt;
    gridScroll = (gridScroll + dt * 1.4f) % SCROLL_WRAP;
    sunPhase = (sunPhase + dt * 0.35f) % 1.0f;

    for (uint i = 0; i < WIDTH * HEIGHT; ++i) {
        screen.pixels[i] = background.pixels[i];
    }

    drawStars();
    vi::draw(glow, 0, GLOW_R - SUN_CY, GLOW_SIZE, HORIZON, CX - GLOW_R, 0);
    drawSun();

    drawMountain(-40, 70, 235, 180);
    drawMountain(120, 210, 250, 300);
    drawMountain(500, 590, 245, 690);
    drawMountain(640, 730, 225, 840);

    for (int i = -2; i <= 2; ++i) {
        int a = 255 - (i < 0 ? -i : i) * 80;
        vi::drawLine(0, HORIZON + i, WIDTH, HORIZON + i, (Color) { 236, 72, 153, (char)a });
    }

    drawGrid();
    drawRoad();
    drawTitle();
    applyCrt();
}

fn void main() @export("main") @wasm {
    screen = vi::initWindow(WIDTH, HEIGHT);

    background = vi::newCanvas(WIDTH, HEIGHT);
    for (int y = 0; y < HORIZON; ++y) {
        float t = (float)y / (HORIZON - 1);
        Color c = oklchMix(
            (Oklch) { 0.13, 0.055, 300.0, 1.0 },
            (Oklch) { 0.52, 0.20, 345.0, 1.0 },
            t * t
        );
        background.drawRectangle(0, y, WIDTH, 1, c);
    }
    for (int y = HORIZON; y < HEIGHT; ++y) {
        float t = (float)(y - HORIZON) / (HEIGHT - HORIZON - 1);
        Color c = oklchMix(
            (Oklch) { 0.24, 0.10, 320.0, 1.0 },
            (Oklch) { 0.08, 0.04, 310.0, 1.0 },
            t
        );
        background.drawRectangle(0, y, WIDTH, 1, c);
    }

    sunSource = vi::newCanvas(SUN_SIZE, SUN_SIZE);
    for (int y = 0; y < SUN_SIZE; ++y) {
        float t = (float)y / (SUN_SIZE - 1);
        Color c = oklchMix(
            (Oklch) { 0.95, 0.16, 100.0, 1.0 },
            (Oklch) { 0.62, 0.24, 5.0, 1.0 },
            t
        );
        sunSource.drawRectangle(0, y, SUN_SIZE, 1, c);
    }
    sun = vi::newCanvas(SUN_SIZE, SUN_SIZE);
    sunMask = vi::newCanvas(SUN_SIZE, SUN_SIZE);
    circleMask = vi::newCanvas(SUN_SIZE, SUN_SIZE);
    circleMask.drawCircle(SUN_CX, SUN_CY, SUN_R, (Color) { 255, 255, 255, 255 });

    glow = vi::newCanvas(GLOW_SIZE, GLOW_SIZE);
    for (int y = 0; y < GLOW_SIZE; ++y) {
        for (int x = 0; x < GLOW_SIZE; ++x) {
            int dx = x - GLOW_R;
            int dy = y - GLOW_R;
            float f = 1.0f - (float)(dx * dx + dy * dy) / (GLOW_R * GLOW_R);
            if (f < 0) continue;
            glow.pixels[y * GLOW_SIZE + x] = (Color) { 255, 110, 190, (char)(f * f * 105) };
        }
    }

    crt = vi::newCanvas(WIDTH, HEIGHT);
    for (int y = 0; y < HEIGHT; ++y) {
        for (int x = 0; x < WIDTH; ++x) {
            float dx = (float)(x - CX) / CX;
            float dy = (float)(y - HORIZON) / HORIZON;
            float d2 = dx * dx + dy * dy;
            int a = y % 3 == 2 ? 38 : 0;
            if (d2 > 0.55f) a += (int)((d2 - 0.55f) * 95.0f);
            if (a > 190) a = 190;
            crt.pixels[y * WIDTH + x] = (Color) { (char)(255 - a), 0, 0, 255 };
        }
    }

    for (int i = 0; i < STAR_COUNT; ++i) {
        starX[i] = js::getRandomValue(0, WIDTH - 1);
        starY[i] = js::getRandomValue(0, HORIZON - 40);
        starSize[i] = js::getRandomValue(0, 6) == 0 ? 2 : 1;
        starPhase[i] = (float)js::getRandomValue(0, 628) / 100.0f;
        starSpeed[i] = (float)js::getRandomValue(80, 300) / 100.0f;
    }

    vi::setFontChars("VT323", 56, "RETROWAVE");
}
