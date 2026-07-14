const XLSX = require('xlsx');

const file = 'C:\\Users\\Administrador\\Downloads\\Horario Secundario Marzo 2026.xlsx';
const workbook = XLSX.readFile(file);

workbook.SheetNames.forEach(sheetName => {
  console.log(`===============================================`);
  console.log(`Analyzing Sheet: ${sheetName}`);
  const sheet = workbook.Sheets[sheetName];
  const data = XLSX.utils.sheet_to_json(sheet, { header: 1 });
  
  const uniqueCells = new Set();
  data.forEach(row => {
    row.forEach(val => {
      if (val && typeof val === 'string') {
        uniqueCells.add(val.trim());
      }
    });
  });
  
  console.log(`Unique string values in ${sheetName}:`);
  const sorted = Array.from(uniqueCells).sort();
  console.log(sorted.slice(0, 100)); // Print first 100 unique values
  if (sorted.length > 100) {
    console.log(`... and ${sorted.length - 100} more.`);
  }
});
