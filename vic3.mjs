function makeEnvironment(env) {
    return new Proxy(env, {
        get(_target, prop, _receiver) {
            if (env[prop] !== undefined) {
                return env[prop].bind(env);
            }
            return (...args) => {
                throw new Error(`NOT IMPLEMENTED: ${prop} ${args}`);
            }
        }
    });
}

function renderDebugInfo(ctx, deltaTime, game) {
    const fontSize = 28;
    ctx.font = `${fontSize}px bold`;
    game.dts.push(deltaTime);
    if (game.dts.length > 60)
        game.dts.shift();
    const dtAvg = game.dts.reduce((a, b) => a + b, 0) / game.dts.length;
    const labels = [];
    labels.push(`FPS: ${Math.floor(1 / dtAvg)}`);
    const shadowOffset = fontSize * 0.06;
    const padding = 70;
    for (let i = 0; i < labels.length; ++i) {
        ctx.fillStyle = "black";
        ctx.fillText(labels[i], padding, padding + fontSize * i);
        ctx.fillStyle = "white";
        ctx.fillText(labels[i], padding + shadowOffset, padding - shadowOffset + fontSize * i);
    }
}

let handleIntersection = function (entries) {
    for (let entry of entries) {
        if (entry.isIntersecting) {
            entry.target.classList.add("visible");
        } else {
            entry.target.classList.remove("visible");
        }
    }
}

const observer = new IntersectionObserver(handleIntersection);

class Vic3 {
    #reset() {
        this.wasm = undefined;
        this.ctx = undefined;
        this.dt = undefined;
        this.dts = [];
        this.previous = undefined;
        this.quit = undefined;
        this.canvasPtr = undefined;
        this.canvasWidth = undefined;
        this.canvasHeight = undefined;
        this.focused = false;
        this.prevPressedKeyState = new Set();
        this.currentPressedKeyState = new Set();
        this.currentMouseWheelMoveState = 0;
        this.currentMousePosition = {x: 0, y: 0};
    }

    constructor() {
        this.#reset();
    }

    async start({ wasm, canvas }) {
        if (!wasm || !canvas) { // wasm is either a path or a WebAssembly.Module (use latter only if you're caching it somewhere)
            throw new Error("Both wasm and canvas are required");
        }
        if (typeof canvas === "string") { // canvas is either a selector or a canvas element
            canvas = document.querySelector(canvas);
        }
        observer.observe(canvas);
        this.ctx = canvas.getContext("2d");
        if (this.ctx === null) {
            throw new Error("Could not create 2d canvas context");
        }

        if (typeof wasm === "string") {
            this.wasm = await WebAssembly.instantiateStreaming(fetch(wasm), {
                env: makeEnvironment(this)
            });
        } else {
            this.wasm = await WebAssembly.instantiate(wasm, {
                env: makeEnvironment(this)
            });
        }

        this.ctx.canvas.addEventListener("focus", () => this.focused = true);
        this.ctx.canvas.addEventListener("blur", () => this.focused = false);
        const keyDown = (e) => {
            if (this.focused) {
                e.preventDefault();
                this.currentPressedKeyState.add(e.keyCode);
            }
        }
        const keyUp = (e) => {
            if (this.focused) {
                e.preventDefault();
                this.currentPressedKeyState.delete(e.keyCode);
            }
        }
        const wheelMove = (e) => {
            if (this.focused) {
                e.preventDefault();
                this.currentMouseWheelMoveState = Math.sign(-e.deltaY);
            }
        }
        const mouseMove = (e) => {
            if (this.focused) {
                this.currentMousePosition = {x: e.clientX, y: e.clientY};
            }
        }

        window.addEventListener("keydown", keyDown);
        window.addEventListener("keyup", keyUp);
        window.addEventListener("wheel", wheelMove);
        window.addEventListener("mousemove", mouseMove);

        this.wasm.instance.exports._initialize();
        this.wasm.instance.exports.main();

        const next = (timestamp) => {
            if (this.quit === 1) {
                this.ctx.clearRect(0, 0, this.ctx.canvas.width, this.ctx.canvas.height);
                this.#reset();
                return;
            } else if (this.quit === 0) {
                this.#reset();
                return;
            }
            this.dt = (timestamp - this.previous)/1000.0;
            this.previous = timestamp;
            if (this.ctx.canvas.classList.contains("visible")) {
                this.wasm.instance.exports.draw(Math.min(this.dt, 1 / 60)); // TODO: introduce less hacky way to limit dt
                // TODO: create separate update function
                const buffer = this.wasm.instance.exports.memory.buffer;
                const pixels = new Uint8ClampedArray(buffer, this.canvasPtr + 8, this.canvasWidth * this.canvasHeight * 4);
                this.ctx.putImageData(new ImageData(pixels, this.canvasWidth, this.canvasHeight), 0, 0);
                this.quit === undefined && renderDebugInfo(this.ctx, this.dt, this);
            }
            requestAnimationFrame(next);
        }
        window.requestAnimationFrame((timestamp) => {
            this.previous = timestamp;
            window.requestAnimationFrame(next);
        });
    }
    shouldQuit() {
        this.quit = 0;
    }
    fmodf(a, b) {
        return a % b;
    }
    connectCanvas(canvasPtr) {
        this.canvasPtr = canvasPtr;
        const buffer = this.wasm.instance.exports.memory.buffer;
        this.canvasWidth = new Uint32Array(buffer, canvasPtr, 1)[0];
        this.canvasHeight = new Uint32Array(buffer, canvasPtr + 4, 1)[0];
        this.ctx.canvas.width = this.canvasWidth;
        this.ctx.canvas.height = this.canvasHeight;
    }
    getRandomValue(min, max) { // TEMP
        return min + Math.floor(Math.random()*(max - min + 1));
    }
    isKeyDown(keyCode) {
        return this.currentPressedKeyState.has(keyCode);
    }
    drawText(canvasPtr, textPtr, posX, posY, fontSize, colorPtr) { // TODO: implement font atlas, and C3's drawText
        const buffer = this.wasm.instance.exports.memory.buffer;
        const pixelsPtr = canvasPtr + 8;
        const tempCanvas = document.createElement("canvas");
        tempCanvas.width = this.canvasWidth;
        tempCanvas.height = this.canvasHeight;
        const tempCtx = tempCanvas.getContext("2d");
        tempCtx.putImageData(new ImageData(new Uint8ClampedArray(buffer, pixelsPtr, this.canvasWidth * this.canvasHeight * 4), this.canvasWidth, this.canvasHeight), 0, 0);
        const text = cstr_by_ptr(buffer, textPtr);
        const color = getColorFromMemory(buffer, colorPtr);

        tempCtx.fillStyle = color;
        tempCtx.font = `${fontSize}px VT323`;
        tempCtx.fillText(text, posX, posY);

        const pixels = new Uint8ClampedArray(tempCtx.getImageData(0, 0, this.canvasWidth, this.canvasHeight).data);
        const target = new Uint8ClampedArray(buffer, pixelsPtr, this.canvasWidth * this.canvasHeight * 4);
        target.set(pixels);
    }
}

function cstrlen(mem, ptr) {
    let len = 0;
    while (mem[ptr] != 0) {
        len++;
        ptr++;
    }
    return len;
}

function cstr_by_ptr(mem_buffer, ptr) {
    const mem = new Uint8Array(mem_buffer);
    const len = cstrlen(mem, ptr);
    const bytes = new Uint8Array(mem_buffer, ptr, len);
    return new TextDecoder().decode(bytes);
}

function colorHexUnpacked(r, g, b, a) {
    r = r.toString(16).padStart(2, '0');
    g = g.toString(16).padStart(2, '0');
    b = b.toString(16).padStart(2, '0');
    a = a.toString(16).padStart(2, '0');
    return "#"+r+g+b+a;
}

function getColorFromMemory(buffer, color_ptr) {
    const [r, g, b, a] = new Uint8Array(buffer, color_ptr, 4);
    return colorHexUnpacked(r, g, b, a);
}

export default Vic3;
