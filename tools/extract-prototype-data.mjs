// One off: pulls the data tables out of prototype/prototype-5.html into the
// GameCore JSON resources, so the numbers and text match the prototype exactly.
// Run from the repo root:  node tools/extract-prototype-data.mjs
// Hand written data (balance, rivals, events, challenges, facilities) is not
// touched; only the files listed below are regenerated.

import { readFileSync, writeFileSync } from 'node:fs';

const html = readFileSync('prototype/prototype-5.html', 'utf8');
const OUT = 'Packages/GameCore/Sources/GameCore/Resources/Data/';

// Returns the source text of `const NAME=...;`, skipping over strings and nested brackets.
function constSource(name) {
  const start = html.indexOf('const ' + name + '=');
  if (start < 0) throw new Error('missing const ' + name);
  let i = start + ('const ' + name + '=').length, depth = 0, quote = null;
  for (; i < html.length; i++) {
    const c = html[i];
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = null; continue; }
    if (c === '"' || c === "'" || c === '`') quote = c;
    else if ('([{'.includes(c)) depth++;
    else if (')]}'.includes(c)) depth--;
    else if ((c === ';' || c === ',') && depth === 0) break;
  }
  return html.slice(start + ('const ' + name + '=').length, i);
}
const value = name => Function('"use strict";return (' + constSource(name) + ')')();
const write = (file, data) => writeFileSync(OUT + file, JSON.stringify(data, null, 2) + '\n');

// Plots: hand made and legendary venues.
const reserve = value('RESERVE');
const plots = value('PLOTS').map(p => {
  const out = {
    id: p.id, name: p.name, area: p.area, lat: p.lat, lon: p.lon, land: p.terrain,
    holes: p.holes, wealth: p.wealth, demand: p.demand, prestige: p.prestige,
  };
  if (p.legend) out.legendaryGuide = p.lp;
  if (reserve.includes(p.id)) out.reserve = true;
  return out;
});
write('plots.json', plots);

// Towns used for generated sites.
const code = value('TCODE');
write('towns.json', value('PLACES').map(a => ({
  town: a[0], county: a[1], lat: a[2], lon: a[3],
  lands: a[4].split('').map(c => code[c]), wealth: a[5], demand: a[6],
})));

// Name word lists for generated sites.
const gen = value('GEN_NAMES');
const names = {};
for (const k in gen) names[k] = { first: gen[k][0], second: gen[k][1] };
write('site_names.json', names);

write('golfer_names.json', { first: value('FIRST'), last: value('LAST') });
write('percy.json', { lines: value('L'), column: value('PERCY_COL') });

console.log('plots', plots.length);
