const { JSDOM } = require("jsdom");
const fs = require("fs");
const script = fs.readFileSync("" + require("path").join(__dirname, "..", "App", "Web", "agent.js") + "", "utf8");

const html = `<!doctype html><html><head><title>Shop &amp; Search</title></head><body>
<form id="f" action="#"><label for="q">Search</label><input id="q" name="q" type="text" placeholder="Search shop">
<button type="submit">Go</button></form>
<a href="/shoes">Red shoes</a>
<input type="checkbox" id="stock"><label for="stock">In stock</label>
<select id="size" aria-label="Size"><option value="s">Small</option><option value="m">Medium</option><option value="l">Large</option></select>
<input type="range" id="vol" min="0" max="10" value="3" aria-label="Volume">
<input type="password" id="pw" aria-label="Password" value="hunter2">
<input type="text" id="card" autocomplete="cc-number" aria-label="Card" value="4111">
<div role="button" id="fake" onclick="document.title='clicked'">Fake button</div>
<button id="hidden" style="display:none">Hidden</button>
<div id="host"></div>
<script>
 const root = document.getElementById('host').attachShadow({mode:'open'});
 root.innerHTML = '<button id="deep">Deep button</button>';
 window.log = [];
 document.getElementById('q').addEventListener('input', e => window.log.push('input:' + e.target.value));
 document.getElementById('q').addEventListener('change', e => window.log.push('change:' + e.target.value));
 document.getElementById('f').addEventListener('submit', e => { e.preventDefault(); window.log.push('submit'); });
 document.getElementById('size').addEventListener('change', e => window.log.push('size:' + e.target.value));
 document.getElementById('vol').addEventListener('input', e => window.log.push('vol:' + e.target.value));
</script></body></html>`;

const dom = new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, url: "https://shop.example.com/" });
const w = dom.window;
// jsdom has no layout: give every element a box so the script treats it as visible.
w.Element.prototype.getBoundingClientRect = function () {
  if (this.style && this.style.display === "none") return { top: 0, bottom: 0, left: 0, right: 0, width: 0, height: 0 };
  const i = Array.from(w.document.querySelectorAll("*")).indexOf(this);
  return { top: 10 + i * 20, bottom: 28 + i * 20, left: 0, right: 200, width: 200, height: 18 };
};
w.document.elementFromPoint = () => null;
w.Element.prototype.scrollIntoView = function () {};
w.eval(script);

let pass = 0, fail = 0;
function check(name, cond, extra) { if (cond) { pass++; } else { fail++; console.log("FAIL", name, extra === undefined ? "" : JSON.stringify(extra)); } }

const snap = JSON.parse(w.__agent.snapshot(60));
const by = label => snap.elements.find(e => e.label === label);
check("title", snap.title === "Shop & Search", snap.title);
check("has search box", by("Search") && by("Search").role === "textbox", snap.elements);
check("has Go button", by("Go") && by("Go").role === "button");
check("has link", by("Red shoes") && by("Red shoes").role === "link");
check("has checkbox", by("In stock") && by("In stock").role === "checkbox" && by("In stock").checked === false);
check("has dropdown", by("Size") && by("Size").role === "dropdown" && by("Size").value === "Small");
check("has slider", by("Volume") && by("Volume").role === "slider");
check("div role=button found", by("Fake button"));
check("shadow DOM found", by("Deep button"));
check("hidden skipped", !by("Hidden"));
check("password flagged", snap.hasPassword === true);
const pw = by("Password"); const card = by("Card");
check("password value never leaves page", pw && pw.value === null, pw);
check("card value never leaves page", card && card.value === null, card);
check("ids are numbers and unique", new Set(snap.elements.map(e => e.id)).size === snap.elements.length);

const id = l => by(l).id;
let r = JSON.parse(w.__agent.act(id("Search"), "fill", "red shoes", false));
check("fill ok", r.ok === true, r);
check("input+change fired", w.log.includes("input:red shoes") && w.log.includes("change:red shoes"), w.log);
check("value set", w.document.getElementById("q").value === "red shoes");

r = JSON.parse(w.__agent.act(id("Search"), "fill", "boots", true));
check("enter ok", r.ok === true && r.message.includes("Enter"), r);

r = JSON.parse(w.__agent.act(id("Password"), "fill", "x", false));
check("password refused", r.ok === false && r.message === "sensitive", r);
check("password untouched", w.document.getElementById("pw").value === "hunter2");
r = JSON.parse(w.__agent.act(id("Card"), "fill", "1", false));
check("card refused", r.ok === false && r.message === "sensitive", r);

r = JSON.parse(w.__agent.act(id("In stock"), "fill", "true", false));
check("checkbox checked", r.ok && w.document.getElementById("stock").checked === true, r);
r = JSON.parse(w.__agent.act(id("In stock"), "fill", "false", false));
check("checkbox unchecked", r.ok && w.document.getElementById("stock").checked === false, r);

r = JSON.parse(w.__agent.act(id("Size"), "fill", "large", false));
check("select by text", r.ok && w.document.getElementById("size").value === "l" && w.log.includes("size:l"), r);
r = JSON.parse(w.__agent.act(id("Size"), "fill", "huge", false));
check("select bad option explains", r.ok === false && r.message.includes("Options"), r);

r = JSON.parse(w.__agent.act(id("Volume"), "fill", "99", false));
check("slider clamps", r.ok && w.document.getElementById("vol").value === "10" && w.log.includes("vol:10"), r);
r = JSON.parse(w.__agent.act(id("Volume"), "fill", "abc", false));
check("slider needs number", r.ok === false, r);

r = JSON.parse(w.__agent.act(id("Fake button"), "click", "", false));
check("click custom button", r.ok && w.document.title === "clicked", r);
r = JSON.parse(w.__agent.act(id("Deep button"), "click", "", false));
check("click shadow button", r.ok, r);
r = JSON.parse(w.__agent.act(99999, "click", "", false));
check("missing element handled", r.ok === false && r.message.includes("gone"), r);

check("readText works", w.__agent.readText().length >= 0);
r = JSON.parse(w.__agent.scroll("down")); check("scroll ok", r.ok === true);
check("agent API is frozen", (() => { try { w.__agent.act = null; } catch (e) {} return typeof w.__agent.act === "function"; })());
check("agent defined once", (() => { const a = w.__agent; w.eval(script); return w.__agent === a; })());

const big = new JSDOM("<body>" + Array.from({ length: 150 }, (_, i) => `<a href="/p${i}">Product ${i}</a>`).join("") + "</body>", { runScripts: "outside-only", pretendToBeVisual: true, url: "https://shop.example.com/" });
big.window.Element.prototype.getBoundingClientRect = function () { return { top: 10, bottom: 28, left: 0, right: 200, width: 200, height: 18 }; };
big.window.document.elementFromPoint = () => null;
big.window.Element.prototype.scrollIntoView = function () {};
big.window.eval(script);
const s2 = JSON.parse(big.window.__agent.snapshot(60));
check("limit respected", s2.elements.length === 60 && s2.more === 90, [s2.elements.length, s2.more]);

const menu = new JSDOM('<body><a href="/h">Home</a><a href="/c" id="c">Calendar</a><a href="/g">Grades</a></body>', { runScripts: "outside-only", pretendToBeVisual: true, url: "https://portal.example.com/" });
let nth = 0;
menu.window.Element.prototype.getBoundingClientRect = function () { const top = this.tagName === "A" ? 20 + 1500 * (this.id === "c" ? 1 : 0) : 0; return { top, bottom: top + 18, left: 0, right: 200, width: 200, height: 18 }; };
menu.window.document.elementFromPoint = () => null;
menu.window.Element.prototype.scrollIntoView = function () {};
menu.window.eval(script);
const plain = JSON.parse(menu.window.__agent.snapshot(60));
check("out-of-view link is not in the plain list", !plain.elements.some(e => e.label === "Calendar"), plain.elements.map(e => e.label));
const found = JSON.parse(menu.window.__agent.snapshot(60, "calend"));
check("find returns the out-of-view link", found.elements.length === 1 && found.elements[0].label === "Calendar" && found.elements[0].offscreen === true, found.elements);
const clicked = JSON.parse(menu.window.__agent.act(found.elements[0].id, "click", "", false));
check("found link can be clicked", clicked.ok === true && clicked.label === "Calendar", clicked);
check("find with no match is empty", JSON.parse(menu.window.__agent.snapshot(60, "zzz")).elements.length === 0);

console.log(`${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
