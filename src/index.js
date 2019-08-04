import { readFileSync } from 'fs';
import setupWabt from 'wabt';

console.clear();

const env = {
  memory: new WebAssembly.Memory({ initial: 10 }),
  anyref_table: new WebAssembly.Table({ element: 'anyref', initial: 2 }),
  get: Reflect.get,
  alloc_struct(...args) {
    return args;
  },
  alloc_struct0() {
    return [];
  },
  alloc_struct1(a) {
    return [a];
  },
  alloc_struct2(a, b) {
    return [a, b];
  },
  alloc_struct3(a, b, c) {
    return [a, b, c];
  },
  log(value) {
    console.log(value);
  }
};

const wabt = setupWabt();
const wat = readFileSync('src/main.wat', { encoding: 'utf8' });
const features = {
  'reference_types': true
};

const wabtModule = wabt.parseWat('src/main.wat', wat, features);
wabtModule.resolveNames();
wabtModule.validate(features);
const { buffer } = wabtModule.toBinary({
  log: true,
  write_debug_names: true
});

const module = new WebAssembly.Module(buffer);
const imports = { env };
const instance = new WebAssembly.Instance(module, imports);

// It seems there's some sort of bug (or undocumented behavior) in V8's
// experimental reference types implementation where when *importing* an anyref
// table it doesn't correctly see it as table.type == kWasmAnyRef but instead
// as kWasmFuncRef. When I tried to set into it *before* instantiating, it
// errors out during instiantiation with:
// "LinkError: WebAssembly.Instance(): table import 1[0] is not a wasm function"
// https://github.com/v8/v8/blob/2cf99b34677979387658ab9a8ebf9ff0c6b2d08d/src/wasm/module-instantiate.cc#L999
// So we're doing it here instead. It's unclear long term if we'll eventually
// have a way of initializing a table with values instead of needing to set them
// individually, like we do here.
env.anyref_table.set(0, 'Some Name');
env.anyref_table.set(1, 'Example comment text');

instance.exports.main();
