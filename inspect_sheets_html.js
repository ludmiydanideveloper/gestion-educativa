const fs = require('fs');

const htmlPath = 'C:\\Users\\Administrador\\.gemini\\antigravity\\brain\\c4d12dfb-e507-4195-ad46-7b227979de55\\.system_generated\\steps\\1474\\content.md';
if (!fs.existsSync(htmlPath)) {
  console.log("HTML file not found!");
  process.exit(1);
}

const content = fs.readFileSync(htmlPath, 'utf8');

const searchAround = (term) => {
  let idx = 0;
  while ((idx = content.indexOf(term, idx)) !== -1) {
    console.log(`=== FOUND ${term} at index ${idx} ===`);
    const start = Math.max(0, idx - 150);
    const end = Math.min(content.length, idx + 150);
    console.log(content.substring(start, end));
    idx += term.length;
  }
};

searchAround("Hoja1");
searchAround("2026");

