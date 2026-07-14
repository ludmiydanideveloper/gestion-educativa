const fs = require('fs');

const htmlPath = 'C:\\Users\\Administrador\\.gemini\\antigravity\\brain\\c4d12dfb-e507-4195-ad46-7b227979de55\\.system_generated\\steps\\1474\\content.md';
const content = fs.readFileSync(htmlPath, 'utf8');

// Find all matches for sheetId or gridId or gid
const regexes = [
  /sheetId["']?\s*:\s*(\d+)/gi,
  /gid["']?\s*:\s*["']?(\d+)/gi,
  /gridId["']?\s*:\s*(\d+)/gi,
  /["']id["']\s*:\s*["']?(\d{5,})["']?/g // 5 or more digits
];

regexes.forEach((regex, idx) => {
  const matches = new Set();
  let match;
  while ((match = regex.exec(content)) !== null) {
    matches.add(match[1]);
  }
  console.log(`Regex ${idx} matches:`, Array.from(matches));
});

// Let's look for sheet tab names or "Hoja1" or "2026"
const posHoja = content.indexOf("Hoja1");
if (posHoja !== -1) {
  console.log("Hoja1 context:", content.substring(posHoja - 200, posHoja + 200));
}
const pos2026 = content.indexOf("2026");
if (pos2026 !== -1) {
  console.log("2026 context:", content.substring(pos2026 - 200, pos2026 + 200));
}
