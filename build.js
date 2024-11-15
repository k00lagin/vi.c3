const { spawn } = require('child_process');

const demos = [
    {
        name: "showcase",
        sources: ["./demos/showcase.c3", "./vic3-src/vi.c3"],
        out: "./build/showcase"
    },
    {
        name: "oklch",
        sources: ["./demos/oklch.c3", "./vic3-src/vi.c3"],
        out: "./build/oklch"
    },
    {
        name: "ball",
        sources: ["./demos/ball.c3", "./vic3-src/vi.c3"],
        out: "./build/ball"
    },
    {
        name: "cursors",
        sources: ["./demos/cursors.c3", "./vic3-src/vi.c3"],
        out: "./build/cursors"
    },
    {
        name: "input-keys",
        sources: ["./demos/input-keys.c3", "./vic3-src/vi.c3"],
        out: "./build/input-keys"
    },
    {
        name: "blen-dmodes",
        sources: ["./demos/blend-modes.c3", "./vic3-src/vi.c3"],
        out: "./build/blend-modes"
    },
    {
        name: "retro",
        sources: ["./demos/retro.c3", "./vic3-src/vi.c3"],
        out: "./build/retro"
    }
]

/**
 * @param {string} program 
 * @param {string[]} args 
 * @returns {ReturnType<typeof spawn>}
 */
function cmd(program, args = []) {
    const spawnOptions = { "shell": true };
    console.log('CMD:', program, args.flat(), spawnOptions);
    const p = spawn(program, args.flat(), spawnOptions); // NOTE: flattening the args array enables you to group related arguments for better self-documentation of the running command
    // @ts-ignore [stdout may be null?]
    p.stdout.on('data', (data) => process.stdout.write(data));
    // @ts-ignore [stderr may be null?]
    p.stderr.on('data', (data) => process.stderr.write(data));
    p.on('close', (code) => {
        if (code !== 0) {
            console.error(program, args, 'exited with', code);
        }
    });
    return p;
}

if (!0) {
    for (const demo of demos) {
        cmd("c3c", [
            "compile",
            "-D", "PLATFORM_WEB",
            "--reloc=none",
            "--target", "wasm32",
            "--single-module=yes",
            "-O5", "-g0", "--link-libc=no", "--no-entry",
            "-o", demo.out,
            "-z", "--export-table",
            "-z", "--allow-undefined",
            `${demo.sources.map(s => `"${s}"`).join(" ")}`,
        ])
    }
}
