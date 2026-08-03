import buildFontAtlas from './buildFontAtlas.mjs';

const DEFAULT_FONT_CODEPOINTS = createDefaultFontCodepoints();
const MAX_CONCURRENT_FONT_ATLAS_BUILDS = 2;

function makeEnvironment(env) {
	return new Proxy(env, {
		get(_target, prop, _receiver) {
			if (env[prop] !== undefined) {
				return env[prop].bind(env);
			}
			return (...args) => {
				throw new Error(`NOT IMPLEMENTED: ${prop} ${args}`);
			};
		}
	});
}

function renderDebugInfo(ctx, deltaTime, game) {
	const fontSize = 28;
	ctx.font = `${fontSize}px bold`;
	game.dts.push(deltaTime);
	if (game.dts.length > 60) game.dts.shift();
	const dtAvg = game.dts.reduce((a, b) => a + b, 0) / game.dts.length;
	const labels = [];
	labels.push(`FPS: ${Math.floor(1 / dtAvg)}`);
	const shadowOffset = fontSize * 0.06;
	const padding = 70;
	for (let i = 0; i < labels.length; ++i) {
		ctx.fillStyle = 'black';
		ctx.fillText(labels[i], padding, padding + fontSize * i);
		ctx.fillStyle = 'white';
		ctx.fillText(labels[i], padding + shadowOffset, padding - shadowOffset + fontSize * i);
	}
}

let handleIntersection = function (entries) {
	for (let entry of entries) {
		if (entry.isIntersecting) {
			entry.target.classList.add('visible');
		} else {
			entry.target.classList.remove('visible');
		}
	}
};

const observer = new IntersectionObserver(handleIntersection);

class Vic3 {
	#reset() {
		for (const build of this.fontAtlasBuilds?.values() ?? []) {
			build.controller.abort();
		}
		this.fontAtlasBuilds = new Map();
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
		this.prevPressedKeyCodes = new Set();
		this.prevPressedKeys = new Set();
		this.currentPressedKeyCodes = new Set();
		this.currentPressedKeys = new Set();
		this.currentMouseWheelMoveState = 0;
		this.currentMousePosition = { x: 0, y: 0 };
		this.prevMouseButtonState = new Set();
		this.currentMouseButtonState = new Set();
	}

	constructor() {
		this.#reset();
	}

	async start({ wasm, canvas }) {
		if (!wasm || !canvas) {
			// wasm is either a path or a WebAssembly.Module (use latter only if you're caching it somewhere)
			throw new Error('Both wasm and canvas are required');
		}
		if (typeof canvas === 'string') {
			// canvas is either a selector or a canvas element
			canvas = document.querySelector(canvas);
		}
		observer.observe(canvas);
		this.ctx = canvas.getContext('2d');
		if (this.ctx === null) {
			throw new Error('Could not create 2d canvas context');
		}

		if (typeof wasm === 'string') {
			this.wasm = await WebAssembly.instantiateStreaming(fetch(wasm), {
				env: makeEnvironment(this)
			});
		} else {
			this.wasm = await WebAssembly.instantiate(wasm, {
				env: makeEnvironment(this)
			});
		}

		this.ctx.canvas.addEventListener('focus', () => (this.focused = true));
		this.ctx.canvas.addEventListener('blur', () => (this.focused = false));
		const keyDown = (e) => {
			if (this.focused) {
				e.preventDefault();
				this.currentPressedKeyCodes.add(e.code);
			}
		};
		const keyUp = (e) => {
			if (this.focused) {
				e.preventDefault();
				this.currentPressedKeyCodes.delete(e.code);
			}
		};
		const wheelMove = (e) => {
			if (this.focused) {
				e.preventDefault();
				this.currentMouseWheelMoveState = Math.sign(-e.deltaY);
			}
		};
		const mouseMove = (e) => {
			if (this.ctx === undefined) return;
			const boundingClientRect = this.ctx.canvas.getBoundingClientRect();
			this.currentMousePosition = {
				x: e.clientX - boundingClientRect.x,
				y: e.clientY - boundingClientRect.y
			};
		};

		const mouseDown = (e) => {
			this.currentMouseButtonState.add(e.button);
		};
		const mouseUp = (e) => {
			this.currentMouseButtonState.delete(e.button);
		};

		window.addEventListener('keydown', keyDown);
		window.addEventListener('keyup', keyUp);
		window.addEventListener('wheel', wheelMove);
		window.addEventListener('mousemove', mouseMove);
		this.ctx.canvas.addEventListener('mousedown', mouseDown);
		window.addEventListener('mouseup', mouseUp);

		this.wasm.instance.exports._initialize();
		this.wasm.instance.exports.main();

		const next = (timestamp) => {
			if (this.quit === 1) {
				this.ctx.clearRect(0, 0, this.ctx.canvas.width, this.ctx.canvas.height);
				this.#reset();
				return;
			} else if (this.quit === 0) {
				this.ctx.canvas.removeEventListener('mousedown', mouseDown);
				this.#reset();
				return;
			}
			this.dt = (timestamp - this.previous) / 1000.0;
			this.previous = timestamp;
			if (this.ctx.canvas.classList.contains('visible')) {
				this.wasm.instance.exports.draw(this.dt);
				// TODO: create separate update function
				const buffer = this.wasm.instance.exports.memory.buffer;
				const pixels = new Uint8ClampedArray(
					buffer,
					this.canvasPtr + 8,
					this.canvasWidth * this.canvasHeight * 4
				);
				this.ctx.putImageData(new ImageData(pixels, this.canvasWidth, this.canvasHeight), 0, 0);
				this.quit === undefined && renderDebugInfo(this.ctx, this.dt, this);
			}
			requestAnimationFrame(next);
		};
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
	fpow(x, exp) {
		return Math.pow(x, exp);
	}
	fmin(a, b) {
		return Math.min(a, b);
	}
	fmax(a, b) {
		return Math.max(a, b);
	}
	connectCanvas(canvasPtr) {
		this.canvasPtr = canvasPtr;
		const buffer = this.wasm.instance.exports.memory.buffer;
		this.canvasWidth = new Uint32Array(buffer, canvasPtr, 1)[0];
		this.canvasHeight = new Uint32Array(buffer, canvasPtr + 4, 1)[0];
		this.ctx.canvas.width = this.canvasWidth;
		this.ctx.canvas.height = this.canvasHeight;
	}
	getRandomValue(min, max) {
		// TEMP
		return min + Math.floor(Math.random() * (max - min + 1));
	}
	isKeyDown(codePtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		const code = cstr_by_ptr(buffer, codePtr);
		return this.currentPressedKeyCodes.has(code);
	}
	fontCharacterSetsEqual(leftPtr, rightPtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		const left = createCodepointsFromString(cstr_by_ptr(buffer, leftPtr));
		const right = createCodepointsFromString(cstr_by_ptr(buffer, rightPtr));
		return left.length === right.length && left.every((codepoint, index) => codepoint === right[index]);
	}
	requestFontAtlas(fontFamilyPtr, fontSize, charactersPtr, atlasPtr) {
		const instance = this.wasm.instance;
		const buffer = instance.exports.memory.buffer;
		const fontFamily = cstr_by_ptr(buffer, fontFamilyPtr);
		const codepoints = charactersPtr === 0
			? DEFAULT_FONT_CODEPOINTS
			: createCodepointsFromString(cstr_by_ptr(buffer, charactersPtr));

		while (this.fontAtlasBuilds.size >= MAX_CONCURRENT_FONT_ATLAS_BUILDS) {
			const [oldestAtlasPtr, oldestBuild] = this.fontAtlasBuilds.entries().next().value;
			oldestBuild.controller.abort();
			this.fontAtlasBuilds.delete(oldestAtlasPtr);
			oldestBuild.failureReported = true;
			if (this.wasm?.instance === oldestBuild.instance) {
				oldestBuild.instance.exports.fontAtlasFailed(oldestAtlasPtr);
			}
		}

		const build = { controller: new AbortController(), instance, failureReported: false };
		this.fontAtlasBuilds.set(atlasPtr, build);
		void this.#loadFontAtlas(instance, fontFamily, fontSize, codepoints, atlasPtr, build)
			.finally(() => {
				if (this.fontAtlasBuilds.get(atlasPtr) === build) this.fontAtlasBuilds.delete(atlasPtr);
			});
	}
	async #loadFontAtlas(instance, fontFamily, fontSize, codepoints, atlasPtr, build) {
		let atlas;
		try {
			atlas = await buildFontAtlas({
				fontFamily,
				fontSize,
				codepoints,
				padding: 1,
				useOffscreen: true,
				includeKerning: true,
				signal: build.controller.signal
			});
			if (this.wasm?.instance !== instance) return;
			const exports = instance.exports;
			exports.fontAtlasPrepare(
				atlasPtr,
				atlas.lineHeight,
				atlas.emAscent,
				atlas.emDescent,
				atlas.glyphs.length,
				atlas.kernings.length
			);

			const pixelsPtr = exports.fontAtlasPrepareBitmap(atlasPtr, atlas.width, atlas.height) >>> 0;
			const pixels = new Uint8ClampedArray(
				exports.memory.buffer,
				pixelsPtr,
				atlas.width * atlas.height * 4
			);
			pixels.set(atlas.pixels);

			for (let i = 0; i < atlas.glyphs.length; i++) {
				const glyph = atlas.glyphs[i];
				exports.fontAtlasSetGlyph(
					atlasPtr,
					i,
					glyph.codepoint,
					glyph.x,
					glyph.y,
					glyph.width,
					glyph.height,
					glyph.xOffset,
					glyph.yOffset,
					glyph.xAdvance
				);
			}
			for (let i = 0; i < atlas.kernings.length; i++) {
				const kerning = atlas.kernings[i];
				exports.fontAtlasSetKerning(
					atlasPtr,
					i,
					kerning.left,
					kerning.right,
					kerning.adjustment
				);
			}
		} catch (error) {
			if (!build.failureReported && this.wasm?.instance === instance) {
				build.failureReported = true;
				instance.exports.fontAtlasFailed(atlasPtr);
			}
			if (error.name !== 'AbortError') console.error(`Could not build font atlas for "${fontFamily}"`, error);
			return;
		}

		// Publishing may let C3 evict this atlas. Never send atlasPtr to a failure
		// callback after this point.
		instance.exports.fontAtlasReady(atlasPtr);
		try {
			console.log(
				`Font atlas ready: "${fontFamily}" ${atlas.width}x${atlas.height}, ` +
				`${atlas.glyphs.length} glyphs, ${atlas.kernings.length} kerning pairs`
			);
		} catch {
			// Host pages may replace console methods; publishing already succeeded.
		}
	}
	async setClipboardText(textPtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		const text = cstr_by_ptr(buffer, textPtr);
		try {
			await navigator.clipboard.writeText(text);
		} catch (error) {
			console.warn(error.message);
		}
	}
	openURL(urlPtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		const url = cstr_by_ptr(buffer, urlPtr);
		window.open(url);
	}
	Mouse_getPosition(resultPtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		const target = new Uint32Array(buffer, resultPtr, 2);
		target.set(new Uint32Array([this.currentMousePosition.x, this.currentMousePosition.y], 2));
	}
	Mouse_getX() {
		return this.currentMousePosition.x;
	}
	Mouse_getY() {
		return this.currentMousePosition.y;
	}
	Mouse_isDown(buttonCode) {
		return this.currentMouseButtonState.has(buttonCode);
	}
	Mouse_setCursor(cursorPtr) {
		const buffer = this.wasm.instance.exports.memory.buffer;
		this.ctx.canvas.style.cursor = cstr_by_ptr(buffer, cursorPtr);
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

function createDefaultFontCodepoints() {
	const codepoints = [];
	const addRange = (start, end) => {
		for (let codepoint = start; codepoint <= end; codepoint++) codepoints.push(codepoint);
	};

	addRange(0x0020, 0x007e); // Basic Latin
	addRange(0x00a0, 0x017f); // Latin-1 Supplement and Latin Extended-A
	addRange(0x0400, 0x04ff); // Cyrillic
	addRange(0x2000, 0x206f); // General Punctuation
	codepoints.push(0xfffd); // Replacement Character
	return codepoints;
}

function createCodepointsFromString(characters) {
	const codepoints = new Set(Array.from(characters, character => character.codePointAt(0)));
	codepoints.add(0xfffd);
	return [...codepoints].sort((a, b) => a - b);
}

export default Vic3;
