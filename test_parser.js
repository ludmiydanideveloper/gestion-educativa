const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);

const coursesFound = [];

workbook.SheetNames.forEach(sheetName => {
  const sheet = workbook.Sheets[sheetName];
  const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
  
  for (let r = 0; r < data.length; r++) {
    const row = data[r];
    if (!row) continue;
    for (let c = 0; c < row.length; c++) {
      const val = row[c];
      if (val && typeof val === 'string' && val.includes('HORARIO')) {
        const match = val.match(/HORARIO\s+([^-\(]+)/i);
        const name = match ? match[1].trim() : val;
        coursesFound.push({
          name: name,
          sheetName: sheetName,
          startRow: r,
          startCol: c
        });
      }
    }
  }
});

console.log("Found courses:");
console.log(coursesFound);
