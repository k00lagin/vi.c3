import Vic3 from './vic3.mjs';

const demos = [
	{ name: 'ball', wasm: 'build/ball.wasm', canvas: document.querySelector('.ball-demo') },
	{ name: 'input-keys', wasm: 'build/input-keys.wasm', canvas: document.querySelector('.input-keys-demo') },
	{ name: 'fake-gradient', wasm: 'build/fake-gradient.wasm', canvas: document.querySelector('.fake-gradient-demo') },
	{ name: 'retro', wasm: 'build/retro.wasm', canvas: document.querySelector('.retro-demo') }
];

for (const demo of demos) {
	let vic3 = new Vic3();
	vic3.start({
		wasm: demo.wasm,
		canvas: demo.canvas
	});
}