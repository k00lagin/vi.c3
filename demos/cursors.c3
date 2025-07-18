import vi;

const WIDTH = 800;
const HEIGHT = 600;

const int COLS = 7;
const int ROWS = 5;

const RECT_SIZE = 76;
const GAP = (WIDTH - COLS * RECT_SIZE) / (COLS + 1);

enum Cursors : usz (String description)
{
    DEFAULT = "default",
    NONE = "none",
    CONTEXT_MENU = "context-menu",
    HELP = "help",
    POINTER = "pointer",
    PROGRESS = "progress",
    WAIT = "wait",
    CELL = "cell",
    CROSSHAIR = "crosshair",
    TEXT = "text",
    VERTICAL_TEXT = "vertical-text",
    ALIAS = "alias",
    COPY = "copy",
    MOVE = "move",
    NO_DROP = "no-drop",
    NOT_ALLOWED = "not-allowed",
    ALL_SCROLL = "all-scroll",
    COL_RESIZE = "col-resize",
    ROW_RESIZE = "row-resize",
    N_RESIZE = "n-resize",
    E_RESIZE = "e-resize",
    S_RESIZE = "s-resize",
    W_RESIZE = "w-resize",
    NE_RESIZE = "ne-resize",
    NW_RESIZE = "nw-resize",
    SE_RESIZE = "se-resize",
    SW_RESIZE = "sw-resize",
    EW_RESIZE = "ew-resize",
    NS_RESIZE = "ns-resize",
    NESW_RESIZE = "nesw-resize",
    NWSE_RESIZE = "nwse-resize",
    ZOOM_IN = "zoom-in",
    ZOOM_OUT = "zoom-out",
    GRAB = "grab",
    GRABBING = "grabbing",
}
usz currentCursor = 0;
bool hoverCursor;

IntVector2 mouseCoords;
bool mouseDownPrevState = false;
bool mouseDownState = false;

Canvas *labels;
bool labelsDrawn = false;

fn void draw(float dt) @export("draw") @wasm {
    vi::clearBackground((Color) { 8, 8, 18, 255 });

    vi::mouse::getPosition(&mouseCoords);
    mouseDownState = vi::mouse::isDown(0);
    if (!mouseDownState && mouseDownPrevState) {
        mouseDownPrevState = false;
    }
    hoverCursor = false;

    for (int col = 0; col < COLS; ++col) {
        for (int row = 0; row < ROWS; ++row) {
            IntVector4 rect = (IntVector4) { GAP + col * (RECT_SIZE + GAP), GAP + row * (RECT_SIZE + GAP), RECT_SIZE, RECT_SIZE };
            if (vi::checkCollisionPointRec(mouseCoords, rect)) {
                vi::drawRectangle(rect.x - 5, rect.y - 5, RECT_SIZE + 10, RECT_SIZE + 10, (Color) { 255, 42, 42, 255 });
                if (currentCursor != Cursors.from_ordinal(row * COLS + col).ordinal) {
                    vi::mouse::setCursor(Cursors.from_ordinal(row * COLS + col).description);
                    currentCursor = Cursors.from_ordinal(row * COLS + col).ordinal;
                }
                if (!mouseDownPrevState && mouseDownState) {
                    mouseDownPrevState = true;
                    vi::setClipboardText(String.tconcat("cursor: ", Cursors.from_ordinal(row * COLS + col).description));
                }
                if (mouseDownState) {
                    vi::drawRectangle(rect.x, rect.y, RECT_SIZE, RECT_SIZE, (Color) { 255, 69, 200, 255 });
                } else {
                    vi::drawRectangle(rect.x, rect.y, RECT_SIZE, RECT_SIZE, (Color) { 200, 69, 69, 255 });
                }
                hoverCursor = true;
            } else {
                vi::drawRectangle(rect.x, rect.y, RECT_SIZE, RECT_SIZE, (Color) { 200, 69, 69, 255 });
            }
            if (!labelsDrawn) {
                labels.drawText(Cursors.from_ordinal(row * COLS + col).description, rect.x + 1, (int)(rect.y + (RECT_SIZE / 9 * 5.75 + 1)), (Color) { 18, 18, 18, 255 });
                labels.drawText(Cursors.from_ordinal(row * COLS + col).description, rect.x + 2, (int)(rect.y + (RECT_SIZE / 9 * 5.75)), (Color) { 255, 255, 255, 255 });
            }
        }
    }

    if (currentCursor && !hoverCursor) {
        currentCursor = 0;
        vi::mouse::setCursor(Cursors.DEFAULT.description);
    }
    if (!labelsDrawn) {
        labelsDrawn = true;
    } else {
        vi::draw(labels, 0, 0, WIDTH, HEIGHT, 0, 0);
    }
}

fn void main() @export("main") @wasm {
    vi::initWindow(WIDTH, HEIGHT);
    vi::js::setFont("17px VT323");
    labels = vi::newCanvas(WIDTH, HEIGHT);
}
