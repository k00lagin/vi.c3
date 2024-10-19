import Vic3 from './vic3.mjs';

const demos = [
	{ name: 'showcase', wasm: 'build/showcase.wasm', canvas: document.querySelector('.showcase-demo') },
	{ name: 'oklch', wasm: 'build/oklch.wasm', canvas: document.querySelector('.oklch-demo') },
	{ name: 'ball', wasm: 'build/ball.wasm', canvas: document.querySelector('.ball-demo') },
	{ name: 'cursors', wasm: 'build/cursors.wasm', canvas: document.querySelector('.cursors-demo') },
	{ name: 'input-keys', wasm: 'build/input-keys.wasm', canvas: document.querySelector('.input-keys-demo') },
	{ name: 'blend-modes', wasm: 'build/blend-modes.wasm', canvas: document.querySelector('.blend-modes-demo') },
	{ name: 'retro', wasm: 'build/retro.wasm', canvas: document.querySelector('.retro-demo') }
];

for (const demo of demos) {
	let vic3 = new Vic3();
	vic3.start({
		wasm: demo.wasm,
		canvas: demo.canvas
	});
}