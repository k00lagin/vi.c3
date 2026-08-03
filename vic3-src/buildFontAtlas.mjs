const MAX_ATLAS_SIDE = 16384;

export default async function buildFontAtlas({
	fontFamily,
	fontSize,
	codepoints,
	padding = 1,
	useOffscreen = true,
	includeKerning = true,
	signal
} = {}) {
	throwIfAborted(signal);
	if (typeof fontFamily !== 'string' || fontFamily.length === 0) {
		throw new Error('fontFamily must be a non-empty string');
	}
	if (!Number.isFinite(fontSize) || fontSize <= 0) {
		throw new Error('fontSize must be a positive number');
	}
	if (!Number.isInteger(padding) || padding < 0) {
		throw new Error('padding must be a non-negative integer');
	}

	const normalizedCodepoints = normalizeCodepoints(codepoints);
	if (normalizedCodepoints.length === 0) {
		throw new Error('No characters to pack');
	}

	const cssFont = `${fontSize}px "${fontFamily.replaceAll('"', '\\"')}"`;
	await ensureFontLoaded(fontFamily, fontSize, cssFont, useOffscreen, signal);
	throwIfAborted(signal);

	const measureCtx = create2DContext(1, 1, useOffscreen);
	measureCtx.textBaseline = 'alphabetic';
	measureCtx.textAlign = 'left';
	measureCtx.font = cssFont;

	const sample = measureCtx.measureText('Mg');
	const emAscent = sample.emHeightAscent ?? sample.actualBoundingBoxAscent ?? fontSize;
	const emDescent = sample.emHeightDescent ?? sample.actualBoundingBoxDescent ?? fontSize * 0.25;
	const lineHeight = emAscent + emDescent;

	const glyphs = [];
	let totalArea = 0;
	let measureYieldDeadline = Date.now() + 8;
	for (const codepoint of normalizedCodepoints) {
		throwIfAborted(signal);
		const char = String.fromCodePoint(codepoint);
		const metrics = measureCtx.measureText(char);
		const left = metrics.actualBoundingBoxLeft ?? 0;
		const right = metrics.actualBoundingBoxRight ?? metrics.width;
		const ascent = metrics.actualBoundingBoxAscent ?? emAscent;
		const descent = metrics.actualBoundingBoxDescent ?? emDescent;
		const width = Math.max(1, Math.ceil(left + right) + 2 * padding);
		const height = Math.max(1, Math.ceil(ascent + descent) + 2 * padding);

		glyphs.push({
			codepoint,
			char,
			left,
			right,
			ascent,
			descent,
			width,
			height,
			xAdvance: metrics.width
		});
		totalArea += width * height;
		if (Date.now() >= measureYieldDeadline) {
			await yieldToBrowser(signal);
			measureYieldDeadline = Date.now() + 8;
		}
	}

	const packingOrder = [...glyphs].sort((a, b) => b.height - a.height || b.width - a.width);
	let side = Math.max(1, Math.ceil(Math.sqrt(totalArea) * 1.07));
	while (!shelfPack(packingOrder, side)) {
		side = Math.ceil(side * 1.25);
		if (side > MAX_ATLAS_SIDE) {
			throw new Error(`Font atlas exceeds ${MAX_ATLAS_SIDE}x${MAX_ATLAS_SIDE}`);
		}
	}

	const ctx = create2DContext(side, side, useOffscreen);
	ctx.clearRect(0, 0, side, side);
	ctx.font = cssFont;
	ctx.textBaseline = 'alphabetic';
	ctx.textAlign = 'left';
	ctx.fillStyle = 'white';

	const atlasGlyphs = [];
	let rasterYieldDeadline = Date.now() + 8;
	for (const glyph of glyphs) {
		const baseline = glyph.y + padding + glyph.ascent;
		const textX = glyph.x + padding + glyph.left;
		ctx.fillText(glyph.char, textX, baseline);

		atlasGlyphs.push({
			codepoint: glyph.codepoint,
			x: glyph.x,
			y: glyph.y,
			width: glyph.width,
			height: glyph.height,
			xOffset: -glyph.left - padding,
			yOffset: -glyph.ascent - padding,
			xAdvance: glyph.xAdvance
		});
		if (Date.now() >= rasterYieldDeadline) {
			await yieldToBrowser(signal);
			rasterYieldDeadline = Date.now() + 8;
		}
	}

	const kernings = [];
	if (includeKerning) {
		let yieldDeadline = Date.now() + 8;
		let pairsSinceClockCheck = 0;
		for (const leftGlyph of glyphs) {
			for (const rightGlyph of glyphs) {
				const pair = leftGlyph.char + rightGlyph.char;
				const pairWidth = measureCtx.measureText(pair).width;
				const adjustment = pairWidth - leftGlyph.xAdvance - rightGlyph.xAdvance;
				if (Math.abs(adjustment) > 0.01) {
					kernings.push({
						left: leftGlyph.codepoint,
						right: rightGlyph.codepoint,
						adjustment
					});
				}
				pairsSinceClockCheck++;
				if (pairsSinceClockCheck >= 64) {
					pairsSinceClockCheck = 0;
					if (Date.now() >= yieldDeadline) {
						await yieldToBrowser(signal);
						yieldDeadline = Date.now() + 8;
					}
				}
			}
		}
	}

	throwIfAborted(signal);
	const { data: pixels } = ctx.getImageData(0, 0, side, side);
	return {
		width: side,
		height: side,
		pixels,
		glyphs: atlasGlyphs,
		kernings,
		fontFamily,
		fontSize,
		lineHeight,
		emAscent,
		emDescent,
		canvas: ctx.canvas
	};
}

async function yieldToBrowser(signal) {
	throwIfAborted(signal);
	await new Promise(resolve => setTimeout(resolve, 0));
	throwIfAborted(signal);
}

function throwIfAborted(signal) {
	if (!signal?.aborted) return;
	throw createAbortError();
}

function createAbortError() {
	const error = new Error('Font atlas build aborted');
	error.name = 'AbortError';
	return error;
}

function normalizeCodepoints(values) {
	if (!Array.isArray(values)) {
		throw new Error('codepoints must be an array');
	}

	const unique = new Set();
	for (const value of values) {
		if (!Number.isInteger(value) || value < 0 || value > 0x10ffff || (value >= 0xd800 && value <= 0xdfff)) {
			throw new Error(`Invalid Unicode codepoint: ${value}`);
		}
		unique.add(value);
	}
	return [...unique].sort((a, b) => a - b);
}

async function ensureFontLoaded(fontFamily, fontSize, cssFont, useOffscreen, signal) {
	if (typeof document === 'undefined' || !document.fonts) {
		throw new Error('The CSS Font Loading API is unavailable');
	}

	const loadedFaces = await raceWithAbort(document.fonts.load(cssFont, 'Mg'), signal);
	if (loadedFaces.length === 0 && !isSystemFontAvailable(fontFamily, fontSize, useOffscreen)) {
		throw new Error(`Could not load font: ${cssFont}`);
	}
}

function raceWithAbort(promise, signal) {
	if (!signal) return promise;
	throwIfAborted(signal);
	return new Promise((resolve, reject) => {
		const onAbort = () => {
			signal.removeEventListener('abort', onAbort);
			reject(createAbortError());
		};
		signal.addEventListener('abort', onAbort, { once: true });
		promise.then(
			value => {
				signal.removeEventListener('abort', onAbort);
				resolve(value);
			},
			error => {
				signal.removeEventListener('abort', onAbort);
				reject(error);
			}
		);
	});
}

function isSystemFontAvailable(fontFamily, fontSize, useOffscreen) {
	const genericFamilies = ['monospace', 'sans-serif', 'serif'];
	if (genericFamilies.includes(fontFamily.toLowerCase())) return true;

	const ctx = create2DContext(1, 1, useOffscreen);
	const sample = 'mmmmmmmmmmlliWW@#';
	return genericFamilies.some(genericFamily => {
		ctx.font = `${fontSize}px ${genericFamily}`;
		const fallbackWidth = ctx.measureText(sample).width;
		ctx.font = `${fontSize}px "${fontFamily.replaceAll('"', '\\"')}", ${genericFamily}`;
		return ctx.measureText(sample).width !== fallbackWidth;
	});
}

function create2DContext(width, height, preferOffscreen) {
	let canvas;
	if (preferOffscreen && typeof OffscreenCanvas !== 'undefined') {
		canvas = new OffscreenCanvas(width, height);
	} else if (typeof document !== 'undefined') {
		canvas = document.createElement('canvas');
		canvas.width = width;
		canvas.height = height;
	} else {
		throw new Error('Canvas 2D is unavailable');
	}

	const ctx = canvas.getContext('2d', { willReadFrequently: true });
	if (ctx === null) {
		throw new Error('Could not create font atlas 2D context');
	}
	return ctx;
}

function shelfPack(items, side) {
	let x = 0;
	let y = 0;
	let shelfHeight = 0;
	for (const item of items) {
		if (item.width > side || item.height > side) return false;
		if (x + item.width > side) {
			x = 0;
			y += shelfHeight;
			shelfHeight = 0;
		}
		if (y + item.height > side) return false;
		item.x = x;
		item.y = y;
		x += item.width;
		shelfHeight = Math.max(shelfHeight, item.height);
	}
	return true;
}
