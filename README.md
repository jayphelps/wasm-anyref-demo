# wasm-anyref-demo

**Requires a fairly recent Node.js version with support for `--experimental-wasm-anyref`. I'm not sure which version off hand, but I'm using v12.7.0**

This is a (relatively speaking) simple demo of using JavaScript's Garbage Collector as the sole heap allocator for a WebAssembly (Wasm) module.

If this is interesting to a number of folks I might take time to explain more about it, as it does require some understanding of a lot of things, but I did include a few comments.

Performance is probably the biggest issue with this approach, but that's known and proposals in the W3C WebAssembly Community Group will fix them eventually.

```bash
npm install
npm start
```