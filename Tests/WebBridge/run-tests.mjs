import { readFile } from 'node:fs/promises';
import testBridge from './spotify-lyrics-bridge.test.mjs';

const swift = await readFile(new URL('../../App/Shared/SpotifyLyricsSession.swift', import.meta.url), 'utf8');
const source = swift.match(/private static let bridge = #"""([\s\S]*?)"""#/)[1];
const result = await testBridge(source);
console.log(JSON.stringify(result, null, 2));
